import 'package:flutter/foundation.dart';

/**
 * @file Logger Service
 * @description Advanced debugging and telemetry collector for the frontend.
 */

class AppLogger {
  static void debug(String message, [dynamic error, StackTrace? stack]) {
    if (kDebugMode) {
      print('🔍 [DEBUG] ${DateTime.now()}: $message');
      if (error != null) print('❌ Error: $error');
      if (stack != null) print('📜 Stack: $stack');
    }
  }

  static void info(String message) {
    print('ℹ️ [INFO] ${DateTime.now()}: $message');
  }

  static void warning(String message) {
    print('⚠️ [WARN] ${DateTime.now()}: $message');
  }

  static void error(String message, [dynamic error, StackTrace? stack]) {
    print('🚨 [ERROR] ${DateTime.now()}: $message');
    if (error != null) print('❌ Exception: $error');
    if (stack != null) print('📜 Stack Trace:\n$stack');
    
    // In a real app, we would send this to Sentry or Firebase Crashlytics here.
  }
}
