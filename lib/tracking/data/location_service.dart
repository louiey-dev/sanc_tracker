import 'package:geolocator/geolocator.dart';

abstract interface class LocationService {
  Future<bool> isServiceEnabled();
  Future<LocationPermission> requestPermissionIfNeeded();
  Future<Position> getCurrentPosition();
  Stream<Position> positionStream();
}

class GeolocatorLocationService implements LocationService {
  @override
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();
  @override
  Future<LocationPermission> requestPermissionIfNeeded() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied)
      permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.whileInUse)
      permission = await Geolocator.requestPermission();
    return permission;
  }

  @override
  Future<Position> getCurrentPosition() => Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
  );

  @override
  Stream<Position> positionStream() => Geolocator.getPositionStream(
    locationSettings: AndroidSettings(
      accuracy: LocationAccuracy.high,
      // MVP 1 기본 수집 정책: 50m 이동 시 위치를 수집한다.
      // 정지 상태에서의 최대 5분 완화 주기는 백그라운드 안정화 단계에서 추가한다.
      distanceFilter: 50,
      foregroundNotificationConfig: ForegroundNotificationConfig(
        notificationTitle: 'SANC Tracker 위치 기록 중',
        notificationText: '잠금 상태에서도 이동 경로를 기록하고 있습니다.',
        enableWakeLock: true,
        setOngoing: true,
        enableWifiLock: true,
      ),
    ),
  );
}
