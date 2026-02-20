import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ThemeProvider extends ChangeNotifier {
  static const _storage = FlutterSecureStorage(
    webOptions: WebOptions(
      dbName: 'LCH_Storage',
      publicKey: 'LCH_Key',
    ),
  );

  ThemeMode _themeMode = ThemeMode.dark;

  ThemeProvider() {
    _loadTheme();
  }

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> _loadTheme() async {
    try {
      final savedTheme = await _storage.read(key: 'theme_mode');
      if (savedTheme != null) {
        _themeMode = savedTheme == 'light' ? ThemeMode.light : ThemeMode.dark;
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error loading theme: $e");
    }
  }

  void toggleTheme(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners(); 
    
    try {
      await _storage.write(key: 'theme_mode', value: isDark ? 'dark' : 'light');
    } catch (e) {
      debugPrint("Error saving theme: $e");
    }
  }
}