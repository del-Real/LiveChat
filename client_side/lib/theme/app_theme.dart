import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: AppPrimaryColor,
    scaffoldBackgroundColor: Colors.white,
    cardColor: Colors.grey[100], 
    
    colorScheme: const ColorScheme.light(
      primary: AppPrimaryColor,
      secondary: AppSuccessColor,
      surface: Colors.white,
      onSurface: Colors.black,
      error: AppErrorColor,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black, 
      elevation: 0,
    ),

    textTheme: const TextTheme(
      displayLarge: TextStyle(color: Colors.black),
      titleLarge: TextStyle(color: Colors.black),
      bodyLarge: TextStyle(color: Colors.black),
      bodyMedium: TextStyle(color: Colors.black),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: AppPrimaryColor,
    scaffoldBackgroundColor: AppDarkBackground,
    cardColor: const Color(0xFF1E1E1E), 

    colorScheme: const ColorScheme.dark(
      primary: AppPrimaryColor,
      secondary: AppSuccessColor,
      surface: AppDarkBackground,
      onSurface: Colors.white,
      error: AppErrorColor,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: AppDarkBackground,
      foregroundColor: Colors.white,
      elevation: 0,
    ),

    textTheme: const TextTheme(
      displayLarge: TextStyle(color: Colors.white),
      titleLarge: TextStyle(color: Colors.white),
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white),
    ),
  );
}