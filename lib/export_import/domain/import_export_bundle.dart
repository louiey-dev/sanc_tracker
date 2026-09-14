import '../../map/map_marker.dart';
import '../../tracking/domain/location_point.dart';
import '../../tracking/domain/tracking_session.dart';

/// Bundle containing sessions, location points, and markers
/// for export and import.
class ImportExportBundle {
  const ImportExportBundle({
    this.sessions = const [],
    this.points = const [],
    this.markers = const [],
  });

  final List<TrackingSession> sessions;
  final List<LocationPoint> points;
  final List<MapMarker> markers;

  bool get isEmpty => sessions.isEmpty && points.isEmpty && markers.isEmpty;
  bool get isNotEmpty => !isEmpty;

  int get totalSessionsCount => sessions.length;
  int get totalPointsCount => points.length;
  int get totalMarkersCount => markers.length;
}
