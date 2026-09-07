import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sanc_tracker/tracking/data/location_service.dart';
import 'package:sanc_tracker/tracking/domain/tracking_repository.dart';
import 'package:sanc_tracker/tracking/domain/tracking_session.dart';
import 'package:sanc_tracker/tracking/domain/location_point.dart';
import 'package:sanc_tracker/tracking/presentation/tracking_controller.dart';

class FakeLocation implements LocationService {
  final stream = StreamController<Position>();
  LocationPermission permission = LocationPermission.whileInUse;
  int subscriptions = 0;
  @override
  Future<bool> isServiceEnabled() async => true;
  @override
  Future<LocationPermission> requestPermissionIfNeeded() async => permission;
  @override
  Future<Position?> getLastKnownPosition() async => null;
  @override
  Future<Position> getCurrentPosition() => throw UnimplementedError();
  @override
  Stream<Position> positionStream() {
    subscriptions++;
    return stream.stream;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeRepository implements TrackingRepository {
  final session = TrackingSession(
    id: 'existing',
    startedAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
  final points = <LocationPoint>[];
  bool failSave = false;
  int created = 0;
  @override
  Future<TrackingSession?> loadActiveSession() async => session;
  @override
  Future<List<LocationPoint>> loadPoints(String id) async => points;
  @override
  Future<void> savePoint(LocationPoint point) async {
    if (failSave) throw StateError('disk full');
    points.add(point);
  }

  @override
  Future<void> saveSession(TrackingSession session) async {
    created++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeLocation location;
  late FakeRepository repository;
  late ProviderContainer container;
  setUp(() {
    location = FakeLocation();
    repository = FakeRepository();
    container = ProviderContainer(
      overrides: [
        locationServiceProvider.overrideWithValue(location),
        trackingRepositoryProvider.overrideWithValue(repository),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await location.stream.close();
  });

  Position point() => Position(
    longitude: 127,
    latitude: 37,
    timestamp: DateTime.utc(2026),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 1,
    speedAccuracy: 0,
  );

  test(
    'restoration resubscribes and persists into the existing session',
    () async {
      final controller = container.read(trackingControllerProvider.notifier);
      await controller.restoreActiveSession();
      await controller.restoreActiveSession();
      expect(location.subscriptions, 1);
      location.stream.add(point());
      await Future<void>.delayed(Duration.zero);
      expect(repository.points.single.sessionId, 'existing');
      expect(repository.created, 0);
      expect(container.read(trackingControllerProvider).route, hasLength(1));
      expect(
        container.read(trackingControllerProvider).currentPosition?.latitude,
        37,
      );
      expect(container.read(trackingControllerProvider).isTracking, isTrue);
    },
  );

  test(
    'denied recovery never claims to be tracking and retry reuses session',
    () async {
      location.permission = LocationPermission.deniedForever;
      final controller = container.read(trackingControllerProvider.notifier);
      await controller.restoreActiveSession();
      expect(container.read(trackingControllerProvider).isTracking, isFalse);
      expect(location.subscriptions, 0);
      location.permission = LocationPermission.whileInUse;
      await controller.toggleTracking();
      expect(location.subscriptions, 1);
      expect(repository.created, 0);
    },
  );

  test(
    'storage failure stops tracking and does not display unsaved point',
    () async {
      repository.failSave = true;
      await container
          .read(trackingControllerProvider.notifier)
          .restoreActiveSession();
      location.stream.add(point());
      await Future<void>.delayed(Duration.zero);
      final state = container.read(trackingControllerProvider);
      expect(state.isTracking, isFalse);
      expect(state.route, isEmpty);
      expect(state.message, contains('disk full'));
    },
  );
}
