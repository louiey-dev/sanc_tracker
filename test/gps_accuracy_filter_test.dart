import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sanc_tracker/tracking/domain/gps_kalman_filter.dart';
import 'package:sanc_tracker/tracking/domain/location_filter.dart';

Position createPoint({
  required double lat,
  required double lng,
  required DateTime timestamp,
  double accuracy = 5.0,
  double altitude = 100.0,
  double speed = 1.0,
}) {
  return Position(
    latitude: lat,
    longitude: lng,
    timestamp: timestamp,
    accuracy: accuracy,
    altitude: altitude,
    altitudeAccuracy: 1.0,
    heading: 0.0,
    headingAccuracy: 1.0,
    speed: speed,
    speedAccuracy: 1.0,
  );
}

void main() {
  group('LocationFilter - GPS Error & Drift Rejection', () {
    const filter = LocationFilter(
      minimumDistanceM: 20.0,
      maximumIntervalSeconds: 30,
      maxAccuracyM: 25.0,
      initialMaxAccuracyM: 35.0,
      stationaryRadiusM: 8.0,
      maxSpeedMps: 30.0,
    );

    final t0 = DateTime.utc(2026, 9, 7, 10, 0, 0);

    test('rejects initial point if accuracy exceeds initialMaxAccuracyM (35m)', () {
      final inaccurateStart = createPoint(
        lat: 37.5000,
        lng: 127.0000,
        timestamp: t0,
        accuracy: 45.0,
      );
      expect(filter.shouldRecord(null, inaccurateStart), isFalse);
    });

    test('accepts initial point if accuracy is within initialMaxAccuracyM', () {
      final accurateStart = createPoint(
        lat: 37.5000,
        lng: 127.0000,
        timestamp: t0,
        accuracy: 15.0,
      );
      expect(filter.shouldRecord(null, accurateStart), isTrue);
    });

    test('rejects subsequent point if accuracy exceeds maxAccuracyM (25m)', () {
      final prev = createPoint(
        lat: 37.5000,
        lng: 127.0000,
        timestamp: t0,
        accuracy: 10.0,
      );
      // 50m away but accuracy is 40m
      final noisyFix = createPoint(
        lat: 37.5005,
        lng: 127.0000,
        timestamp: t0.add(const Duration(seconds: 10)),
        accuracy: 40.0,
      );
      expect(filter.shouldRecord(prev, noisyFix), isFalse);
    });

    test('suppresses stationary drift within 8m even after maximumIntervalSeconds', () {
      final prev = createPoint(
        lat: 37.50000,
        lng: 127.00000,
        timestamp: t0,
        accuracy: 8.0,
      );
      // GPS jitter: ~4 meters away, 45 seconds later while resting
      final jitterAfter45s = createPoint(
        lat: 37.50003,
        lng: 127.00000,
        timestamp: t0.add(const Duration(seconds: 45)),
        accuracy: 8.0,
      );
      final dist = Geolocator.distanceBetween(
        prev.latitude,
        prev.longitude,
        jitterAfter45s.latitude,
        jitterAfter45s.longitude,
      );
      expect(dist, lessThan(8.0));
      // Should be rejected to eliminate fake distance accumulation while resting
      expect(filter.shouldRecord(prev, jitterAfter45s), isFalse);
    });

    test('rejects impossible multipath speed spikes (> 30 m/s = 108 km/h)', () {
      final prev = createPoint(
        lat: 37.5000,
        lng: 127.0000,
        timestamp: t0,
        accuracy: 10.0,
      );
      // Multipath jump: 200m away in 2 seconds = 100 m/s
      final spike = createPoint(
        lat: 37.5018,
        lng: 127.0000,
        timestamp: t0.add(const Duration(seconds: 2)),
        accuracy: 10.0,
      );
      final dist = Geolocator.distanceBetween(
        prev.latitude,
        prev.longitude,
        spike.latitude,
        spike.longitude,
      );
      expect(dist, greaterThan(150.0));
      expect(filter.shouldRecord(prev, spike), isFalse);
    });

    test('accepts valid trail movement exceeding minimumDistanceM (20m)', () {
      final prev = createPoint(
        lat: 37.5000,
        lng: 127.0000,
        timestamp: t0,
        accuracy: 10.0,
      );
      // ~25m away in 15 seconds (1.6 m/s walking speed)
      final moved25m = createPoint(
        lat: 37.50023,
        lng: 127.0000,
        timestamp: t0.add(const Duration(seconds: 15)),
        accuracy: 10.0,
      );
      final dist = Geolocator.distanceBetween(
        prev.latitude,
        prev.longitude,
        moved25m.latitude,
        moved25m.longitude,
      );
      expect(dist, greaterThan(20.0));
      expect(filter.shouldRecord(prev, moved25m), isTrue);
    });

    test('accepts confirmed gentle movement (between 8m and 20m) after 30 seconds', () {
      final prev = createPoint(
        lat: 37.5000,
        lng: 127.0000,
        timestamp: t0,
        accuracy: 8.0,
      );
      // ~13m away in 32 seconds (steep uphill climb)
      final slowClimb = createPoint(
        lat: 37.50012,
        lng: 127.0000,
        timestamp: t0.add(const Duration(seconds: 32)),
        accuracy: 8.0,
      );
      final dist = Geolocator.distanceBetween(
        prev.latitude,
        prev.longitude,
        slowClimb.latitude,
        slowClimb.longitude,
      );
      expect(dist, greaterThan(8.0));
      expect(dist, lessThan(20.0));
      expect(filter.shouldRecord(prev, slowClimb), isTrue);
    });
  });

  group('GpsKalmanFilter - Noise Smoothing', () {
    final t0 = DateTime.utc(2026, 9, 7, 10, 0, 0);

    test('initializes on first point and matches measurement', () {
      final kalman = GpsKalmanFilter();
      final p1 = createPoint(
        lat: 37.5000,
        lng: 127.0000,
        timestamp: t0,
        accuracy: 10.0,
      );
      final filtered = kalman.filter(p1);
      expect(filtered.latitude, p1.latitude);
      expect(filtered.longitude, p1.longitude);
      expect(kalman.isInitialized, isTrue);
    });

    test('smooths out erratic noisy spikes and resists jumps', () {
      final kalman = GpsKalmanFilter();
      final p1 = createPoint(
        lat: 37.5000,
        lng: 127.0000,
        timestamp: t0,
        accuracy: 5.0,
      );
      kalman.filter(p1);

      // Next point is 20m noisy jump with low accuracy (25m radius)
      final noisyFix = createPoint(
        lat: 37.50018,
        lng: 127.0000,
        timestamp: t0.add(const Duration(seconds: 2)),
        accuracy: 25.0,
      );
      final smoothed = kalman.filter(noisyFix);

      // The smoothed position should be between p1 and noisyFix, but strongly dampened
      expect(smoothed.latitude, greaterThan(p1.latitude));
      expect(smoothed.latitude, lessThan(noisyFix.latitude));

      final rawDist = Geolocator.distanceBetween(
        p1.latitude,
        p1.longitude,
        noisyFix.latitude,
        noisyFix.longitude,
      );
      final smoothedDist = Geolocator.distanceBetween(
        p1.latitude,
        p1.longitude,
        smoothed.latitude,
        smoothed.longitude,
      );
      // Smoothed jump is significantly less than the raw 20m jump
      expect(smoothedDist, lessThan(rawDist * 0.5));
    });

    test('re-anchors to measurement when time gap exceeds 30 seconds', () {
      final kalman = GpsKalmanFilter();
      final p1 = createPoint(
        lat: 37.5000,
        lng: 127.0000,
        timestamp: t0,
        accuracy: 5.0,
      );
      kalman.filter(p1);

      // Gap of 60 seconds (user stopped or resumed after long pause)
      final p2 = createPoint(
        lat: 37.5050,
        lng: 127.0050,
        timestamp: t0.add(const Duration(seconds: 60)),
        accuracy: 10.0,
      );
      final reanchored = kalman.filter(p2);
      // Should immediately re-anchor without dragging across the 60s gap
      expect(reanchored.latitude, p2.latitude);
      expect(reanchored.longitude, p2.longitude);
    });

    test('reset clears state and allows clean re-initialization', () {
      final kalman = GpsKalmanFilter();
      final p1 = createPoint(
        lat: 37.5000,
        lng: 127.0000,
        timestamp: t0,
      );
      kalman.filter(p1);
      expect(kalman.isInitialized, isTrue);

      kalman.reset();
      expect(kalman.isInitialized, isFalse);

      final p2 = createPoint(
        lat: 38.0000,
        lng: 128.0000,
        timestamp: t0.add(const Duration(seconds: 1)),
      );
      final secondInit = kalman.filter(p2);
      expect(secondInit.latitude, 38.0000);
      expect(secondInit.longitude, 128.0000);
    });

    test('setState restores Kalman filter state from previous session point', () {
      final kalman = GpsKalmanFilter();
      kalman.setState(
        latitude: 37.5100,
        longitude: 127.0200,
        altitude: 250.0,
        accuracyM: 8.0,
        timestamp: t0,
      );
      expect(kalman.isInitialized, isTrue);

      final nextPoint = createPoint(
        lat: 37.5102,
        lng: 127.0200,
        timestamp: t0.add(const Duration(seconds: 2)),
        accuracy: 8.0,
      );
      final filtered = kalman.filter(nextPoint);
      expect(filtered.latitude, greaterThan(37.5100));
      expect(filtered.latitude, lessThan(37.5102));
    });
  });
}
