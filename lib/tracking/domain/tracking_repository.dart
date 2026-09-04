import 'location_point.dart';
import 'tracking_session.dart';

abstract interface class TrackingRepository {
  Future<void> saveSession(TrackingSession session);
  Future<void> updateSession(TrackingSession session);
  Future<void> savePoint(LocationPoint point);
  Future<List<TrackingSession>> loadSessions();
  Future<TrackingSession?> loadActiveSession();
  Future<List<LocationPoint>> loadPoints(String sessionId);
}
