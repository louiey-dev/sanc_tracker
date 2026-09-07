import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanc_tracker/tracking/domain/tracking_state.dart';
import 'package:sanc_tracker/tracking/presentation/widgets/tracking_hud_card.dart';

void main() {
  group('TrackingHudCard collapse and expand behavior', () {
    testWidgets('starts collapsed by default for maximum map visibility', (tester) async {
      var toggled = false;
      const state = TrackingState();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrackingHudCard(
              tracking: state,
              onToggleTracking: () => toggled = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially collapsed by default: Status and compact button are visible, full 3 columns hidden
      expect(find.text('추적 대기'), findsOneWidget);
      expect(find.text('시간'), findsNothing);
      expect(find.text('거리'), findsNothing);
      expect(find.text('속도'), findsNothing);
      expect(find.text('시작'), findsOneWidget);
      expect(find.byTooltip('메뉴 펼치기'), findsOneWidget);

      // Tap compact start button while collapsed
      await tester.tap(find.text('시작'));
      expect(toggled, isTrue);

      // Tap expand button
      await tester.tap(find.byTooltip('메뉴 펼치기'));
      await tester.pumpAndSettle();

      // Expanded: Metrics visible
      expect(find.text('시간'), findsOneWidget);
      expect(find.text('거리'), findsOneWidget);
      expect(find.text('속도'), findsOneWidget);
      expect(find.byTooltip('메뉴 접기'), findsOneWidget);

      // Tap collapse button
      await tester.tap(find.byTooltip('메뉴 접기'));
      await tester.pumpAndSettle();

      // Collapsed again
      expect(find.text('시간'), findsNothing);
      expect(find.byTooltip('메뉴 펼치기'), findsOneWidget);
    });

    testWidgets('starts expanded when initiallyCollapsed is false', (tester) async {
      const state = TrackingState();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrackingHudCard(
              tracking: state,
              onToggleTracking: () {},
              initiallyCollapsed: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('추적 대기'), findsOneWidget);
      expect(find.text('시간'), findsOneWidget);
      expect(find.text('거리'), findsOneWidget);
      expect(find.text('속도'), findsOneWidget);
      expect(find.byTooltip('메뉴 접기'), findsOneWidget);
    });
  });
}
