import 'package:flutter_test/flutter_test.dart';
import 'package:sanc_tracker/export_import/domain/geojson_converter.dart';
import 'package:sanc_tracker/map/map_marker.dart';
import 'package:sanc_tracker/tracking/domain/location_point.dart';
import 'package:sanc_tracker/tracking/domain/tracking_session.dart';

void main() {
  group('GeoJsonConverter', () {
    final testTime = DateTime.utc(2026, 9, 14, 10, 0, 0);

    final session = TrackingSession(
      id: 'session-1',
      startedAt: testTime,
      updatedAt: testTime,
      endedAt: testTime.add(const Duration(minutes: 10)),
      title: '한강 자전거길',
      status: TrackingSessionStatus.completed,
    );

    final points = [
      LocationPoint(
        id: 'p-1',
        sessionId: 'session-1',
        latitude: 37.5200,
        longitude: 126.9300,
        altitudeM: 15.0,
        speedMps: 4.5,
        recordedAt: testTime,
        updatedAt: testTime,
      ),
      LocationPoint(
        id: 'p-2',
        sessionId: 'session-1',
        latitude: 37.5250,
        longitude: 126.9350,
        altitudeM: 16.0,
        speedMps: 5.0,
        recordedAt: testTime.add(const Duration(minutes: 5)),
        updatedAt: testTime.add(const Duration(minutes: 5)),
      ),
    ];

    final markers = [
      const MapMarker(
        id: 'm-1',
        title: '여의도 쉼터',
        latitude: 37.5220,
        longitude: 126.9320,
        note: '편의점 앞 자전거 거치대',
        category: 'place',
      ),
    ];

    test('toGeoJson exports valid FeatureCollection with LineString and Point', () {
      final geoJson = GeoJsonConverter.toGeoJson(
        sessions: [session],
        points: points,
        markers: markers,
      );

      expect(geoJson, contains('"type": "FeatureCollection"'));
      expect(geoJson, contains('"type": "Point"'));
      expect(geoJson, contains('"title": "여의도 쉼터"'));
      expect(geoJson, contains('"type": "LineString"'));
      expect(geoJson, contains('"title": "한강 자전거길"'));
      expect(geoJson, contains('126.93'));
      expect(geoJson, contains('37.52'));
    });

    test('fromGeoJson parses FeatureCollection into sessions, points, and markers', () {
      final geoJson = GeoJsonConverter.toGeoJson(
        sessions: [session],
        points: points,
        markers: markers,
      );

      final bundle = GeoJsonConverter.fromGeoJson(geoJson);

      expect(bundle.sessions.length, 1);
      expect(bundle.sessions.first.title, '한강 자전거길');
      expect(bundle.points.length, 2);
      expect(bundle.points.first.latitude, closeTo(37.5200, 0.0001));
      expect(bundle.points.first.longitude, closeTo(126.9300, 0.0001));
      expect(bundle.points.first.altitudeM, closeTo(15.0, 0.1));

      expect(bundle.markers.length, 1);
      expect(bundle.markers.first.title, '여의도 쉼터');
      expect(bundle.markers.first.note, '편의점 앞 자전거 거치대');
    });

    test('fromGeoJson parses MultiLineString geometry correctly', () {
      const multiLineGeoJson = '''{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "geometry": {
        "type": "MultiLineString",
        "coordinates": [
          [[127.0, 37.5], [127.01, 37.51]],
          [[127.02, 37.52], [127.03, 37.53]]
        ]
      },
      "properties": {
        "name": "다중 구간 산책로"
      }
    }
  ]
}''';

      final bundle = GeoJsonConverter.fromGeoJson(multiLineGeoJson);

      expect(bundle.sessions.length, 2);
      expect(bundle.points.length, 4);
    });
  });
}
