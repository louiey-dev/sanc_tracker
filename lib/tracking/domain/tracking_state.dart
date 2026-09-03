import 'package:geolocator/geolocator.dart';

class TrackingState {
  const TrackingState({
    this.currentPosition,
    this.route = const [],
    this.message,
    this.isTracking = false,
  });
  final Position? currentPosition;
  final List<Position> route;
  final String? message;
  final bool isTracking;
  TrackingState copyWith({
    Position? currentPosition,
    List<Position>? route,
    String? message,
    bool clearMessage = false,
    bool? isTracking,
  }) => TrackingState(
    currentPosition: currentPosition ?? this.currentPosition,
    route: route ?? this.route,
    message: clearMessage ? null : (message ?? this.message),
    isTracking: isTracking ?? this.isTracking,
  );
}
