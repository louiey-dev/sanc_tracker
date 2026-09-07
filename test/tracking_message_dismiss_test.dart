import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanc_tracker/main.dart';
import 'package:sanc_tracker/map/map_marker.dart';
import 'package:sanc_tracker/tracking/domain/location_point.dart';
import 'package:sanc_tracker/tracking/domain/tracking_repository.dart';
import 'package:sanc_tracker/tracking/domain/tracking_session.dart';
import 'package:sanc_tracker/tracking/presentation/tracking_controller.dart';

class TestTrackingRepository implements TrackingRepository {
  @override
  Future<List<TrackingSession>> loadSessions() async => const [];
  @override
  Future<List<MapMarker>> loadMarkers() async => const [];
  @override
  Future<TrackingSession?> loadActiveSession() async => null;
  @override
  Future<List<LocationPoint>> loadPoints(String id) async => const [];
  @override
  Future<void> updateSession(TrackingSession session) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('Tracking message appears and can be dismissed via X button',
      (WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        trackingRepositoryProvider.overrideWithValue(TestTrackingRepository()),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SancTrackerApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Initially no message banner
    expect(find.byIcon(Icons.close_rounded), findsNothing);

    // Trigger message by calling clearLoadedSessionRoute
    container
        .read(trackingControllerProvider.notifier)
        .clearLoadedSessionRoute();
    await tester.pump();

    // Verify message and close button are visible
    expect(find.text('저장 경로 보기를 종료했습니다.'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    // Tap X button
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();

    // Verify message and close button are dismissed
    expect(find.text('저장 경로 보기를 종료했습니다.'), findsNothing);
    expect(find.byIcon(Icons.close_rounded), findsNothing);
  });
}
