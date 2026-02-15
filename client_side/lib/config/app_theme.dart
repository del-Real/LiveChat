import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/**
 * @file App Theme
 * @description Highly customized theme configurations for immersive UI experience.
 */

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppPrimaryColor,
      scaffoldBackgroundColor: const Color(0xFFF9FAFB),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: false,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
            fontWeight: FontWeight.bold, color: Colors.black, fontSize: 24),
        bodyLarge: TextStyle(color: Colors.black87, fontSize: 16),
        bodySmall: TextStyle(color: Colors.black54, fontSize: 13),
      ),
      dividerColor: Colors.grey[200],
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppPrimaryColor,
      scaffoldBackgroundColor: const Color(0xFF111827),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1F2937),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
            fontWeight: FontWeight.bold, color: Colors.white, fontSize: 24),
        bodyLarge: TextStyle(color: Colors.white, fontSize: 16),
        bodySmall: TextStyle(color: Colors.white70, fontSize: 13),
      ),
      dividerColor: Colors.white12,
    );
  }
}
