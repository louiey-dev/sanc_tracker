import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanc_tracker/settings/presentation/settings_screen.dart';

void main() {
  group('SettingsScreen app version display', () {
    testWidgets('renders version matching pubspec.yaml (v0.1.1) instead of hardcoded v1.0.0', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to bottom of SettingsScreen
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      // Should NOT render hardcoded v1.0.0
      expect(find.text('SANC Tracker v1.0.0'), findsNothing);

      // Should render pubspec.yaml version 0.1.1
      expect(find.text('SANC Tracker v0.1.1'), findsOneWidget);
    });

    testWidgets('renders overridden version when appVersionProvider emits new version', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appVersionProvider.overrideWith((ref) => Future.value('0.2.0')),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to bottom of SettingsScreen
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(find.text('SANC Tracker v0.2.0'), findsOneWidget);
    });
  });
}
