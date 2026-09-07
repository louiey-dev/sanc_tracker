import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sanc_tracker/main.dart';
import 'package:sanc_tracker/history/presentation/history_screen.dart';
import 'package:sanc_tracker/map/presentation/markers_screen.dart';
import 'package:sanc_tracker/settings/presentation/settings_screen.dart';

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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('shows the initial tracking screen and navigates tabs', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trackingRepositoryProvider.overrideWithValue(TestTrackingRepository()),
        ],
        child: const SancTrackerApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Verify Tab 0 (추적): NavigationBar and HUD
    expect(find.text('추적'), findsOneWidget);
    expect(find.text('기록'), findsOneWidget);
    expect(find.text('마커'), findsOneWidget);
    expect(find.text('설정'), findsOneWidget);

    expect(find.text('추적 대기'), findsOneWidget);
    expect(find.text('시작'), findsOneWidget);

    // Switch to Tab 1 (기록)
    await tester.tap(find.text('기록'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(HistoryScreen), findsOneWidget);
    expect(find.text('저장된 이동 기록이 없습니다.'), findsOneWidget);

    // Switch to Tab 2 (마커)
    await tester.tap(find.text('마커'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(MarkersScreen), findsOneWidget);
    expect(find.text('저장된 마커가 없습니다.'), findsOneWidget);

    // Switch to Tab 3 (설정)
    await tester.tap(find.text('설정'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('배터리 절약 모드'), findsOneWidget);
    expect(find.text('Android GPS 요청 주기'), findsOneWidget);
  });
}
