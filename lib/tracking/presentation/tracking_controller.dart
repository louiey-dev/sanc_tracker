import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../data/location_service.dart';
import '../data/tracking_preferences.dart';
import '../domain/tracking_state.dart';
import '../domain/location_point.dart';
import '../domain/location_filter.dart';
import '../domain/gps_kalman_filter.dart';
import '../domain/tracking_repository.dart';
import '../domain/tracking_session.dart';
import '../../map/map_marker.dart';
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
final sessionsListProvider =
    FutureProvider.autoDispose<List<TrackingSession>>((ref) async {
  final repository = ref.watch(trackingRepositoryProvider);
  return repository.loadSessions();
});
final markersListProvider =
    FutureProvider.autoDispose<List<MapMarker>>((ref) async {
  final repository = ref.watch(trackingRepositoryProvider);
  return repository.loadMarkers();
});
final trackingControllerProvider =
    NotifierProvider<TrackingController, TrackingState>(TrackingController.new);

class TrackingController extends Notifier<TrackingState> {
  final LocationFilter _filter = const LocationFilter();
  final GpsKalmanFilter _kalmanFilter = GpsKalmanFilter();
  StreamSubscription<Position>? _subscription;
  Timer? _durationTimer;
  TrackingSession? _session;
  bool _busy = false;

