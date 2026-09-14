import 'package:flutter_test/flutter_test.dart';
import 'package:sanc_tracker/export_import/application/export_import_service.dart';
import 'package:sanc_tracker/map/map_marker.dart';
import 'package:sanc_tracker/media/media_item.dart';
import 'package:sanc_tracker/tracking/domain/location_point.dart';
import 'package:sanc_tracker/tracking/domain/tracking_repository.dart';
import 'package:sanc_tracker/tracking/domain/tracking_session.dart';

class InMemoryTrackingRepository implements TrackingRepository {
  final List<TrackingSession> sessions = [];
  final List<LocationPoint> points = [];
  final List<MapMarker> markers = [];
  final List<MediaItem> media = [];

  @override
  Future<void> saveSession(TrackingSession session) async {
    sessions.add(session);
  }

  @override
  Future<void> updateSession(TrackingSession session) async {
    final idx = sessions.indexWhere((s) => s.id == session.id);
    if (idx >= 0) sessions[idx] = session;
  }

  @override
  Future<void> savePoint(LocationPoint point) async {
    points.add(point);
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    sessions.removeWhere((s) => s.id == sessionId);
    points.removeWhere((p) => p.sessionId == sessionId);
  }

  @override
  Future<List<TrackingSession>> loadSessions() async => List.of(sessions);

  @override
  Future<TrackingSession?> loadActiveSession() async => null;

  @override
  Future<List<LocationPoint>> loadPoints(String sessionId) async =>
      points.where((p) => p.sessionId == sessionId).toList();

  @override
  Future<void> saveMarker(MapMarker marker) async {
    markers.add(marker);
  }

  @override
  Future<void> updateMarker(MapMarker marker) async {
    final idx = markers.indexWhere((m) => m.id == marker.id);
    if (idx >= 0) markers[idx] = marker;
  }

  @override
  Future<void> deleteMarker(String markerId) async {
    markers.removeWhere((m) => m.id == markerId);
  }

  @override
  Future<List<MapMarker>> loadMarkers() async => List.of(markers);

  @override
  Future<void> saveMedia(MediaItem item) async {
    media.add(item);
  }

  @override
  Future<List<MediaItem>> loadMedia(String markerId) async =>
      media.where((m) => m.markerId == markerId).toList();

  @override
  Future<void> deleteMedia(String mediaId) async {
    media.removeWhere((m) => m.id == mediaId);
  }
}

void main() {
  group('ExportImportService', () {
    late InMemoryTrackingRepository repo;
    late ExportImportService service;

    setUp(() {
      repo = InMemoryTrackingRepository();
      service = ExportImportService(repository: repo);
    });

    test('parseContent auto-detects and parses GPX content', () {
      const gpx = '''<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="Test">
  <wpt lat="37.5" lon="127.0"><name>마커1</name></wpt>
  <trk>
    <name>세션1</name>
    <trkseg>
      <trkpt lat="37.5" lon="127.0"><time>2026-09-14T10:00:00Z</time></trkpt>
    </trkseg>
  </trk>
</gpx>''';

      final bundle = service.parseContent(gpx);
      expect(bundle.sessions.length, 1);
      expect(bundle.sessions.first.title, '세션1');
      expect(bundle.points.length, 1);
      expect(bundle.markers.length, 1);
      expect(bundle.markers.first.title, '마커1');
    });

    test('parseContent auto-detects and parses GeoJSON content', () {
      const geoJson = '''{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "geometry": { "type": "Point", "coordinates": [127.0, 37.5] },
      "properties": { "title": "장소A" }
    },
    {
      "type": "Feature",
      "geometry": { "type": "LineString", "coordinates": [[127.0, 37.5], [127.01, 37.51]] },
      "properties": { "title": "경로A" }
    }
  ]
}''';

      final bundle = service.parseContent(geoJson);
      expect(bundle.sessions.length, 1);
      expect(bundle.sessions.first.title, '경로A');
      expect(bundle.points.length, 2);
      expect(bundle.markers.length, 1);
      expect(bundle.markers.first.title, '장소A');
    });

    test('parseContent throws FormatException on invalid content', () {
      expect(() => service.parseContent('random invalid string text'), throwsA(isA<FormatException>()));
    });

    test('commitImport persists bundle into repository safely', () async {
      const gpx = '''<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="Test">
  <wpt lat="37.5" lon="127.0"><name>마커1</name></wpt>
  <trk>
    <name>세션1</name>
    <trkseg>
      <trkpt lat="37.5" lon="127.0"><time>2026-09-14T10:00:00Z</time></trkpt>
    </trkseg>
  </trk>
</gpx>''';

      final bundle = service.parseContent(gpx);
      await service.commitImport(bundle);

      expect(repo.sessions.length, 1);
      expect(repo.points.length, 1);
      expect(repo.markers.length, 1);
    });
  });
}
