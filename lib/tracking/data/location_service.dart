import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

abstract interface class LocationService {
  Future<bool> isServiceEnabled();
  Future<LocationPermission> requestPermissionIfNeeded();
  Future<Position?> getLastKnownPosition();
  Future<Position> getCurrentPosition();
  Stream<Position> positionStream();
}

class GeolocatorLocationService implements LocationService {
  GeolocatorLocationService({
    this.batterySaving = false,
    this.intervalSeconds = 10,
  });
  final bool batterySaving;
  final int intervalSeconds;
  @override
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();
  @override
  Future<LocationPermission> requestPermissionIfNeeded() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission;
  }
  @override
  Future<Position?> getLastKnownPosition() => Geolocator.getLastKnownPosition();

  @override
  Future<Position> getCurrentPosition() => Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 15),
    ),
  );

  @override
  Stream<Position> positionStream() =>
      Geolocator.getPositionStream(locationSettings: settings);

  LocationSettings get settings {
    final accuracy = batterySaving
        ? LocationAccuracy.medium
        : LocationAccuracy.high;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: accuracy,
        intervalDuration: Duration(seconds: intervalSeconds),
        distanceFilter: 0,
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: 'SANC Tracker 위치 기록 중',
          notificationText: '잠금 상태에서도 이동 경로를 기록하고 있습니다.',
          enableWakeLock: true,
          setOngoing: true,
          enableWifiLock: false,
        ),
      );
    }
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      return AppleSettings(
        accuracy: accuracy,
        distanceFilter: batterySaving ? 100 : 10,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    }
    return LocationSettings(accuracy: accuracy, distanceFilter: 50);
  }
}
