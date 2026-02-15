import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:namer_app/api_config.dart';
import 'package:namer_app/models/chat.dart';
import 'package:namer_app/services/auth_service.dart';

typedef UserId = String;

// Service responsible for fetching homepage-related data.
// This class handles retrieving user chats from the backend.
class HomepageService {
  final AuthService _authService = AuthService();

  // Fetch all chats for the currently logged-in user.
  Future<List<ChatModel>> getUserChats() async {
    try {
      final user = await _authService.getUser();
      if (user == null) {
        throw Exception("User session not found");
      }

      final UserId userId = user.id;
      final Uri url = _buildChatsUri(userId);

      final http.Response response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList
            .map(
              (json) => ChatModel.fromJson(json, currentUserId: userId),
            )
            .toList();
      } else {
        final dynamic errorBody = _safeDecode(response.body);
        throw Exception(
          errorBody is Map && errorBody['error'] != null
              ? errorBody['error']
              : 'Failed to load chats',
        );
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  // Build chats endpoint URI
  Uri _buildChatsUri(UserId userId) {
    return Uri.parse('${ApiConfig.baseUrl}/chats/$userId');
  }

  // Decode JSON safely without throwing
  dynamic _safeDecode(String source) {
    try {
      return jsonDecode(source);
    } catch (_) {
      return null;
    }
  }
}

//Extensions

extension HomepageServiceExtensions on HomepageService {
  // Checking service availability
  bool get isReady => true;
}
