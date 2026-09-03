import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../data/location_service.dart';
import '../domain/tracking_state.dart';

final locationServiceProvider = Provider<LocationService>(
  (ref) => GeolocatorLocationService(),
);
final trackingControllerProvider =
    NotifierProvider<TrackingController, TrackingState>(TrackingController.new);

class TrackingController extends Notifier<TrackingState> {
  StreamSubscription<Position>? _subscription;
  @override
  TrackingState build() {
    ref.onDispose(() => _subscription?.cancel());
    return const TrackingState();
  }

  Future<void> toggleTracking() async {
    if (state.isTracking) {
      await _subscription?.cancel();
      _subscription = null;
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
    _subscription = service.positionStream().listen(
      (position) => state = state.copyWith(
        currentPosition: position,
        route: [...state.route, position],
        clearMessage: true,
      ),
      onError: (Object error) =>
          state = state.copyWith(message: '위치 수집 오류: $error'),
    );
    state = state.copyWith(isTracking: true);
  }
}
