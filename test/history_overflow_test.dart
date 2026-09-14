import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanc_tracker/history/presentation/history_screen.dart';
import 'package:sanc_tracker/tracking/domain/location_point.dart';
import 'package:sanc_tracker/tracking/domain/tracking_repository.dart';
import 'package:sanc_tracker/tracking/domain/tracking_session.dart';
import 'package:sanc_tracker/tracking/presentation/tracking_controller.dart';
import 'package:sanc_tracker/map/map_marker.dart';
import 'package:sanc_tracker/media/media_item.dart';

class FakeTrackingRepository implements TrackingRepository {
  final List<TrackingSession> sessions = [
    TrackingSession(
      id: 'session-12345678-abcd-ef01',
      startedAt: DateTime.utc(2026, 9, 14, 10, 0),
      updatedAt: DateTime.utc(2026, 9, 14, 11, 45),
      endedAt: DateTime.utc(2026, 9, 14, 11, 45),
      status: TrackingSessionStatus.completed,
      title: '아주 긴 이름을 가진 북한산 백운대 원점회귀 코스 주말 등산 기록',
    ),
  ];

  @override
  Future<List<TrackingSession>> loadSessions() async => sessions;

  @override
  Future<List<LocationPoint>> loadPoints(String sessionId) async => [
    LocationPoint(
      id: 'p1',
      sessionId: sessionId,
      latitude: 37.6,
      longitude: 127.0,
      recordedAt: DateTime.utc(2026, 9, 14, 10, 0),
      updatedAt: DateTime.utc(2026, 9, 14, 10, 0),
    ),
    LocationPoint(
      id: 'p2',
      sessionId: sessionId,
      latitude: 37.61,
      longitude: 127.01,
      recordedAt: DateTime.utc(2026, 9, 14, 11, 45),
      updatedAt: DateTime.utc(2026, 9, 14, 11, 45),
    ),
  ];

  @override
  Future<void> saveSession(TrackingSession session) async {}
  @override
  Future<void> updateSession(TrackingSession session) async {}
  @override
  Future<void> savePoint(LocationPoint point) async {}
  @override
  Future<void> deleteSession(String sessionId) async {}
  @override
  Future<TrackingSession?> loadActiveSession() async => null;
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
  for (final size in [
    const Size(320, 568), // Ultra narrow (iPhone SE 1st gen)
    const Size(360, 640), // Standard Android
    const Size(390, 844), // Modern iPhone
  ]) {
    testWidgets('No overflow on ${size.width}x${size.height} screen size', (tester) async {
      tester.view.physicalSize = Size(size.width * 2, size.height * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = FakeTrackingRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trackingRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            home: HistoryScreen(
              onSelectSession: (_) {},
              isViewingSavedRoute: true,
              onExitSavedRoute: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(HistoryScreen), findsOneWidget);
    });
  }
}
