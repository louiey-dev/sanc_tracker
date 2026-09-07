import 'package:geolocator/geolocator.dart';
import 'tracking_session.dart';

class TrackingState {
  const TrackingState({
    this.currentPosition,
    this.route = const [],
    this.message,
    this.isTracking = false,
    this.duration = Duration.zero,
    this.distanceMeters = 0.0,
    this.currentSpeedKmh = 0.0,
    this.savedRoute = const [],
    this.viewedSession,
  });

  final Position? currentPosition;
  final List<Position> route;
  final String? message;
  final bool isTracking;
  final Duration duration;
  final double distanceMeters;
  final double currentSpeedKmh;
  final List<Position> savedRoute;
  final TrackingSession? viewedSession;

  TrackingState copyWith({
    Position? currentPosition,
    List<Position>? route,
    String? message,
    bool clearMessage = false,
    bool? isTracking,
    Duration? duration,
    double? distanceMeters,
    double? currentSpeedKmh,
    List<Position>? savedRoute,
    bool clearSavedRoute = false,
    TrackingSession? viewedSession,
    bool clearViewedSession = false,
  }) => TrackingState(
    currentPosition: currentPosition ?? this.currentPosition,
    route: route ?? this.route,
    message: clearMessage ? null : (message ?? this.message),
    isTracking: isTracking ?? this.isTracking,
    duration: duration ?? this.duration,
    distanceMeters: distanceMeters ?? this.distanceMeters,
    currentSpeedKmh: currentSpeedKmh ?? this.currentSpeedKmh,
    savedRoute: clearSavedRoute ? const [] : (savedRoute ?? this.savedRoute),
    viewedSession:
        clearViewedSession ? null : (viewedSession ?? this.viewedSession),
  );
}
