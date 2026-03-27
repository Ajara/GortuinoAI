import 'dart:developer' as developer;

class AppLogger {
  static void info(String message, {String name = 'APP'}) {
    developer.log(message, name: name, level: 800);
  }

  static void warning(String message, {String name = 'APP'}) {
    developer.log(message, name: name, level: 900);
  }

  static void error(
    String message, {
    String name = 'APP',
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(
      message,
      name: name,
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
