import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:namer_app/api_config.dart';
import 'package:namer_app/models/chat.dart';
import 'package:namer_app/models/contact.dart';
import 'package:namer_app/services/auth_service.dart';

class ContactService {
  final AuthService _authService = AuthService();

  // Send a contact request to a user by username
  Future<String> sendContactRequest(String username) async {
    try {
      final user = await _authService.getUser();
      if (user == null) throw Exception('User session not found');

      final url = Uri.parse('${ApiConfig.baseUrl}/contacts/request');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'senderId': user.id,
          'username': username,
        }),
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return responseBody['message'] ?? 'Contact request sent';
      } else if (response.statusCode == 400) {
        // Handle specific error cases
        throw Exception(responseBody['message'] ?? 'Bad request');
      } else if (response.statusCode == 404) {
        throw Exception('User not found');
      } else {
        throw Exception(responseBody['message'] ?? 'Failed to send request');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  Future<List<ContactModel>> getContacts() async {
    try {
      final user = await _authService.getUser();
      if (user == null) throw Exception('User session not found');

      final url =
          Uri.parse('${ApiConfig.baseUrl}/contacts/get_contacts/${user.id}');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.map((json) => ContactModel.fromJson(json)).toList();
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception(errorBody['message'] ?? 'Failed to load contacts');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  Future<List<ContactModel>> getContactRequests() async {
    try {
      final user = await _authService.getUser();
      if (user == null) throw Exception('User session not found');

      final url =
          Uri.parse('${ApiConfig.baseUrl}/contacts/requests/${user.id}');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.map((json) => ContactModel.fromJson(json)).toList();
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception(errorBody['message'] ?? 'Failed to load requests');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  /// Respond to a contact request
  Future<String> respondToRequest({
    required String requesterId,
    required String action,
  }) async {
    try {
      final user = await _authService.getUser();
      if (user == null) throw Exception('User session not found');

      if (!['accept', 'reject'].contains(action)) {
        throw Exception('Invalid action. Use "accept" or "reject"');
      }

      final url = Uri.parse('${ApiConfig.baseUrl}/contacts/respond');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'requesterId': requesterId,
          'receiverId': user.id,
          'action': action,
        }),
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return responseBody['message'] ?? 'Request processed';
      } else if (response.statusCode == 404) {
        throw Exception('Request not found');
      } else {
        throw Exception(
            responseBody['message'] ?? 'Failed to respond to request');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  // Accept a contact request
  Future<void> acceptRequest(String requesterId) async {
    await respondToRequest(
      requesterId: requesterId,
      action: 'accept',
    );
  }

  // Reject a contact request
  Future<void> rejectRequest(String requesterId) async {
    await respondToRequest(
      requesterId: requesterId,
      action: 'reject',
    );
  }

  Future<ChatModel> startChatWithContact(String contactId) async {
    try {
      final user = await _authService.getUser();
      if (user == null) throw Exception('User session not found');

      final url = Uri.parse('${ApiConfig.baseUrl}/chats/start_chat');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': user.id,
          'contactId': contactId,
        }),
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ChatModel.fromJson(data, currentUserId: user.id);
      } else if (response.statusCode == 403) {
        throw Exception('Not in your contacts');
      } else {
        throw Exception(responseBody['message'] ?? 'Failed to start chatt');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  Future<void> updateContactStatus(
      String contactId, Map<String, dynamic> data) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/contacts/$contactId/status');
      final response = await http.patch(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update contact');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  Future<void> deleteContact(String contactId) async {
    try {
      final user = await _authService.getUser();
      if (user == null) throw Exception('User session not found');

      final url = Uri.parse('${ApiConfig.baseUrl}/contacts/$contactId');
      final response = await http.delete(
        url,
        body: jsonEncode({"userId": user.id}),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete contact');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }
}
