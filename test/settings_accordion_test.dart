import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanc_tracker/settings/presentation/settings_screen.dart';

void main() {
  group('SettingsScreen background guidance accordions', () {
    testWidgets('renders concise summary and collapsible vendor sections', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Concise summary message
      expect(
        find.text('추적 중에는 화면이 꺼지거나 다른 앱을 사용 중이어도 위치가 기기에 안전하게 기록됩니다.'),
        findsOneWidget,
      );

      // Accordion headers
      expect(find.text('기본 Android 권장 설정'), findsOneWidget);
      expect(find.text('Samsung (Galaxy) 기기 설정'), findsOneWidget);
      expect(find.text('Xiaomi / Redmi 기기 설정'), findsOneWidget);
      expect(find.text('비정상 종료 자동 복구 안내'), findsOneWidget);

      // Scroll and tap to expand Samsung section
      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Samsung (Galaxy) 기기 설정'));
      await tester.pumpAndSettle();

      expect(find.textContaining('절전 예외 앱'), findsWidgets);
    });
  });
}
