import 'package:flutter/foundation.dart';

enum AppEnvironment { development, production }

class AppConfig {
  const AppConfig({
    required this.environment,
    required this.enableLogging,
    this.kakaoNativeAppKey = '',
    this.kakaoWebAppKey = '',
  });

  final AppEnvironment environment;
  final bool enableLogging;
  final String kakaoNativeAppKey;
  final String kakaoWebAppKey;

  bool get isProduction => environment == AppEnvironment.production;

  static AppConfig fromEnvironment() {
    const value = String.fromEnvironment(
      'SANC_ENV',
      defaultValue: 'development',
    );
    const logging = String.fromEnvironment('SANC_LOGGING', defaultValue: '');
    const nativeKey = String.fromEnvironment('KAKAO_NATIVE_APP_KEY');
    const webKey = String.fromEnvironment('KAKAO_WEB_APP_KEY');
    final environment = value.toLowerCase() == 'production'
        ? AppEnvironment.production
        : AppEnvironment.development;
    final enableLogging = logging.isEmpty
        ? kDebugMode
        : logging.toLowerCase() == 'true';
    return AppConfig(
      environment: environment,
      enableLogging: enableLogging,
      kakaoNativeAppKey: nativeKey,
      kakaoWebAppKey: webKey,
    );
  }
}
