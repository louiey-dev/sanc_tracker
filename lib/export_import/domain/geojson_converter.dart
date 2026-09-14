import 'dart:convert';
import '../../map/map_marker.dart';
import '../../tracking/domain/location_point.dart';
import '../../tracking/domain/tracking_session.dart';
import 'import_export_bundle.dart';

class GeoJsonConverter {
  const GeoJsonConverter._();

  /// Converts tracking sessions, points, and markers to GeoJSON RFC 7946 string.
  static String toGeoJson({
    List<TrackingSession> sessions = const [],
    List<LocationPoint> points = const [],
    List<MapMarker> markers = const [],
  }) {
    final features = <Map<String, dynamic>>[];

    // 1. Markers -> Point features
    for (final marker in markers) {
      features.add({
        'type': 'Feature',
        'id': marker.id,
        'geometry': {
          'type': 'Point',
          'coordinates': [marker.longitude, marker.latitude],
        },
        'properties': {
          'type': 'marker',
          'title': marker.title,
          'name': marker.title,
          if (marker.note != null) 'note': marker.note,
          if (marker.note != null) 'description': marker.note,
          if (marker.category != null) 'category': marker.category,
        },
      });
    }

    // 2. Tracks -> LineString features
    final pointsBySession = <String, List<LocationPoint>>{};
    for (final point in points) {
      pointsBySession.putIfAbsent(point.sessionId, () => []).add(point);
    }

    for (final session in sessions) {
      final sessionPoints = pointsBySession[session.id] ??
          (sessions.length == 1 ? points : const <LocationPoint>[]);

      final coords = <List<num>>[];
      final coordTimes = <String>[];
      final speeds = <num>[];

      for (final pt in sessionPoints) {
        if (pt.altitudeM != null) {
          coords.add([pt.longitude, pt.latitude, pt.altitudeM!]);
        } else {
          coords.add([pt.longitude, pt.latitude]);
        }
        coordTimes.add(pt.recordedAt.toUtc().toIso8601String());
        if (pt.speedMps != null) {
          speeds.add(pt.speedMps!);
        }
      }

      features.add({
        'type': 'Feature',
        'id': session.id,
        'geometry': {
          'type': 'LineString',
          'coordinates': coords,
        },
        'properties': {
          'type': 'session_track',
          'title': session.title ?? '기록 ${session.startedAt.toLocal()}',
          'name': session.title ?? '기록 ${session.startedAt.toLocal()}',
          'startedAt': session.startedAt.toUtc().toIso8601String(),
          if (session.endedAt != null) 'endedAt': session.endedAt!.toUtc().toIso8601String(),
          'coordTimes': coordTimes,
          if (speeds.isNotEmpty) 'speeds': speeds,
        },
      });
    }

    // If points are present without session definition
    if (sessions.isEmpty && points.isNotEmpty) {
      final coords = points.map((p) => [p.longitude, p.latitude, if (p.altitudeM != null) p.altitudeM!]).toList();
      features.add({
        'type': 'Feature',
        'geometry': {
          'type': 'LineString',
          'coordinates': coords,
        },
        'properties': {
          'type': 'session_track',
          'title': '기록 경로',
          'name': '기록 경로',
          'coordTimes': points.map((p) => p.recordedAt.toUtc().toIso8601String()).toList(),
        },
      });
    }

    final collection = {
      'type': 'FeatureCollection',
      'features': features,
    };

    return const JsonEncoder.withIndent('  ').convert(collection);
  }

