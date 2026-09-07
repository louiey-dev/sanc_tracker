import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sanc_tracker/tracking/data/location_service.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('Android enables foreground notification and CPU wake lock', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final settings =
        GeolocatorLocationService(intervalSeconds: 30).settings
            as AndroidSettings;
    expect(settings.intervalDuration, const Duration(seconds: 30));
    expect(settings.foregroundNotificationConfig!.enableWakeLock, isTrue);
    expect(settings.foregroundNotificationConfig!.enableWifiLock, isFalse);
    expect(settings.distanceFilter, 0);
  });

  test('iOS continues background updates without automatic pause', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final settings = GeolocatorLocationService().settings as AppleSettings;
    expect(settings.allowBackgroundLocationUpdates, isTrue);
    expect(settings.pauseLocationUpdatesAutomatically, isFalse);
    expect(settings.showBackgroundLocationIndicator, isTrue);
  });

  test('battery saving lowers requested accuracy', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(
      GeolocatorLocationService(batterySaving: true).settings.accuracy,
      LocationAccuracy.medium,
    );
  });
}
