import 'dart:developer' as developer;

import 'app_config.dart';

class AppLogger {
  const AppLogger(this.config);

  final AppConfig config;

  void info(String message) {
    if (config.enableLogging) {
      developer.log(message, name: 'sanc_tracker');
    }
  }

  void error(String message, Object error, StackTrace stackTrace) {
    if (config.enableLogging) {
      developer.log(
        message,
        name: 'sanc_tracker',
        error: error,
        stackTrace: stackTrace,
        level: 1000,
      );
    }
  }
}
