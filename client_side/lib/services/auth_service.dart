import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:namer_app/api_config.dart';
import 'package:namer_app/models/user.dart';
import 'package:http/http.dart' as http;

class AuthService {
  static const _storage = FlutterSecureStorage(
    webOptions: WebOptions(
      dbName: 'LCH_Storage',
      publicKey: 'LCH_Key',
    ),
  );

  static const String _keyId = 'user_id';
  static const String _keyUsername = 'username';
  static const String _keyEmail = 'email';
  static const String _keyDisplayName = 'display_name'; 
  static const String _keyProfilePic = 'profile_picture'; 

  Future<void> saveUser(User user) async {
    try {
      await _storage.write(key: _keyId, value: user.id);
      await _storage.write(key: _keyUsername, value: user.username);
      await _storage.write(key: _keyEmail, value: user.email);
      await _storage.write(key: _keyDisplayName, value: user.displayName ?? "");
      await _storage.write(key: _keyProfilePic, value: user.profilePicture ?? "");
    } catch (e) {
      print("Error saving user data: $e");
    }
  }

  Future<User?> getUser() async {
    try {
      final id = await _storage.read(key: _keyId);
      final username = await _storage.read(key: _keyUsername);
      final email = await _storage.read(key: _keyEmail);
      final displayName = await _storage.read(key: _keyDisplayName); 
      final profilePic = await _storage.read(key: _keyProfilePic); 

      if (id == null || username == null || email == null) {
        return null;
      }

      return User(
        id: id,
        username: username,
        email: email,
        displayName: displayName, 
        profilePicture: profilePic,
      );
    } catch (e) {
      print("Error reading user data: $e");
      return null;
    }
  }

  Future<String?> getUserId() async {
    return await _storage.read(key: _keyId);
  }

  Future<bool> isLoggedIn() async {
    final id = await _storage.read(key: _keyId);
    return id != null;
  }

  Future<void> clearUserData() async {
    await _storage.deleteAll();
  }

    Future<void> forgotPassword(String email) async {
    final response = await http .post(
      Uri.parse('${ApiConfig.baseUrl}/users/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    if (response.statusCode != 200) throw Exception('Failed to send reset email');
  }

  Future<void> resetPassword(String token, String password) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/users/reset-password/$token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'password': password}),
    );
    if (response.statusCode != 200) throw Exception('Failed to reset password');
  }
}