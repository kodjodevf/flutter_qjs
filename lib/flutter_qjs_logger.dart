import 'dart:developer' as developer;

enum FlutterQjsLogLevel { debug, info, warning, error }

typedef FlutterQjsLogHandler =
    void Function(FlutterQjsLogLevel level, String message, Object? error);

class FlutterQjsLogger {
  FlutterQjsLogger._();

  static bool enabled = true;

  static FlutterQjsLogLevel level = FlutterQjsLogLevel.info;

  static FlutterQjsLogHandler? handler;

  static void debug(String message, [Object? error]) {
    log(FlutterQjsLogLevel.debug, message, error);
  }

  static void info(String message, [Object? error]) {
    log(FlutterQjsLogLevel.info, message, error);
  }

  static void warning(String message, [Object? error]) {
    log(FlutterQjsLogLevel.warning, message, error);
  }

  static void error(String message, [Object? error]) {
    log(FlutterQjsLogLevel.error, message, error);
  }

  static void log(
    FlutterQjsLogLevel logLevel,
    String message, [
    Object? error,
  ]) {
    if (!enabled || logLevel.index < level.index) return;
    final activeHandler = handler;
    if (activeHandler != null) {
      activeHandler(logLevel, message, error);
      return;
    }
    developer.log(
      message,
      name: 'flutter_qjs_es2023',
      level: _developerLevel(logLevel),
      error: error,
    );
  }

  static int _developerLevel(FlutterQjsLogLevel level) {
    switch (level) {
      case FlutterQjsLogLevel.debug:
        return 500;
      case FlutterQjsLogLevel.info:
        return 800;
      case FlutterQjsLogLevel.warning:
        return 900;
      case FlutterQjsLogLevel.error:
        return 1000;
    }
  }
}
