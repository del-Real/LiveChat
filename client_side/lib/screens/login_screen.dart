import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:namer_app/api_config.dart';
import 'package:namer_app/models/user.dart';
import 'package:namer_app/services/auth_service.dart';
import 'package:namer_app/theme/app_colors.dart';
import 'package:namer_app/helpers/logo.dart';
import 'package:namer_app/helpers/Input_field.dart';
import 'package:namer_app/helpers/action_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    final String identifier = _identifierController.text.trim();
    final String password = _passwordController.text.trim();

    if (identifier.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/users/login');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'identifier': identifier,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final user = User.fromJson(data['user']);

        await AuthService().saveUser(user);

        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Login Successful!'),
                backgroundColor: Colors.green),
          );
          context.go("/home");
        }
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['message'] ?? 'Login Failed';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Login Failed: $errorMessage'),
                backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connection Error. Check server.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 60.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 50),
            const LiveChatLogo(),
            const SizedBox(height: 60),

            InputField(
              hintText: 'Username or Email',
              icon: Icons.person_outline,
              controller: _identifierController,
            ),

            const SizedBox(height: 20),

            InputField(
              hintText: 'Password',
              icon: Icons.lock_outline,
              controller: _passwordController,
              isPassword: true,
            ),

            const SizedBox(height: 20),

            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => context.go('/forgot-password'),
                child: Text(
                  'I forgot my password',
                  style: TextStyle(
                    color: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.color
                        ?.withOpacity(0.7),
                    fontSize: 14,
                    decoration:
                        TextDecoration.underline, // Added teammate's underline
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),

            ActionButton(
              text: 'Login',
              icon: Icons.vpn_key_outlined,
              color: AppPrimaryColor,
              onPressed: _handleLogin,
              isLoading: _isLoading,
            ),

            const SizedBox(height: 20),

            ActionButton(
              text: 'Sign up',
              icon: Icons.person_add,
              color: const Color.fromARGB(255, 78, 24, 129),
              isSecondary: true,
              onPressed: () => context.push('/signup'),
            ),
          ],
        ),
      ),
    );
  }
}


class _ForgotPasswordButton extends StatelessWidget {
  const _ForgotPasswordButton();

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () {},
      child: const Text(
        'I forgot my password',
        style: TextStyle(color: Colors.white70, fontSize: 14),
      ),
    );
  }
}
