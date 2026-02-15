import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:namer_app/services/auth_service.dart';
import 'package:namer_app/theme/app_colors.dart';
import 'package:namer_app/helpers/Input_field.dart';
import 'package:namer_app/helpers/action_button.dart';
import 'package:namer_app/helpers/logo.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String token;
  const ResetPasswordScreen({super.key, required this.token});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _loading = false;


  bool _isValidPassword(String password) {
    final regex = RegExp(
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&]).{8,}$',
    );
    return regex.hasMatch(password);
  }

  Future<void> _submit() async {
    final pass = _passwordController.text.trim();
    final confirm = _confirmController.text.trim();

    if (pass.isEmpty || confirm.isEmpty) {
      _showSnackBar('Please fill in all fields', isError: true);
      return;
    }

    if (pass != confirm) {
      _showSnackBar('Passwords do not match', isError: true);
      return;
    }

    if (!_isValidPassword(pass)) {
      _showSnackBar(
        'Password must be at least 8 characters and include uppercase, lowercase, number, and symbol',
        isError: true,
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await AuthService().resetPassword(widget.token, pass);

      if (mounted) {
        _showSnackBar('Password reset successful!', isSuccess: true);
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          e.toString().replaceAll('Exception: ', ''),
          isError: true,
        );
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  void _showSnackBar(
    String message, {
    bool isError = false,
    bool isSuccess = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? AppErrorColor : (isSuccess ? Colors.green : Colors.grey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Column(
            children: [
              const LiveChatLogo(),
              const SizedBox(height: 50),
              Text(
                'Reset Password',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color:
                      Theme.of(context).textTheme.titleLarge?.color,
                ),
              ),
              const SizedBox(height: 40),
              InputField(
                hintText: 'New Password',
                icon: Icons.lock_outline,
                isPassword: true,
                controller: _passwordController,
              ),
              const SizedBox(height: 20),
              InputField(
                hintText: 'Confirm Password',
                icon: Icons.lock_reset,
                isPassword: true,
                controller: _confirmController,
              ),
              const SizedBox(height: 40),
              ActionButton(
                text: 'Update Password',
                icon: Icons.security_rounded,
                color: AppPrimaryColor,
                isLoading: _loading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
