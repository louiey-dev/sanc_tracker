import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sanc_tracker/tracking/data/location_service.dart';
import 'package:sanc_tracker/tracking/domain/location_point.dart';
import 'package:sanc_tracker/tracking/domain/tracking_repository.dart';
import 'package:sanc_tracker/tracking/domain/tracking_session.dart';
import 'package:sanc_tracker/tracking/domain/tracking_state.dart';
import 'package:sanc_tracker/tracking/presentation/tracking_controller.dart';

class _FakeLocationService implements LocationService {
  final stream = StreamController<Position>.broadcast();

  @override
  Future<bool> isServiceEnabled() async => true;

  @override
  Future<LocationPermission> requestPermissionIfNeeded() async =>
      LocationPermission.always;

  @override
  Future<Position?> getLastKnownPosition() async => null;

  @override
  Future<Position> getCurrentPosition() async => Position(
        latitude: 37.5,
        longitude: 127.0,
        timestamp: DateTime.utc(2026),
        accuracy: 5.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );

  @override
  Stream<Position> positionStream() => stream.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTrackingRepository implements TrackingRepository {
  final Map<String, List<LocationPoint>> storedPoints = {};

  @override
  Future<TrackingSession?> loadActiveSession() async => null;

  @override
  Future<List<LocationPoint>> loadPoints(String sessionId) async {
    return storedPoints[sessionId] ?? const [];
  }

  @override
  Future<void> saveSession(TrackingSession session) async {}

  @override
  Future<void> savePoint(LocationPoint point) async {}

  @override
  Future<List<TrackingSession>> loadSessions() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Saved route state isolation', () {
    test('TrackingState keeps route and savedRoute isolated', () {
      const state = TrackingState();
      expect(state.route, isEmpty);
      expect(state.savedRoute, isEmpty);
      expect(state.viewedSession, isNull);

      final livePoint = Position(
        latitude: 37.5,
        longitude: 127.0,
        timestamp: DateTime.utc(2026),
        accuracy: 1.0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
      final savedPoint = Position(
        latitude: 38.0,
        longitude: 128.0,
        timestamp: DateTime.utc(2026),
        accuracy: 1.0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );

      final updated = state.copyWith(
        route: [livePoint],
        savedRoute: [savedPoint],
        viewedSession: TrackingSession(
          id: 'test-session',
          startedAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      );

      expect(updated.route.length, 1);
      expect(updated.route.first.latitude, 37.5);
      expect(updated.savedRoute.length, 1);
      expect(updated.savedRoute.first.latitude, 38.0);
      expect(updated.viewedSession?.id, 'test-session');

      // Clearing savedRoute must not clear live route
      final clearedSaved = updated.copyWith(
        clearSavedRoute: true,
        clearViewedSession: true,
      );
      expect(clearedSaved.route.length, 1);
      expect(clearedSaved.route.first.latitude, 37.5);
      expect(clearedSaved.savedRoute, isEmpty);
      expect(clearedSaved.viewedSession, isNull);
    });

    test('TrackingController does not overwrite active live route when viewing/exiting saved session', () async {
      final fakeLocation = _FakeLocationService();
      final fakeRepo = _FakeTrackingRepository();
      fakeRepo.storedPoints['historical-session'] = [
        LocationPoint(
          id: 'p1',
          sessionId: 'historical-session',
          latitude: 35.1,
          longitude: 129.0,
          recordedAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
          accuracyM: 5.0,
        ),
        LocationPoint(
          id: 'p2',
          sessionId: 'historical-session',
          latitude: 35.2,
          longitude: 129.1,
          recordedAt: DateTime.utc(2026, 1, 1, 0, 5),
          updatedAt: DateTime.utc(2026, 1, 1, 0, 5),
          accuracyM: 5.0,
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          locationServiceProvider.overrideWithValue(fakeLocation),
          trackingRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await fakeLocation.stream.close();
      });

      final notifier = container.read(trackingControllerProvider.notifier);

      // Start tracking
      await notifier.toggleTracking();
      expect(container.read(trackingControllerProvider).isTracking, isTrue);

      // Simulate incoming live location
      final livePoint = Position(
        latitude: 37.5665,
        longitude: 126.9780,
        timestamp: DateTime.utc(2026, 3, 1),
        accuracy: 3.0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 1.2,
        speedAccuracy: 0,
      );
      fakeLocation.stream.add(livePoint);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(trackingControllerProvider).route.length, 1);

      // Now view historical saved session
      final session = TrackingSession(
        id: 'historical-session',
        startedAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1, 0, 5),
      );
      await notifier.loadSessionRoute(session);

      final stateWithSaved = container.read(trackingControllerProvider);
      // Live route MUST remain intact!
      expect(stateWithSaved.route.length, 1);
      expect(stateWithSaved.route.first.latitude, 37.5665);

      // Saved route MUST be populated
      expect(stateWithSaved.savedRoute.length, 2);
      expect(stateWithSaved.savedRoute.first.latitude, 35.1);
      expect(stateWithSaved.viewedSession?.id, 'historical-session');

      // Now clear loaded session route (user exits saved route)
      notifier.clearLoadedSessionRoute();

      final stateAfterExit = container.read(trackingControllerProvider);
      // Live route MUST still be preserved!
      expect(stateAfterExit.route.length, 1);
      expect(stateAfterExit.route.first.latitude, 37.5665);

      // Saved route MUST be cleared
      expect(stateAfterExit.savedRoute, isEmpty);
      expect(stateAfterExit.viewedSession, isNull);
    });
  });
}
