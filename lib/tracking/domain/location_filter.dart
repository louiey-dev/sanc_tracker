import 'package:geolocator/geolocator.dart';

class LocationFilter {
  const LocationFilter({this.minimumDistanceM = 50});
  final double minimumDistanceM;

  bool shouldRecord(Position? previous, Position current) {
    if (previous == null) return true;
    return Geolocator.distanceBetween(
          previous.latitude,
          previous.longitude,
          current.latitude,
          current.longitude,
        ) >=
        minimumDistanceM;
  }
}
