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
      distanceFilter: 20,
    ),
  );
}
