import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sanc_tracker/main.dart';

void main() {
  testWidgets('shows the initial tracking screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: SancTrackerApp()));

    expect(find.text('SANC Tracker'), findsOneWidget);
    expect(find.text('추적 대기'), findsOneWidget);
    expect(find.text('시작'), findsOneWidget);
    expect(find.text('저장된 마커'), findsOneWidget);
    await tester.tap(find.text('저장된 마커'));
    await tester.pump();
    expect(find.text('저장된 마커 없음'), findsOneWidget);
  });
}
