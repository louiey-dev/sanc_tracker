import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';
import 'core/app_config.dart';
import 'core/app_logger.dart';
import 'tracking/presentation/tracking_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode) {
    await WakelockPlus.enable();
  }
  final config = AppConfig.fromEnvironment();
  runApp(
    ProviderScope(
      overrides: [appConfigProvider.overrideWithValue(config)],
      child: SancTrackerApp(config: config, initializeSdk: true),
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
    this.initializeSdk = false,
  });
  final AppConfig config;
  final bool initializeSdk;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'SANC Tracker',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
    home: initializeSdk ? _SdkBootstrap(config: config) : const TrackingPage(),
  );
}

class _SdkBootstrap extends StatefulWidget {
  const _SdkBootstrap({required this.config});
  final AppConfig config;

  @override
  State<_SdkBootstrap> createState() => _SdkBootstrapState();
}

class _SdkBootstrapState extends State<_SdkBootstrap> {
  late final Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _initialization = _initialize();
  }

  Future<void> _initialize() async {
    if (widget.config.kakaoNativeAppKey.trim().isEmpty) {
      throw StateError(
        'KAKAO_NATIVE_APP_KEY is missing. Rebuild with --dart-define.',
      );
    }
    await KakaoMapSdk.instance.initialize(widget.config.kakaoNativeAppKey);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _initialization,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _StartupError(error: snapshot.error!);
      }
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return const TrackingPage();
    },
  );
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('앱을 시작하지 못했습니다.\n\n$error', textAlign: TextAlign.center),
      ),
    ),
  );
}
