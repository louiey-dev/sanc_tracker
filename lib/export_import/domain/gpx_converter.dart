import 'package:xml/xml.dart';
import '../../map/map_marker.dart';
import '../../tracking/domain/location_point.dart';
import '../../tracking/domain/tracking_session.dart';
import 'import_export_bundle.dart';

class GpxConverter {
  const GpxConverter._();

  /// Converts tracking sessions, points, and markers to GPX v1.1 XML string.
  static String toGpx({
    List<TrackingSession> sessions = const [],
    List<LocationPoint> points = const [],
    List<MapMarker> markers = const [],
    String? creatorName,
  }) {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element(
      'gpx',
      attributes: {
        'version': '1.1',
        'creator': creatorName ?? 'SANC Tracker',
        'xmlns': 'http://www.topografix.com/GPX/1/1',
        'xmlns:xsi': 'http://www.w3.org/2001/XMLSchema-instance',
        'xsi:schemaLocation':
            'http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd',
      },
      nest: () {
        // Metadata
        builder.element(
          'metadata',
          nest: () {
            builder.element('name', nest: 'SANC Tracker Export');
            builder.element('time', nest: DateTime.now().toUtc().toIso8601String());
          },
        );

        // Waypoints (MapMarkers)
        for (final marker in markers) {
          builder.element(
            'wpt',
            attributes: {
              'lat': marker.latitude.toStringAsFixed(7),
              'lon': marker.longitude.toStringAsFixed(7),
            },
            nest: () {
              builder.element('name', nest: marker.title);
              if (marker.note != null && marker.note!.isNotEmpty) {
                builder.element('desc', nest: marker.note!);
              }
              if (marker.category != null && marker.category!.isNotEmpty) {
                builder.element('type', nest: marker.category!);
              }
            },
          );
        }

        // Tracks (TrackingSessions)
        // Group points by sessionId
        final pointsBySession = <String, List<LocationPoint>>{};
        for (final point in points) {
          pointsBySession.putIfAbsent(point.sessionId, () => []).add(point);
        }

        for (final session in sessions) {
          final sessionPoints = pointsBySession[session.id] ??
              (sessions.length == 1 ? points : const <LocationPoint>[]);

          builder.element(
            'trk',
            nest: () {
              builder.element('name', nest: session.title ?? '기록 ${session.startedAt.toLocal()}');
              builder.element(
                'trkseg',
                nest: () {
                  for (final pt in sessionPoints) {
                    builder.element(
                      'trkpt',
                      attributes: {
                        'lat': pt.latitude.toStringAsFixed(7),
                        'lon': pt.longitude.toStringAsFixed(7),
                      },
                      nest: () {
                        if (pt.altitudeM != null) {
                          builder.element('ele', nest: pt.altitudeM!.toStringAsFixed(1));
                        }
                        builder.element('time', nest: pt.recordedAt.toUtc().toIso8601String());
                        if (pt.speedMps != null) {
                          builder.element('speed', nest: pt.speedMps!.toStringAsFixed(2));
                        }
                      },
                    );
                  }
                },
              );
            },
          );
        }

        // If no sessions provided but points are given
        if (sessions.isEmpty && points.isNotEmpty) {
          builder.element(
            'trk',
            nest: () {
              builder.element('name', nest: '기록 경로');
              builder.element(
                'trkseg',
                nest: () {
                  for (final pt in points) {
                    builder.element(
                      'trkpt',
                      attributes: {
                        'lat': pt.latitude.toStringAsFixed(7),
                        'lon': pt.longitude.toStringAsFixed(7),
                      },
                      nest: () {
                        if (pt.altitudeM != null) {
                          builder.element('ele', nest: pt.altitudeM!.toStringAsFixed(1));
                        }
                        builder.element('time', nest: pt.recordedAt.toUtc().toIso8601String());
                      },
                    );
                  }
                },
              );
            },
          );
        }
      },
    );

    return builder.buildDocument().toXmlString(pretty: true, indent: '  ');
  }