  @override
  TrackingState build() {
    ref.onDispose(() {
      _subscription?.cancel();
      _durationTimer?.cancel();
      _kalmanFilter.reset();
    });
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
      var totalDist = 0.0;
      for (var i = 1; i < route.length; i++) {
        totalDist += Geolocator.distanceBetween(
          route[i - 1].latitude,
          route[i - 1].longitude,
          route[i].latitude,
          route[i].longitude,
        );
      }
      if (route.isNotEmpty) {
        final last = route.last;
        _kalmanFilter.setState(
          latitude: last.latitude,
          longitude: last.longitude,
          altitude: last.altitude,
          accuracyM: last.accuracy,
          timestamp: last.timestamp,
        );
      }
      state = state.copyWith(
        currentPosition: route.isEmpty ? null : route.last,
        route: route,
        distanceMeters: totalDist,
        duration: DateTime.now().toUtc().difference(session.startedAt),
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
        permission == LocationPermission.deniedForever) {
      return;
    }
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
        permission == LocationPermission.deniedForever) {
      return;
    }
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
    var totalDist = 0.0;
    for (var i = 1; i < route.length; i++) {
      totalDist += Geolocator.distanceBetween(
        route[i - 1].latitude,
        route[i - 1].longitude,
        route[i].latitude,
        route[i].longitude,
      );
    }
    final sessionEnd = session.endedAt ?? session.updatedAt;
    final duration = sessionEnd.difference(session.startedAt);
    final displayName =
        session.title != null && session.title!.trim().isNotEmpty
            ? '“${session.title}”'
            : '저장 경로';
    if (!state.isTracking) {
      state = state.copyWith(
        savedRoute: route,
        viewedSession: session,
        distanceMeters: totalDist,
        duration: duration.isNegative ? Duration.zero : duration,
        message: '$displayName (${route.length}개 지점)을 불러왔습니다.',
      );
    } else {
      state = state.copyWith(
        savedRoute: route,
        viewedSession: session,
        message: '$displayName (${route.length}개 지점)을 불러왔습니다. (추적 계속 진행 중)',
      );
    }
  }

  void clearLoadedSessionRoute() {
    if (!state.isTracking) {
      state = state.copyWith(
        clearSavedRoute: true,
        clearViewedSession: true,
        distanceMeters: 0.0,
        duration: Duration.zero,
        currentSpeedKmh: 0.0,
        message: '저장 경로 보기를 종료했습니다.',
      );
    } else {
      state = state.copyWith(
        clearSavedRoute: true,
        clearViewedSession: true,
        message: '저장 경로 보기를 종료했습니다.',
      );
    }
  }

  void clearMessage() {
    state = state.copyWith(clearMessage: true);
  }

  Future<void> toggleTracking() async {
    if (_busy) return;
    _busy = true;
    try {
      if (state.isTracking) {
        await _subscription?.cancel();
        _subscription = null;
        _durationTimer?.cancel();
        _durationTimer = null;
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
        _kalmanFilter.reset();
        ref.invalidate(sessionsListProvider);
        state = state.copyWith(
          isTracking: false,
          currentSpeedKmh: 0.0,
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
        _kalmanFilter.reset();
        final session = TrackingSession(
          id: _newId(),
          startedAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        );
        await ref.read(trackingRepositoryProvider).saveSession(session);
        _session = session;
        state = state.copyWith(
          route: [],
          distanceMeters: 0.0,
          duration: Duration.zero,
          currentSpeedKmh: 0.0,
        );
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
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!state.isTracking) return;
      state = state.copyWith(
        duration: DateTime.now().toUtc().difference(session.startedAt),
      );
    });
    _subscription = service
        .positionStream()
        .listen(
          (position) async {
            final previous = state.route.isEmpty ? null : state.route.last;
            final shouldRecord = _filter.shouldRecord(previous, position);
            final processedPosition =
                shouldRecord ? _kalmanFilter.filter(position) : position;
            if (shouldRecord) {
              try {
                await ref
                    .read(trackingRepositoryProvider)
                    .savePoint(
                      LocationPoint(
                        id: _newId(),
                        sessionId: session.id,
                        latitude: processedPosition.latitude,
                        longitude: processedPosition.longitude,
                        recordedAt: processedPosition.timestamp,
                        updatedAt: DateTime.now().toUtc(),
                        accuracyM: processedPosition.accuracy,
                        altitudeM: processedPosition.altitude,
                        speedMps: processedPosition.speed,
                        headingDeg: processedPosition.heading,
                      ),
                    );
              } catch (error) {
                _durationTimer?.cancel();
                _durationTimer = null;
                state = state.copyWith(
                  isTracking: false,
                  currentSpeedKmh: 0.0,
                  message: '위치 수집/저장 중단: $error. 시작을 눌러 재시도하세요.',
                );
                await _subscription?.cancel();
                _subscription = null;
                return;
              }
            }
            var newDistance = state.distanceMeters;
            if (shouldRecord && previous != null) {
              newDistance += Geolocator.distanceBetween(
                previous.latitude,
                previous.longitude,
                processedPosition.latitude,
                processedPosition.longitude,
              );
            }
            final speedKmh =
                position.speed > 0.5 ? (position.speed * 3.6) : 0.0;
            final accuracyMessage = position.accuracy > 30
                ? 'GPS 정확도가 낮습니다(±${position.accuracy.toStringAsFixed(0)}m).'
                : null;
            state = state.copyWith(
              currentPosition: processedPosition,
              route: shouldRecord
                  ? [...state.route, processedPosition]
                  : state.route,
              distanceMeters: newDistance,
              currentSpeedKmh: speedKmh,
              message: accuracyMessage,
              clearMessage: accuracyMessage == null,
            );
          },
          onError: (Object error) {
            _durationTimer?.cancel();
            _durationTimer = null;
            state = state.copyWith(
              isTracking: false,
              currentSpeedKmh: 0.0,
              message: '위치 수집/저장 중단: $error. 시작을 눌러 재시도하세요.',
            );
          },
          onDone: () {
            _durationTimer?.cancel();
            _durationTimer = null;
            if (state.isTracking) {
              state = state.copyWith(
                isTracking: false,
                currentSpeedKmh: 0.0,
                message: '위치 수집이 종료되었습니다. 시작을 눌러 재개하세요.',
              );
            }
          },
          cancelOnError: true,
        );
  }

  String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${state.route.length}';
}
