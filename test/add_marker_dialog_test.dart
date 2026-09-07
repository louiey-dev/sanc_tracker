import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanc_tracker/map/presentation/widgets/marker_input_dialog.dart';

void main() {
  testWidgets('MarkerInputDialog submits and disposes without error', (tester) async {
    Map<String, String>? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                result = await MarkerInputDialog.show(
                  context,
                  dialogTitle: '장소 마커 추가',
                  initialTitle: '장소 마커',
                );
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      ),
    );

    // Open dialog
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('장소 마커 추가'), findsOneWidget);
    expect(find.text('저장'), findsOneWidget);

    // Edit the text
    await tester.enterText(find.widgetWithText(TextField, '장소 마커'), '새 마커');
    await tester.pump();

    // Tap Save
    await tester.tap(find.text('저장'));
    // Allow pop animation to complete fully
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(result, isNotNull);
    expect(result!['title'], '새 마커');
  });

  testWidgets('PhotoMemoDialog submits and disposes without error', (tester) async {
    Map<String, String>? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                result = await PhotoMemoDialog.show(
                  context,
                  defaultTitle: '사진 2026-09-07',
                );
              },
              child: const Text('Open Photo Dialog'),
            ),
          ),
        ),
      ),
    );

    // Open dialog
    await tester.tap(find.text('Open Photo Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('사진 메모'), findsOneWidget);
    expect(find.text('저장'), findsOneWidget);

    // Enter memo
    await tester.enterText(find.byType(TextField).last, '아름다운 풍경');
    await tester.pump();

    // Tap Save
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(result, isNotNull);
    expect(result!['title'], '사진 2026-09-07');
    expect(result!['note'], '아름다운 풍경');
  });
}
