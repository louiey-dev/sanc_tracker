import 'package:flutter_test/flutter_test.dart';
import 'package:sanc_tracker/export_import/domain/gpx_converter.dart';
import 'package:sanc_tracker/map/map_marker.dart';
import 'package:sanc_tracker/tracking/domain/location_point.dart';
import 'package:sanc_tracker/tracking/domain/tracking_session.dart';

void main() {
  group('GpxConverter', () {
    final testTime = DateTime.utc(2026, 9, 14, 10, 0, 0);

    final session = TrackingSession(
      id: 'session-1',
      startedAt: testTime,
      updatedAt: testTime,
      endedAt: testTime.add(const Duration(minutes: 10)),
      title: '북한산 등산로',
      status: TrackingSessionStatus.completed,
    );

    final points = [
      LocationPoint(
        id: 'p-1',
        sessionId: 'session-1',
        latitude: 37.6601,
        longitude: 126.9901,
        altitudeM: 250.5,
        speedMps: 1.2,
        recordedAt: testTime,
        updatedAt: testTime,
      ),
      LocationPoint(
        id: 'p-2',
        sessionId: 'session-1',
        latitude: 37.6620,
        longitude: 126.9920,
        altitudeM: 310.0,
        speedMps: 1.5,
        recordedAt: testTime.add(const Duration(minutes: 5)),
        updatedAt: testTime.add(const Duration(minutes: 5)),
      ),
    ];

    final markers = [
      const MapMarker(
        id: 'm-1',
        title: '대남문 쉼터',
        latitude: 37.6610,
        longitude: 126.9910,
        note: '경치 좋은 휴식 장소',
        category: 'viewpoint',
      ),
    ];

    test('toGpx exports valid GPX 1.1 with waypoints and track segments', () {
      final gpx = GpxConverter.toGpx(
        sessions: [session],
        points: points,
        markers: markers,
      );

      expect(gpx, contains('<?xml version="1.0" encoding="UTF-8"?>'));
      expect(gpx, contains('<gpx version="1.1"'));
      expect(gpx, contains('<wpt lat="37.6610000" lon="126.9910000">'));
      expect(gpx, contains('<name>대남문 쉼터</name>'));
      expect(gpx, contains('<desc>경치 좋은 휴식 장소</desc>'));
      expect(gpx, contains('<type>viewpoint</type>'));
      expect(gpx, contains('<trk>'));
      expect(gpx, contains('<name>북한산 등산로</name>'));
      expect(gpx, contains('<trkpt lat="37.6601000" lon="126.9901000">'));
      expect(gpx, contains('<ele>250.5</ele>'));
      expect(gpx, contains('<speed>1.20</speed>'));
    });

    test('fromGpx parses GPX XML string into sessions, points, and markers', () {
      final gpx = GpxConverter.toGpx(
        sessions: [session],
        points: points,
        markers: markers,
      );

      final bundle = GpxConverter.fromGpx(gpx);

      expect(bundle.sessions.length, 1);
      expect(bundle.sessions.first.title, '북한산 등산로');
      expect(bundle.points.length, 2);
      expect(bundle.points.first.latitude, closeTo(37.6601, 0.0001));
      expect(bundle.points.first.longitude, closeTo(126.9901, 0.0001));
      expect(bundle.points.first.altitudeM, closeTo(250.5, 0.1));

      expect(bundle.markers.length, 1);
      expect(bundle.markers.first.title, '대남문 쉼터');
      expect(bundle.markers.first.note, '경치 좋은 휴식 장소');
      expect(bundle.markers.first.category, 'viewpoint');
    });

    test('fromGpx fallback supports <rte> routes if <trk> is absent', () {
      const gpxWithRte = '''<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="External Planner">
  <rte>
    <name>추천 코스</name>
    <rtept lat="37.5000" lon="127.0000">
      <ele>50.0</ele>
    </rtept>
    <rtept lat="37.5050" lon="127.0050">
      <ele>55.0</ele>
    </rtept>
  </rte>
</gpx>''';

      final bundle = GpxConverter.fromGpx(gpxWithRte);

      expect(bundle.sessions.length, 1);
      expect(bundle.sessions.first.title, '추천 코스');
      expect(bundle.points.length, 2);
      expect(bundle.points.first.latitude, closeTo(37.5, 0.0001));
    });
  });
}
