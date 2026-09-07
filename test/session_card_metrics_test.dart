import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanc_tracker/history/presentation/widgets/session_card.dart';
import 'package:sanc_tracker/tracking/domain/tracking_session.dart';

void main() {
  group('SessionCard visual metrics chips and status badge', () {
    testWidgets('renders structured metrics (distance, duration, points) and completed badge', (tester) async {
      final session = TrackingSession(
        id: 'session-completed',
        startedAt: DateTime.utc(2026, 9, 7, 10, 0),
        updatedAt: DateTime.utc(2026, 9, 7, 11, 45),
        endedAt: DateTime.utc(2026, 9, 7, 11, 45),
        status: TrackingSessionStatus.completed,
        title: '설악산 공룡능선',
      );

      final summaryData = SessionSummaryData(
        duration: const Duration(hours: 1, minutes: 45),
        distanceKm: 4.85,
        pointCount: 156,
        start: session.startedAt,
        end: session.endedAt!,
        status: TrackingSessionStatus.completed,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SessionCard(
              session: session,
              summaryDataFuture: Future.value(summaryData),
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

      // Title & custom name
      expect(find.text('설악산 공룡능선'), findsOneWidget);

      // Status badge
      expect(find.text('완료'), findsOneWidget);

      // Visual metric chips
      expect(find.text('4.85 km'), findsOneWidget);
      expect(find.text('1시간 45분'), findsOneWidget);
      expect(find.text('156개 지점'), findsOneWidget);

      // Metric icons
      expect(find.byIcon(Icons.straighten_rounded), findsOneWidget);
      expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
      expect(find.byIcon(Icons.pin_drop_outlined), findsOneWidget);
    });

    testWidgets('renders active status badge for ongoing tracking sessions', (tester) async {
      final session = TrackingSession(
        id: 'session-active',
        startedAt: DateTime.utc(2026, 9, 7, 12, 0),
        updatedAt: DateTime.utc(2026, 9, 7, 12, 0),
        status: TrackingSessionStatus.active,
      );

      final summaryData = SessionSummaryData(
        duration: const Duration(minutes: 25),
        distanceKm: 1.20,
        pointCount: 45,
        start: session.startedAt,
        end: session.startedAt.add(const Duration(minutes: 25)),
        status: TrackingSessionStatus.active,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SessionCard(
              session: session,
              summaryDataFuture: Future.value(summaryData),
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

      // Active status badge
      expect(find.text('기록 중'), findsOneWidget);
      expect(find.text('1.20 km'), findsOneWidget);
      expect(find.text('25분 0초'), findsOneWidget);
      expect(find.text('45개 지점'), findsOneWidget);
    });
  });
}
