import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanc_tracker/history/presentation/history_screen.dart';
import 'package:sanc_tracker/history/presentation/widgets/session_card.dart';
import 'package:sanc_tracker/tracking/domain/location_point.dart';
import 'package:sanc_tracker/tracking/domain/tracking_repository.dart';
import 'package:sanc_tracker/tracking/domain/tracking_session.dart';
import 'package:sanc_tracker/tracking/presentation/tracking_controller.dart';
import 'package:sanc_tracker/map/map_marker.dart';
import 'package:sanc_tracker/media/media_item.dart';

class MockTrackingRepository implements TrackingRepository {
  final List<TrackingSession> sessions = [];

  @override
  Future<void> saveSession(TrackingSession session) async => sessions.add(session);

  @override
  Future<void> updateSession(TrackingSession session) async {}

  @override
  Future<void> savePoint(LocationPoint point) async {}

  @override
  Future<void> deleteSession(String sessionId) async {}

  @override
  Future<List<TrackingSession>> loadSessions() async => List.of(sessions);

  @override
  Future<TrackingSession?> loadActiveSession() async => null;

  @override
  Future<List<LocationPoint>> loadPoints(String sessionId) async => [];

  @override
  Future<void> saveMarker(MapMarker marker) async {}

  @override
  Future<void> updateMarker(MapMarker marker) async {}

  @override
  Future<void> deleteMarker(String markerId) async {}

  @override
  Future<List<MapMarker>> loadMarkers() async => [];

  @override
  Future<void> saveMedia(MediaItem item) async {}

  @override
  Future<List<MediaItem>> loadMedia(String markerId) async => [];

  @override
  Future<void> deleteMedia(String mediaId) async {}
}

void main() {
  group('Export/Import UI', () {
    testWidgets('SessionCard renders export/share button and responds to tap', (tester) async {
      final session = TrackingSession(
        id: 'session-test',
        startedAt: DateTime.utc(2026, 9, 14, 10, 0),
        updatedAt: DateTime.utc(2026, 9, 14, 10, 30),
        status: TrackingSessionStatus.completed,
        title: '테스트 산책로',
      );

      bool exportTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SessionCard(
              session: session,
              isSelected: false,
              isSelecting: false,
              onTap: () {},
              onLongPress: () {},
              onSelectChanged: (_) {},
              onExport: () => exportTapped = true,
            ),
          ),
        ),
      );

      // Verify share button is rendered
      expect(find.byIcon(Icons.share_outlined), findsOneWidget);

      // Tap share button
      await tester.tap(find.byIcon(Icons.share_outlined));
      await tester.pump();

      expect(exportTapped, isTrue);
    });

    testWidgets('HistoryScreen AppBar renders import button with tooltip', (tester) async {
      final mockRepo = MockTrackingRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trackingRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: MaterialApp(
            home: HistoryScreen(
              onSelectSession: (_) {},
              isViewingSavedRoute: false,
              onExitSavedRoute: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify import button is in AppBar
      expect(find.byIcon(Icons.file_download_outlined), findsOneWidget);
      expect(find.byTooltip('기록 가져오기 (GPX / GeoJSON)'), findsOneWidget);
    });
  });
}
