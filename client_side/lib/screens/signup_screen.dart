
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:namer_app/api_config.dart';
import 'package:namer_app/helpers/logo.dart';
import 'package:namer_app/helpers/Input_field.dart';
import 'package:namer_app/theme/app_colors.dart';
import 'package:namer_app/helpers/action_button.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;

  bool _isValidEmail(String email) {
    final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return regex.hasMatch(email);
  }

  bool _isStrongPassword(String password) {
    if (password.length < 8) return false;
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(password);
    final hasNumber = RegExp(r'\d').hasMatch(password);
    return hasLetter && hasNumber;
  }

  Future<void> _handleSignup() async {
    if (_isLoading) return;

    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || email.isEmpty || password.isEmpty) {
      _showMessage('Please fill in all fields');
      return;
    }

    if (!_isValidEmail(email)) {
      _showMessage('Please enter a valid email');
      return;
    }

    if (!_isStrongPassword(password)) {
      _showMessage(
        'Password must be at least 8 characters and contain letters and numbers',
      );
      return;
    }

    setState(() => _isLoading = true);

    Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _isLoading = false);
    });

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/users/create');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 201) {
        _showMessage(
          'Account created successfully. Please check your email.',
          success: true,
        );
        Navigator.pop(context);
      } else {
        _showMessage(response.body);
      }
    } catch (e) {
      _showMessage('Connection error. Please try again.');
    }
  }

  void _showMessage(String text, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).textTheme.titleLarge?.color;

    return Scaffold(
      backgroundColor: scaffoldBg, 
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).appBarTheme.foregroundColor),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const LiveChatLogo(),
              const SizedBox(height: 60),
              Text(
                'Create Account',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: textColor, 
                ),
              ),
              const SizedBox(height: 40),
              InputField(
                hintText: 'Username',
                icon: Icons.person_outline,
                controller: _usernameController,
              ),
              const SizedBox(height: 16),
              InputField(
                hintText: 'Email',
                icon: Icons.email_outlined,
                controller: _emailController,
              ),
              const SizedBox(height: 16),
              InputField(
                hintText: 'Password',
                icon: Icons.lock_outline,
                controller: _passwordController,
                isPassword: true,
              ),
              const SizedBox(height: 30),
              ActionButton(
                text: 'Sign Up',
                color: AppPrimaryColor,
                isLoading: _isLoading,
                onPressed: _handleSignup,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
