import 'package:flutter/foundation.dart';

class ApiConfig {
  static const bool _usePhysicalDevice = false;
  static const String _physicalDeviceIp = 'http://192.168.1.35:3000';

  static String get baseUrl {
    if (_usePhysicalDevice) {
      return _physicalDeviceIp;
    }

    if (kIsWeb) {
      return 'http://localhost:3000';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'http://127.0.0.1:3000';
    }

    return 'http://localhost:3000';
  }
}

/*
class ApiConfig {
  // static const String baseUrl =
  //     'https://starfish-app-mjk27.ondigitalocean.app';
  static const String baseUrl = 'http://10.0.2.2:3000';
  static const String socketUrl = baseUrl;
}
*/
