import 'package:geolocator/geolocator.dart';

class LocationFilter {
  const LocationFilter({
    this.minimumDistanceM = 50,
    this.maximumIntervalSeconds = 30,
  });

  final double minimumDistanceM;
  final int maximumIntervalSeconds;

  bool shouldRecord(Position? previous, Position current) {
    if (previous == null) {
      return true;
    }
    final distance = Geolocator.distanceBetween(
      previous.latitude,
      previous.longitude,
      current.latitude,
      current.longitude,
    );
    if (distance >= minimumDistanceM) {
      return true;
    }
    final elapsedSeconds =
        current.timestamp.difference(previous.timestamp).inSeconds;
    return elapsedSeconds >= maximumIntervalSeconds;
  }
}
