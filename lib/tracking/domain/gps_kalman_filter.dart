import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';

/// 2D Kalman Filter designed for GPS latitude and longitude tracking.
///
/// Features:
/// - Balances measurement uncertainty (GPS accuracy radius) against process noise.
/// - High accuracy fixes (small error circle) pull the filter rapidly.
/// - Low accuracy fixes (large error circle) have low gain and do not cause jumps.
/// - Adapts to variable time intervals between GPS fixes.
/// - Automatically re-anchors if time gap > 30 seconds to prevent lag.
class GpsKalmanFilter {
  GpsKalmanFilter({
    this.processNoiseMps = 3.0,
  });

  /// Process noise in meters per second (approximate walking/hiking motion dynamics).
  final double processNoiseMps;

  double? _lat;
  double? _lng;
  double? _alt;
  double _varianceLat = 0.0;
  double _varianceLng = 0.0;
  double _varianceAlt = 0.0;
  DateTime? _lastTimestamp;

  bool get isInitialized => _lat != null && _lng != null;

  /// Resets the filter state.
  void reset() {
    _lat = null;
    _lng = null;
    _alt = null;
    _varianceLat = 0.0;
    _varianceLng = 0.0;
    _varianceAlt = 0.0;
    _lastTimestamp = null;
  }

  /// Manually initializes or restores the filter state (e.g. on session restoration).
  void setState({
    required double latitude,
    required double longitude,
    double? altitude,
    double accuracyM = 10.0,
    DateTime? timestamp,
  }) {
    _lat = latitude;
    _lng = longitude;
    _alt = altitude;
    final accuracy = accuracyM > 0 ? accuracyM : 10.0;
    final sigmaLat = accuracy / 111319.5;
    final cosLat = math.cos(latitude * math.pi / 180.0).abs().clamp(0.01, 1.0);
    final sigmaLng = accuracy / (111319.5 * cosLat);
    _varianceLat = sigmaLat * sigmaLat;
    _varianceLng = sigmaLng * sigmaLng;
    _varianceAlt = (accuracy * 2.0) * (accuracy * 2.0);
    _lastTimestamp = timestamp ?? DateTime.now();
  }

  /// Filters a raw [Position] measurement and returns the smoothed [Position].
  Position filter(Position position) {
    final accuracy = position.accuracy > 0 ? position.accuracy : 10.0;
    final cosLat =
        math.cos(position.latitude * math.pi / 180.0).abs().clamp(0.01, 1.0);
    final sigmaLat = accuracy / 111319.5;
    final sigmaLng = accuracy / (111319.5 * cosLat);
    final rLat = sigmaLat * sigmaLat;
    final rLng = sigmaLng * sigmaLng;

    if (_lat == null || _lng == null || _lastTimestamp == null) {
      _lat = position.latitude;
      _lng = position.longitude;
      _alt = position.altitude;
      _varianceLat = rLat;
      _varianceLng = rLng;
      _varianceAlt = 25.0;
      _lastTimestamp = position.timestamp;
      return position;
    }

    final dt =
        position.timestamp.difference(_lastTimestamp!).inMilliseconds / 1000.0;

    // If gap is negative or longer than 30s, re-anchor directly to avoid dragging
    if (dt > 30.0 || dt <= 0.0) {
      _lat = position.latitude;
      _lng = position.longitude;
      _alt = position.altitude;
      _varianceLat = rLat;
      _varianceLng = rLng;
      _varianceAlt = 25.0;
      _lastTimestamp = position.timestamp;
      return position;
    }

    // Process noise variance Q (degrees^2)
    final qMeters = processNoiseMps * dt;
    final qLatDegrees = qMeters / 111319.5;
    final qLngDegrees = qMeters / (111319.5 * cosLat);
    final qLat = qLatDegrees * qLatDegrees;
    final qLng = qLngDegrees * qLngDegrees;

    // 1. Predict variance
    final pLatPrior = _varianceLat + qLat;
    final pLngPrior = _varianceLng + qLng;

    // 2. Kalman Gain
    final kLat = pLatPrior / (pLatPrior + rLat);
    final kLng = pLngPrior / (pLngPrior + rLng);

    // 3. Update State
    _lat = _lat! + kLat * (position.latitude - _lat!);
    _lng = _lng! + kLng * (position.longitude - _lng!);

    // 4. Update Variance
    _varianceLat = (1.0 - kLat) * pLatPrior;
    _varianceLng = (1.0 - kLng) * pLngPrior;

    // Altitude smoothing (if altitude provided)
    var filteredAlt = position.altitude;
    if (position.altitude != 0.0) {
      final rAlt = position.altitudeAccuracy > 0
          ? position.altitudeAccuracy
          : accuracy * 2.0;
      final rAltVar = rAlt * rAlt;
      final qAltVar = (1.5 * dt) * (1.5 * dt);
      final pAltPrior = _varianceAlt + qAltVar;
      final kAlt = pAltPrior / (pAltPrior + rAltVar);
      _alt = (_alt ?? position.altitude) +
          kAlt * (position.altitude - (_alt ?? position.altitude));
      _varianceAlt = (1.0 - kAlt) * pAltPrior;
      filteredAlt = _alt!;
    }

    _lastTimestamp = position.timestamp;

    // Filtered accuracy estimate in meters
    final estAccuracy =
        (math.sqrt(_varianceLat) * 111319.5).clamp(1.0, accuracy);

    return Position(
      latitude: _lat!,
      longitude: _lng!,
      timestamp: position.timestamp,
      accuracy: estAccuracy,
      altitude: filteredAlt,
      altitudeAccuracy: position.altitudeAccuracy,
      heading: position.heading,
      headingAccuracy: position.headingAccuracy,
      speed: position.speed,
      speedAccuracy: position.speedAccuracy,
      floor: position.floor,
      isMocked: position.isMocked,
    );
  }
}
