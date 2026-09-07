import 'package:flutter_test/flutter_test.dart';
import 'package:sanc_tracker/tracking/domain/location_point.dart';
import 'package:sanc_tracker/tracking/domain/tracking_session.dart';
import 'package:sanc_tracker/tracking/domain/location_filter.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  test('location point round trips without losing ids or timestamps', () {
    final point = LocationPoint(
      id: 'point-1',
      sessionId: 'session-1',
      latitude: 37.5,
      longitude: 127.0,
      recordedAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 2),
      accuracyM: 4.2,
    );
    final restored = LocationPoint.fromJson(point.toJson());
    expect(restored.id, point.id);
    expect(restored.sessionId, point.sessionId);
    expect(restored.updatedAt, point.updatedAt);
  });

  test('tracking session round trips status, timestamps, and title', () {
    final session = TrackingSession(
      id: 'session-1',
      startedAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 2),
      status: TrackingSessionStatus.completed,
      title: '지리산 등산',
    );
    final restored = TrackingSession.fromJson(session.toJson());
    expect(restored.id, session.id);
    expect(restored.status, TrackingSessionStatus.completed);
    expect(restored.updatedAt, session.updatedAt);
    expect(restored.title, '지리산 등산');

    final updated = session.copyWith(title: '설악산 코스');
    expect(updated.title, '설악산 코스');

    final cleared = updated.copyWith(clearTitle: true);
    expect(cleared.title, isNull);
  });

  test('location filter accepts first point and rejects points within 50m', () {
    final filter = LocationFilter();
    final first = Position(
      latitude: 37.5,
      longitude: 127,
      timestamp: DateTime.utc(2026),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 1,
      heading: 0,
      headingAccuracy: 1,
      speed: 0,
      speedAccuracy: 1,
    );
    final near = Position(
      latitude: 37.5001,
      longitude: 127,
      timestamp: DateTime.utc(2026),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 1,
      heading: 0,
      headingAccuracy: 1,
      speed: 0,
      speedAccuracy: 1,
    );
    expect(filter.shouldRecord(null, first), isTrue);
    expect(filter.shouldRecord(first, near), isFalse);

    final nearAfter30s = Position(
      latitude: 37.5001,
      longitude: 127,
      timestamp: DateTime.utc(2026).add(const Duration(seconds: 30)),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 1,
      heading: 0,
      headingAccuracy: 1,
      speed: 0,
      speedAccuracy: 1,
    );
    expect(filter.shouldRecord(first, nearAfter30s), isTrue);
  });
}
