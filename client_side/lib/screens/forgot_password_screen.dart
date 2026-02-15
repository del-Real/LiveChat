import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:namer_app/services/auth_service.dart';
import 'package:namer_app/theme/app_colors.dart';
import 'package:namer_app/helpers/Input_field.dart';
import 'package:namer_app/helpers/action_button.dart';
import 'package:namer_app/helpers/logo.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _loading = false;

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnackBar('Please enter your email', isError: true);
      return;
    }

    setState(() => _loading = true);

    try {
      await AuthService().forgotPassword(email);
      if (mounted) {
        _showSnackBar('Reset link sent to your email');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(e.toString().replaceAll('Exception: ', ''), isError: true);
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppErrorColor : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: Theme.of(context).appBarTheme.foregroundColor),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30.0),
        child: Column(
          children: [
            const LiveChatLogo(),
            const SizedBox(height: 50),
            Text(
              'Forgot Password?',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.titleLarge?.color, 
              ),
            ),
            const SizedBox(height: 15),
            Text(
              'Enter your email and we will send you a link to reset your password.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7), 
                fontSize: 14
              ),
            ),
            const SizedBox(height: 40),
            InputField(
              hintText: 'Email address',
              icon: Icons.email_outlined,
              controller: _emailController,
            ),
            const SizedBox(height: 40),
            ActionButton(
              text: 'Send Reset Link',
              icon: Icons.send_rounded,
              color: AppPrimaryColor,
              isLoading: _loading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}