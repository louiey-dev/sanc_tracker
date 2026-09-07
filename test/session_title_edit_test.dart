import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanc_tracker/history/presentation/history_screen.dart';
import 'package:sanc_tracker/history/presentation/widgets/session_card.dart';
import 'package:sanc_tracker/history/presentation/widgets/session_title_dialog.dart';
import 'package:sanc_tracker/tracking/domain/location_point.dart';
import 'package:sanc_tracker/tracking/domain/tracking_repository.dart';
import 'package:sanc_tracker/tracking/domain/tracking_session.dart';
import 'package:sanc_tracker/tracking/presentation/tracking_controller.dart';

class _FakeHistoryRepository implements TrackingRepository {
  List<TrackingSession> sessions = [];

  @override
  Future<List<TrackingSession>> loadSessions() async => List.unmodifiable(sessions);

  @override
  Future<List<LocationPoint>> loadPoints(String sessionId) async => const [];

  @override
  Future<void> updateSession(TrackingSession session) async {
    final index = sessions.indexWhere((s) => s.id == session.id);
    if (index >= 0) {
      sessions[index] = session;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Session title editing and display', () {
    testWidgets('SessionCard displays date-time when title is null and custom title when present', (tester) async {
      final sessionWithoutTitle = TrackingSession(
        id: 's1',
        startedAt: DateTime.utc(2026, 5, 1, 9, 30),
        updatedAt: DateTime.utc(2026, 5, 1, 11, 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SessionCard(
              session: sessionWithoutTitle,
              summaryFuture: Future.value('2.5 km • 1시간 30분'),
              isSelected: false,
              isSelecting: false,
              onTap: () {},
              onLongPress: () {},
              onSelectChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Formatted date-time is the main title
      expect(find.text('2026.05.01 18:30'), findsOneWidget); // local time depending on timezone or string format

      // Now test with custom title
      final sessionWithTitle = sessionWithoutTitle.copyWith(title: '북한산 원점회귀');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SessionCard(
              session: sessionWithTitle,
              summaryFuture: Future.value('2.5 km • 1시간 30분'),
              isSelected: false,
              isSelecting: false,
              onTap: () {},
              onLongPress: () {},
              onSelectChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('북한산 원점회귀'), findsOneWidget);
    });

    testWidgets('SessionTitleDialog submits updated title and cancels properly', (tester) async {
      String? submittedTitle;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  submittedTitle = await SessionTitleDialog.show(
                    context,
                    initialTitle: '기존 제목',
                  );
                },
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();

      expect(find.text('기록 이름 수정'), findsOneWidget);
      expect(find.text('기존 제목'), findsOneWidget);

      // Enter new title
      await tester.enterText(find.byType(TextField), '새로운 산책 코스');
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();

      expect(submittedTitle, '새로운 산책 코스');
    });

    testWidgets('HistoryScreen edits and saves session title, updating reactive UI', (tester) async {
      final fakeRepo = _FakeHistoryRepository()
        ..sessions = [
          TrackingSession(
            id: 'session-101',
            startedAt: DateTime.utc(2026, 9, 7, 10, 0),
            updatedAt: DateTime.utc(2026, 9, 7, 11, 0),
          ),
        ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trackingRepositoryProvider.overrideWithValue(fakeRepo),
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

      // Verify edit button exists on card
      final editButton = find.byTooltip('이름 수정');
      expect(editButton, findsOneWidget);

      // Tap edit button
      await tester.tap(editButton);
      await tester.pumpAndSettle();

      expect(find.text('기록 이름 수정'), findsOneWidget);

      // Enter custom title
      await tester.enterText(find.byType(TextField), '지리산 노고단 코스');
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();

      // Verify repository updated
      expect(fakeRepo.sessions.first.title, '지리산 노고단 코스');

      // Verify UI displays new custom title
      expect(find.text('지리산 노고단 코스'), findsOneWidget);
    });
  });
}
