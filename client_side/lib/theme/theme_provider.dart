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
  bool _isInitialized = false;

  ThemeProvider() {
    _init();
  }

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isInitialized => _isInitialized;

  Future<void> _init() async {
    try {
      final saved = await _storage.read(key: 'theme_mode');
      if (saved != null) {
        _themeMode = saved == 'light' ? ThemeMode.light : ThemeMode.dark;
      }
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint("[Theme] Init failed: $e");
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> toggleTheme(bool isDark) async {
    final nextMode = isDark ? ThemeMode.dark : ThemeMode.light;
    if (_themeMode == nextMode) return;

    _themeMode = nextMode;
    notifyListeners();

    try {
      await _storage.write(key: 'theme_mode', value: isDark ? 'dark' : 'light');
    } catch (e) {
      debugPrint("Theme persistence error: $e");
    }
  }
}