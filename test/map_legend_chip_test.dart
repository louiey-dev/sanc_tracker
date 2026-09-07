import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanc_tracker/tracking/presentation/widgets/map_legend_chip.dart';

void main() {
  group('MapLegendChip', () {
    testWidgets('starts collapsed and expands on tap, collapses on close', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MapLegendChip(),
          ),
        ),
      );

      // Initially collapsed
      expect(find.text('범례'), findsOneWidget);
      expect(find.text('지도 범례'), findsNothing);
      expect(find.text('현재 위치'), findsNothing);
      expect(find.text('실시간 추적 경로'), findsNothing);
      expect(find.text('저장된 경로'), findsNothing);

      // Tap to expand
      await tester.tap(find.text('범례'));
      await tester.pumpAndSettle();

      // Expanded state
      expect(find.text('지도 범례'), findsOneWidget);
      expect(find.text('현재 위치'), findsOneWidget);
      expect(find.text('실시간 추적 경로'), findsOneWidget);
      expect(find.text('저장된 경로'), findsOneWidget);
      expect(find.text('장소 마커'), findsOneWidget);
      expect(find.text('사진 마커'), findsOneWidget);

      // Tap close button
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Collapsed again
      expect(find.text('범례'), findsOneWidget);
      expect(find.text('지도 범례'), findsNothing);
    });
  });
}
