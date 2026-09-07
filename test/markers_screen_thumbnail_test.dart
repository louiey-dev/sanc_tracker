import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanc_tracker/map/map_marker.dart';
import 'package:sanc_tracker/map/presentation/markers_screen.dart';
import 'package:sanc_tracker/media/media_item.dart';
import 'package:sanc_tracker/tracking/domain/tracking_repository.dart';
import 'package:sanc_tracker/tracking/domain/tracking_session.dart';
import 'package:sanc_tracker/tracking/domain/location_point.dart';
import 'package:sanc_tracker/tracking/presentation/tracking_controller.dart';

class _FakeMarkerRepo implements TrackingRepository {
  List<MapMarker> markers = [];
  Map<String, List<MediaItem>> mediaByMarker = {};

  @override
  Future<List<MapMarker>> loadMarkers() async => markers;

  @override
  Future<List<MediaItem>> loadMedia(String markerId) async =>
      mediaByMarker[markerId] ?? const [];

  @override
  Future<List<TrackingSession>> loadSessions() async => const [];

  @override
  Future<TrackingSession?> loadActiveSession() async => null;

  @override
  Future<List<LocationPoint>> loadPoints(String id) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('MarkersScreen media thumbnail and category icon rendering', () {
    testWidgets('renders place pin for standard marker and photo icon for photo category', (tester) async {
      final fakeRepo = _FakeMarkerRepo()
        ..markers = [
          const MapMarker(
            id: 'm1',
            title: '대청봉 정상석',
            latitude: 38.123,
            longitude: 128.456,
            category: '정상',
          ),
          const MapMarker(
            id: 'm2',
            title: '흔들바위 사진',
            latitude: 38.124,
            longitude: 128.457,
            category: '사진',
          ),
        ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trackingRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp(
            home: MarkersScreen(
              onFocusMarker: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Titles
      expect(find.text('대청봉 정상석'), findsOneWidget);
      expect(find.text('흔들바위 사진'), findsOneWidget);

      // Category chips
      expect(find.text('정상'), findsWidgets);
      expect(find.text('사진'), findsWidgets);

      // Icons: standard place pin for normal marker, photo camera for photo marker
      expect(find.byIcon(Icons.place_rounded), findsOneWidget);
      expect(find.byIcon(Icons.photo_camera_rounded), findsOneWidget);
    });
  });
}
