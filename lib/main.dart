import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'core/app_config.dart';
import 'core/app_logger.dart';
import 'tracking/presentation/tracking_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WakelockPlus.enable();
  final config = AppConfig.fromEnvironment();
  await KakaoMapSdk.instance.initialize(config.kakaoNativeAppKey);
  runApp(
    ProviderScope(
      overrides: [appConfigProvider.overrideWithValue(config)],
      child: SancTrackerApp(config: config),
    ),
  );
}

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);
final appLoggerProvider = Provider<AppLogger>(
  (ref) => AppLogger(ref.watch(appConfigProvider)),
);

class SancTrackerApp extends StatelessWidget {
  const SancTrackerApp({
    super.key,
    this.config = const AppConfig(
      environment: AppEnvironment.development,
      enableLogging: true,
    ),
  });
  final AppConfig config;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'SANC Tracker',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
    initialRoute: '/',
    routes: {'/': (_) => const TrackingPage()},
  );
}