  /// Parses GeoJSON string into an [ImportExportBundle].
  static ImportExportBundle fromGeoJson(String geoJsonString) {
    final dynamic decoded = jsonDecode(geoJsonString);
    final parsedMarkers = <MapMarker>[];
    final parsedSessions = <TrackingSession>[];
    final parsedPoints = <LocationPoint>[];

    final baseTimestamp = DateTime.now().millisecondsSinceEpoch;

    List<Map<String, dynamic>> featuresList = [];

    if (decoded is Map<String, dynamic>) {
      if (decoded['type'] == 'FeatureCollection' && decoded['features'] is List) {
        featuresList = (decoded['features'] as List).whereType<Map<String, dynamic>>().toList();
      } else if (decoded['type'] == 'Feature') {
        featuresList = [decoded];
      } else if (decoded.containsKey('coordinates')) {
        // Direct geometry object wrapped as a feature
        featuresList = [
          {
            'type': 'Feature',
            'geometry': decoded,
            'properties': <String, dynamic>{},
          }
        ];
      }
    } else if (decoded is List) {
      featuresList = decoded.whereType<Map<String, dynamic>>().toList();
    }

    int sessionIndex = 0;
    int markerIndex = 0;

    for (final feature in featuresList) {
      final geometry = feature['geometry'];
      if (geometry is! Map<String, dynamic>) continue;

      final geomType = geometry['type'] as String?;
      final coordinates = geometry['coordinates'];
      final properties = (feature['properties'] as Map<String, dynamic>?) ?? {};

      final name = properties['title'] as String? ??
          properties['name'] as String? ??
          properties['label'] as String?;
      final note = properties['note'] as String? ??
          properties['description'] as String? ??
          properties['desc'] as String?;
      final category = properties['category'] as String?;

      if (geomType == 'Point' && coordinates is List && coordinates.length >= 2) {
        final lon = (coordinates[0] as num).toDouble();
        final lat = (coordinates[1] as num).toDouble();

        parsedMarkers.add(
          MapMarker(
            id: 'imp_m_${baseTimestamp}_${markerIndex++}',
            title: (name != null && name.isNotEmpty) ? name : '가져온 장소 $markerIndex',
            latitude: lat,
            longitude: lon,
            note: note,
            category: category ?? 'place',
          ),
        );
      } else if (geomType == 'LineString' && coordinates is List) {
        final lineCoords = coordinates.whereType<List>().toList();
        if (lineCoords.isEmpty) continue;

        final sessionId = 'imp_s_${baseTimestamp}_${sessionIndex++}';
        final sessionPoints = <LocationPoint>[];

        final coordTimes = (properties['coordTimes'] as List?)?.map((e) => e.toString()).toList() ??
            (properties['timestamps'] as List?)?.map((e) => e.toString()).toList();
        final speeds = (properties['speeds'] as List?)?.map((e) => (e as num).toDouble()).toList();

        for (int i = 0; i < lineCoords.length; i++) {
          final ptCoord = lineCoords[i];
          if (ptCoord.length < 2) continue;

          final lon = (ptCoord[0] as num).toDouble();
          final lat = (ptCoord[1] as num).toDouble();
          final ele = ptCoord.length >= 3 ? (ptCoord[2] as num).toDouble() : null;

          DateTime pointTime;
          if (coordTimes != null && i < coordTimes.length) {
            pointTime = DateTime.tryParse(coordTimes[i])?.toUtc() ??
                DateTime.fromMillisecondsSinceEpoch(baseTimestamp + i * 1000, isUtc: true);
          } else {
            pointTime = DateTime.fromMillisecondsSinceEpoch(baseTimestamp + i * 1000, isUtc: true);
          }

          final speed = speeds != null && i < speeds.length ? speeds[i] : null;

          sessionPoints.add(
            LocationPoint(
              id: 'imp_p_${baseTimestamp}_${sessionId}_$i',
              sessionId: sessionId,
              latitude: lat,
              longitude: lon,
              recordedAt: pointTime,
              updatedAt: DateTime.now().toUtc(),
              altitudeM: ele,
              speedMps: speed,
            ),
          );
        }

        if (sessionPoints.isNotEmpty) {
          parsedPoints.addAll(sessionPoints);
          parsedSessions.add(
            TrackingSession(
              id: sessionId,
              startedAt: sessionPoints.first.recordedAt,
              updatedAt: DateTime.now().toUtc(),
              endedAt: sessionPoints.last.recordedAt,
              status: TrackingSessionStatus.completed,
              title: (name != null && name.isNotEmpty) ? name : '가져온 경로 $sessionIndex',
            ),
          );
        }
      } else if (geomType == 'MultiLineString' && coordinates is List) {
        for (final segment in coordinates.whereType<List>()) {
          final lineCoords = segment.whereType<List>().toList();
          if (lineCoords.isEmpty) continue;

          final sessionId = 'imp_s_${baseTimestamp}_${sessionIndex++}';
          final sessionPoints = <LocationPoint>[];

          for (int i = 0; i < lineCoords.length; i++) {
            final ptCoord = lineCoords[i];
            if (ptCoord.length < 2) continue;

            final lon = (ptCoord[0] as num).toDouble();
            final lat = (ptCoord[1] as num).toDouble();
            final ele = ptCoord.length >= 3 ? (ptCoord[2] as num).toDouble() : null;

            sessionPoints.add(
              LocationPoint(
                id: 'imp_p_${baseTimestamp}_${sessionId}_$i',
                sessionId: sessionId,
                latitude: lat,
                longitude: lon,
                recordedAt: DateTime.fromMillisecondsSinceEpoch(baseTimestamp + i * 1000, isUtc: true),
                updatedAt: DateTime.now().toUtc(),
                altitudeM: ele,
              ),
            );
          }

          if (sessionPoints.isNotEmpty) {
            parsedPoints.addAll(sessionPoints);
            parsedSessions.add(
              TrackingSession(
                id: sessionId,
                startedAt: sessionPoints.first.recordedAt,
                updatedAt: DateTime.now().toUtc(),
                endedAt: sessionPoints.last.recordedAt,
                status: TrackingSessionStatus.completed,
                title: (name != null && name.isNotEmpty) ? name : '가져온 구간 $sessionIndex',
              ),
            );
          }
        }
      }
    }

    return ImportExportBundle(
      sessions: parsedSessions,
      points: parsedPoints,
      markers: parsedMarkers,
    );
  }
}
