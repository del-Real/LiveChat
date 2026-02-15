/**
 * @file App Constants
 * @description Centralized configuration for business logic and UI strings.
 */

class AppConstants {
  // Networking
  static const int apiTimeoutSeconds = 30;
  static const int paginationLimit = 20;

  // Real-time
  static const int typingDebounceMs = 2000;
  
  // UI - Messaging
  static const String systemSenderId = 'system';
  static const String unknownUserName = 'Unknown User';
  
  // Error Messages
  static const String sessionExpired = 'Your session has expired. Please log in again.';
  static const String connectionError = 'Unable to reach the server. Please check your internet.';
  static const String genericError = 'Something went wrong. Our team is looking into it.';
  
  // Storage Keys
  static const String userPrefsKey = 'user_preferences';
  static const String themeKey = 'app_theme_mode';
}

class SocketEvents {
  static const String sendMessage = 'send_message';
  static const String receiveMessage = 'receive_message';
  static const String joinRoom = 'join_room';
  static const String leaveRoom = 'leave_room';
  static const String userStatusUpdate = 'user_status_update';
  static const String chatStatusUpdated = 'chat_status_updated';
}
