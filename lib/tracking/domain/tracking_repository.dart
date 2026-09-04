import 'location_point.dart';
import 'tracking_session.dart';
import '../../map/map_marker.dart';
import '../../media/media_item.dart';

abstract interface class TrackingRepository {
  Future<void> saveSession(TrackingSession session);
  Future<void> updateSession(TrackingSession session);
  Future<void> savePoint(LocationPoint point);
  Future<void> deleteSession(String sessionId);
  Future<List<TrackingSession>> loadSessions();
  Future<TrackingSession?> loadActiveSession();
  Future<List<LocationPoint>> loadPoints(String sessionId);
  Future<void> saveMarker(MapMarker marker);
  Future<void> updateMarker(MapMarker marker);
  Future<void> deleteMarker(String markerId);
  Future<List<MapMarker>> loadMarkers();
  Future<void> saveMedia(MediaItem item);
  Future<List<MediaItem>> loadMedia(String markerId);
  Future<void> deleteMedia(String mediaId);
}
