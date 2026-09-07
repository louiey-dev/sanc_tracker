import 'package:geolocator/geolocator.dart';

/// Multi-stage GPS filter for outdoor mountain and trail tracking.
///
/// Filters out:
/// 1. Low accuracy fixes (accuracy > [maxAccuracyM] or [initialMaxAccuracyM])
/// 2. Stationary drift / jitter while resting (distance < [stationaryRadiusM])
/// 3. Impossible multipath reflection spikes (speed > [maxSpeedMps])
///
/// Accepts fixes when:
/// 1. Distance exceeds [minimumDistanceM] (significant trail progress)
/// 2. Movement exceeds [stationaryRadiusM] after [maximumIntervalSeconds]
class LocationFilter {
  const LocationFilter({
    this.minimumDistanceM = 20.0,
    this.maximumIntervalSeconds = 30,
    this.maxAccuracyM = 25.0,
    this.initialMaxAccuracyM = 35.0,
    this.stationaryRadiusM = 8.0,
    this.maxSpeedMps = 30.0,
  });

  /// Minimum distance in meters required to record a new position point.
  final double minimumDistanceM;

  /// Maximum seconds between recorded points when confirmed movement is detected.
  final int maximumIntervalSeconds;

  /// Maximum acceptable GPS accuracy uncertainty in meters for subsequent fixes.
  final double maxAccuracyM;

  /// Maximum acceptable accuracy uncertainty for the initial starting fix.
  final double initialMaxAccuracyM;

  /// Radius in meters within which movements are considered stationary jitter/drift.
  final double stationaryRadiusM;

  /// Maximum plausible speed in meters/second (30 m/s = 108 km/h).
  /// Rejects multipath reflection spikes across cliffs or buildings.
  final double maxSpeedMps;

  bool shouldRecord(Position? previous, Position current) {
    // 1. Accuracy Gate: Discard low-confidence fixes.
    if (current.accuracy > 0) {
      final accuracyLimit =
          previous == null ? initialMaxAccuracyM : maxAccuracyM;
      if (current.accuracy > accuracyLimit) {
        return false;
      }
    }

    if (previous == null) {
      return true;
    }

    // 2. Distance Calculation
    final distance = Geolocator.distanceBetween(
      previous.latitude,
      previous.longitude,
      current.latitude,
      current.longitude,
    );

    // 3. Stationary Drift Protection:
    // When stationary, GPS jitter fluctuates by 3-6m. Suppress recording
    // even if maximumIntervalSeconds has elapsed, preventing fake distance buildup.
    if (distance < stationaryRadiusM) {
      return false;
    }

    // 4. Spike / Multipath Gate (speed check)
    final elapsedMs =
        current.timestamp.difference(previous.timestamp).inMilliseconds;
    if (elapsedMs > 0) {
      final speedMps = distance / (elapsedMs / 1000.0);
      if (speedMps > maxSpeedMps) {
        return false;
      }
    }

    // 5. Significant Trail Movement
    if (distance >= minimumDistanceM) {
      return true;
    }

    // 6. Confirmed Gentle Movement Over Time
    final elapsedSeconds = elapsedMs ~/ 1000;
    return elapsedSeconds >= maximumIntervalSeconds;
  }
}

