import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanc_tracker/map/map_marker.dart';
import 'package:sanc_tracker/map/presentation/markers_screen.dart';
import 'package:sanc_tracker/tracking/domain/tracking_repository.dart';
import 'package:sanc_tracker/tracking/presentation/tracking_controller.dart';

class _FakeMarkerRepository implements TrackingRepository {
  List<MapMarker> markers = [];

  @override
  Future<List<MapMarker>> loadMarkers() async => List.unmodifiable(markers);

  @override
  Future<void> deleteMarker(String id) async {
    markers.removeWhere((m) => m.id == id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Marker deletion and sync', () {
    testWidgets('deleting marker refreshes markersListProvider and shows empty state', (tester) async {
      final fakeRepo = _FakeMarkerRepository()
        ..markers = [
          const MapMarker(
            id: 'm1',
            title: '테스트 마커 1',
            latitude: 37.5,
            longitude: 127.0,
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

      // Verify initial marker appears
      expect(find.text('테스트 마커 1'), findsOneWidget);
      expect(find.text('저장된 마커가 없습니다.'), findsNothing);

      // Tap delete icon
      await tester.tap(find.byTooltip('마커 삭제'));
      await tester.pumpAndSettle();

      // Confirm deletion dialog
      expect(find.text('마커 삭제'), findsOneWidget);
      await tester.tap(find.text('삭제'));
      await tester.pumpAndSettle();

      // Verify empty state is now displayed immediately
      expect(find.text('저장된 마커가 없습니다.'), findsOneWidget);
      expect(fakeRepo.markers, isEmpty);
    });
  });
}
