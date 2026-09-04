import 'package:geolocator/geolocator.dart';

abstract interface class LocationService {
  Future<bool> isServiceEnabled();
  Future<LocationPermission> requestPermissionIfNeeded();
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
    return permission;
  }

  @override
  Stream<Position> positionStream() => Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      // MVP 1 기본 수집 정책: 50m 이동 시 위치를 수집한다.
      // 정지 상태에서의 최대 5분 완화 주기는 백그라운드 안정화 단계에서 추가한다.
      distanceFilter: 50,
    ),
  );
}