  /// Parses GPX v1.1 (or compatible) XML string into an [ImportExportBundle].
  static ImportExportBundle fromGpx(String gpxString) {
    final document = XmlDocument.parse(gpxString);
    final parsedMarkers = <MapMarker>[];
    final parsedSessions = <TrackingSession>[];
    final parsedPoints = <LocationPoint>[];

    final baseTimestamp = DateTime.now().millisecondsSinceEpoch;

    // 1. Parse Waypoints (<wpt>)
    final wpts = document.findAllElements('wpt');
    int markerIndex = 0;
    for (final wpt in wpts) {
      final latAttr = wpt.getAttribute('lat');
      final lonAttr = wpt.getAttribute('lon');
      if (latAttr == null || lonAttr == null) continue;

      final lat = double.tryParse(latAttr);
      final lon = double.tryParse(lonAttr);
      if (lat == null || lon == null) continue;

      final name = wpt.findElements('name').firstOrNull?.innerText.trim();
      final desc = wpt.findElements('desc').firstOrNull?.innerText.trim();
      final type = wpt.findElements('type').firstOrNull?.innerText.trim();

      parsedMarkers.add(
        MapMarker(
          id: 'imp_m_${baseTimestamp}_${markerIndex++}',
          title: (name != null && name.isNotEmpty) ? name : '가져온 장소 $markerIndex',
          latitude: lat,
          longitude: lon,
          note: desc,
          category: type ?? 'place',
        ),
      );
    }

    // 2. Parse Tracks (<trk>)
    final trks = document.findAllElements('trk');
    int sessionIndex = 0;
    for (final trk in trks) {
      final trkName = trk.findElements('name').firstOrNull?.innerText.trim();
      final trkPoints = <LocationPoint>[];
      final sessionId = 'imp_s_${baseTimestamp}_${sessionIndex++}';

      final trksegs = trk.findAllElements('trkseg');
      int pointIndex = 0;

      for (final trkseg in trksegs) {
        final trkpts = trkseg.findAllElements('trkpt');
        for (final pt in trkpts) {
          final latAttr = pt.getAttribute('lat');
          final lonAttr = pt.getAttribute('lon');
          if (latAttr == null || lonAttr == null) continue;

          final lat = double.tryParse(latAttr);
          final lon = double.tryParse(lonAttr);
          if (lat == null || lon == null) continue;

          final eleStr = pt.findElements('ele').firstOrNull?.innerText.trim();
          final timeStr = pt.findElements('time').firstOrNull?.innerText.trim();
          final speedStr = pt.findElements('speed').firstOrNull?.innerText.trim();

          final ele = eleStr != null ? double.tryParse(eleStr) : null;
          final time = timeStr != null
              ? DateTime.tryParse(timeStr)?.toUtc() ??
                  DateTime.fromMillisecondsSinceEpoch(baseTimestamp + pointIndex * 1000, isUtc: true)
              : DateTime.fromMillisecondsSinceEpoch(baseTimestamp + pointIndex * 1000, isUtc: true);
          final speed = speedStr != null ? double.tryParse(speedStr) : null;

          trkPoints.add(
            LocationPoint(
              id: 'imp_p_${baseTimestamp}_${sessionId}_${pointIndex++}',
              sessionId: sessionId,
              latitude: lat,
              longitude: lon,
              recordedAt: time,
              updatedAt: DateTime.now().toUtc(),
              altitudeM: ele,
              speedMps: speed,
            ),
          );
        }
      }

      if (trkPoints.isNotEmpty) {
        parsedPoints.addAll(trkPoints);
        final startedAt = trkPoints.first.recordedAt;
        final endedAt = trkPoints.last.recordedAt;
        parsedSessions.add(
          TrackingSession(
            id: sessionId,
            startedAt: startedAt,
            updatedAt: DateTime.now().toUtc(),
            endedAt: endedAt,
            status: TrackingSessionStatus.completed,
            title: (trkName != null && trkName.isNotEmpty) ? trkName : '가져온 경로 $sessionIndex',
          ),
        );
      }
    }

    // 3. Fallback: Parse Routes (<rte>) if no tracks were found
    if (parsedSessions.isEmpty) {
      final rtes = document.findAllElements('rte');
      for (final rte in rtes) {
        final rteName = rte.findElements('name').firstOrNull?.innerText.trim();
        final rtePoints = <LocationPoint>[];
        final sessionId = 'imp_s_${baseTimestamp}_${sessionIndex++}';
        final rtepts = rte.findAllElements('rtept');
        int pointIndex = 0;

        for (final pt in rtepts) {
          final latAttr = pt.getAttribute('lat');
          final lonAttr = pt.getAttribute('lon');
          if (latAttr == null || lonAttr == null) continue;

          final lat = double.tryParse(latAttr);
          final lon = double.tryParse(lonAttr);
          if (lat == null || lon == null) continue;

          final eleStr = pt.findElements('ele').firstOrNull?.innerText.trim();
          final timeStr = pt.findElements('time').firstOrNull?.innerText.trim();
          final ele = eleStr != null ? double.tryParse(eleStr) : null;
          final time = timeStr != null
              ? DateTime.tryParse(timeStr)?.toUtc() ??
                  DateTime.fromMillisecondsSinceEpoch(baseTimestamp + pointIndex * 1000, isUtc: true)
              : DateTime.fromMillisecondsSinceEpoch(baseTimestamp + pointIndex * 1000, isUtc: true);

          rtePoints.add(
            LocationPoint(
              id: 'imp_p_${baseTimestamp}_${sessionId}_${pointIndex++}',
              sessionId: sessionId,
              latitude: lat,
              longitude: lon,
              recordedAt: time,
              updatedAt: DateTime.now().toUtc(),
              altitudeM: ele,
            ),
          );
        }

        if (rtePoints.isNotEmpty) {
          parsedPoints.addAll(rtePoints);
          parsedSessions.add(
            TrackingSession(
              id: sessionId,
              startedAt: rtePoints.first.recordedAt,
              updatedAt: DateTime.now().toUtc(),
              endedAt: rtePoints.last.recordedAt,
              status: TrackingSessionStatus.completed,
              title: (rteName != null && rteName.isNotEmpty) ? rteName : '가져온 루트 $sessionIndex',
            ),
          );
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
