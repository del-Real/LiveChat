import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    visualDensity: VisualDensity.standard,
    brightness: Brightness.light,
    primaryColor: AppPrimaryColor,
    scaffoldBackgroundColor: const Color(0xFFF2F2F7),
    cardColor: Colors.white,
    splashFactory: NoSplash.splashFactory,
    
    colorScheme: const ColorScheme.light(
      primary: AppPrimaryColor,
      surface: Colors.white,
      onSurface: Colors.black,
      error: AppErrorColor,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black, 
      elevation: 0,
      centerTitle: true,
      surfaceTintColor: Colors.transparent,
    ),

    cardTheme: const CardThemeData(
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),

    textTheme: const TextTheme(
      displayLarge: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
      titleLarge: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
      titleMedium: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: Colors.black, fontSize: 16),
      bodyMedium: TextStyle(color: Colors.black87, fontSize: 14),
      bodySmall: TextStyle(color: Colors.black54, fontSize: 12),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    visualDensity: VisualDensity.standard,
    brightness: Brightness.dark,
    primaryColor: AppPrimaryColor,
    scaffoldBackgroundColor: AppDarkBackground,
    cardColor: const Color(0xFF1C1C1E), 
    splashFactory: NoSplash.splashFactory,
    
    colorScheme: const ColorScheme.dark(
      primary: AppPrimaryColor,
      surface: AppDarkBackground,
      onSurface: Colors.white,
      error: AppErrorColor,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: AppDarkBackground,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      surfaceTintColor: Colors.transparent,
    ),

    cardTheme: const CardThemeData(
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),

    textTheme: const TextTheme(
      displayLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      titleMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: Colors.white, fontSize: 16),
      bodyMedium: TextStyle(color: Colors.white70, fontSize: 14),
      bodySmall: TextStyle(color: Colors.white54, fontSize: 12),
    ),
  );
}