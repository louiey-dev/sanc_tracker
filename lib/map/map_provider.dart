import 'package:geolocator/geolocator.dart';

abstract interface class MapProvider {
  String get name;
  Future<void> initialize();
  Future<void> moveCamera(Position position);
}
