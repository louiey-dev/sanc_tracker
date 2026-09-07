import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../data/location_service.dart';
import '../data/tracking_preferences.dart';
import '../domain/tracking_state.dart';
import '../domain/location_point.dart';
import '../domain/tracking_repository.dart';
import '../domain/tracking_session.dart';
import '../data/json_tracking_repository.dart';

final locationServiceProvider = Provider<LocationService>((ref) {
  final preferences = ref.watch(trackingPreferencesProvider);
  return GeolocatorLocationService(
    batterySaving: preferences.batterySaving,
    intervalSeconds: preferences.intervalSeconds,
  );
});
final trackingRepositoryProvider = Provider<TrackingRepository>(
  (ref) => JsonTrackingRepository(),
);
final trackingControllerProvider =
    NotifierProvider<TrackingController, TrackingState>(TrackingController.new);

class TrackingController extends Notifier<TrackingState> {
  StreamSubscription<Position>? _subscription;
  TrackingSession? _session;
  bool _busy = false;
  @override
  TrackingState build() {
    ref.onDispose(() => _subscription?.cancel());
    return const TrackingState();
  }

  Future<void> restoreActiveSession() async {
    if (_busy || state.isTracking) return;
    _busy = true;
    try {
      final session = await ref
          .read(trackingRepositoryProvider)
          .loadActiveSession();
      if (session == null || state.isTracking) return;
      final points = await ref
          .read(trackingRepositoryProvider)
          .loadPoints(session.id);
      _session = session;
      final route = points
          .map(
            (point) => Position(
              latitude: point.latitude,
              longitude: point.longitude,
              timestamp: point.recordedAt,
              accuracy: point.accuracyM ?? 0,
              altitude: point.altitudeM ?? 0,
              altitudeAccuracy: 0,
              heading: point.headingDeg ?? 0,
              headingAccuracy: 0,
              speed: point.speedMps ?? 0,
              speedAccuracy: 0,
            ),
          )
          .toList();
      state = state.copyWith(
        currentPosition: route.isEmpty ? null : route.last,
        route: route,
        isTracking: false,
        message: '이전 추적 세션을 복구했습니다. ${route.length}개의 위치를 불러왔습니다.',
      );
      final service = ref.read(locationServiceProvider);
      if (!await service.isServiceEnabled()) {
        state = state.copyWith(
          message: '이전 기록을 복구했습니다. 위치 서비스를 켜고 시작을 눌러 재개하세요.',
        );
        return;
      }
      final permission = await service.requestPermissionIfNeeded();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        state = state.copyWith(
          message: '이전 기록을 복구했습니다. 위치 권한 허용 후 시작을 눌러 재개하세요.',
        );
        return;
      }
      _startStream(service);
    } catch (error) {
      state = state.copyWith(isTracking: false, message: '추적 복구 실패: $error');
    } finally {
      _busy = false;
    }
  }

  Future<void> loadCurrentPosition() async {
    final service = ref.read(locationServiceProvider);
    if (!await service.isServiceEnabled()) return;
    final permission = await service.requestPermissionIfNeeded();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever)
      return;
    try {
      final position = await service.getCurrentPosition();
      state = state.copyWith(currentPosition: position);
    } catch (error) {
      state = state.copyWith(message: '현재 위치를 확인하지 못했습니다: $error');
    }
  }

  Future<void> loadLastKnownPosition() async {
    final service = ref.read(locationServiceProvider);
    if (!await service.isServiceEnabled()) return;
    final permission = await service.requestPermissionIfNeeded();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) return;
    final position = await service.getLastKnownPosition();
    if (position != null) state = state.copyWith(currentPosition: position);
  }

  Future<void> loadSessionRoute(TrackingSession session) async {
    final points = await ref
        .read(trackingRepositoryProvider)
        .loadPoints(session.id);
    final route = points
        .map(
          (point) => Position(
            latitude: point.latitude,
            longitude: point.longitude,
            timestamp: point.recordedAt,
            accuracy: point.accuracyM ?? 0,
            altitude: point.altitudeM ?? 0,
            altitudeAccuracy: 0,
            heading: point.headingDeg ?? 0,
            headingAccuracy: 0,
            speed: point.speedMps ?? 0,
            speedAccuracy: 0,
          ),
        )
        .toList();
    state = state.copyWith(
      route: route,
      message: '${route.length}개의 저장된 위치를 불러왔습니다.',
    );
  }

  void clearLoadedSessionRoute() {
    state = state.copyWith(route: const [], message: '저장 경로 보기를 종료했습니다.');
  }

  Future<void> toggleTracking() async {
    if (_busy) return;
    _busy = true;
    try {
      if (state.isTracking) {
        await _subscription?.cancel();
        _subscription = null;
        final session = _session;
        if (session != null) {
          await ref
              .read(trackingRepositoryProvider)
              .updateSession(
                TrackingSession(
                  id: session.id,
                  startedAt: session.startedAt,
                  updatedAt: DateTime.now().toUtc(),
                  endedAt: DateTime.now().toUtc(),
                  status: TrackingSessionStatus.completed,
                ),
              );
        }
        _session = null;
        state = state.copyWith(
          isTracking: false,
          message: '추적이 중지되었습니다. ${state.route.length}개의 위치가 수집되었습니다.',
        );
        return;
      }
      state = state.copyWith(clearMessage: true);
      final service = ref.read(locationServiceProvider);
      if (!await service.isServiceEnabled()) {
        state = state.copyWith(message: '휴대폰의 위치 서비스를 켜 주세요.');
        return;
      }
      final permission = await service.requestPermissionIfNeeded();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        state = state.copyWith(message: '위치 권한이 필요합니다. 설정에서 권한을 허용해 주세요.');
        return;
      }
      if (_session == null) {
        final session = TrackingSession(
          id: _newId(),
          startedAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        );
        await ref.read(trackingRepositoryProvider).saveSession(session);
        _session = session;
        state = state.copyWith(route: []);
      }
      await _subscription?.cancel();
      _startStream(service);
    } catch (error) {
      state = state.copyWith(isTracking: false, message: '추적 변경 실패: $error');
    } finally {
      _busy = false;
    }
  }

  void _startStream(LocationService service) {
    final session = _session!;
    state = state.copyWith(isTracking: true);
    _subscription = service
        .positionStream()
        .asyncMap((position) async {
          await ref
              .read(trackingRepositoryProvider)
              .savePoint(
                LocationPoint(
                  id: _newId(),
                  sessionId: session.id,
                  latitude: position.latitude,
                  longitude: position.longitude,
                  recordedAt: position.timestamp,
                  updatedAt: DateTime.now().toUtc(),
                  accuracyM: position.accuracy,
                  altitudeM: position.altitude,
                  speedMps: position.speed,
                  headingDeg: position.heading,
                ),
              );
          return position;
        })
        .listen(
          (position) {
            final accuracyMessage = position.accuracy > 100
                ? 'GPS 정확도가 낮습니다(±${position.accuracy.toStringAsFixed(0)}m).'
                : null;
            state = state.copyWith(
              currentPosition: position,
              route: [...state.route, position],
              message: accuracyMessage,
              clearMessage: accuracyMessage == null,
            );
          },
          onError: (Object error) => state = state.copyWith(
            isTracking: false,
            message: '위치 수집/저장 중단: $error. 시작을 눌러 재시도하세요.',
          ),
          onDone: () {
            if (state.isTracking)
              state = state.copyWith(
                isTracking: false,
                message: '위치 수집이 종료되었습니다. 시작을 눌러 재개하세요.',
              );
          },
          cancelOnError: true,
        );
  }

  String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${state.route.length}';
}
