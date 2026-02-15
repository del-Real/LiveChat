import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:namer_app/api_config.dart';
import 'package:go_router/go_router.dart';

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  String message = "Verifying your email...";
  bool _hasStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // didChangeDependencies is used to safely access GoRouter context
    if (!_hasStarted) {
      _hasStarted = true;

      // Extracts the ?token=... from the URL query parameters
      final String? token =
          GoRouterState.of(context).uri.queryParameters['token'];

      if (token == null) {
        setState(() {
          message = "Invalid verification link (Missing Token)";
        });
        return;
      }

      verify(token);
    }
  }

  Future<void> verify(String token) async {
    try {
      // Using your project's central ApiConfig instead of teammate's missing serverUrl
      final url =
          Uri.parse("${ApiConfig.baseUrl}/users/verify-email?token=$token");

      final res = await http.get(url);

      if (res.statusCode == 200) {
        setState(() {
          message =
              "Email verified successfully!\nYou can now login to the app.";
        });
      } else {
        setState(() {
          message = "Verification failed or link expired.";
        });
      }
    } catch (e) {
      setState(() {
        message = "❌ Server error. Please check your connection.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.mark_email_read_outlined,
                  size: 80, color: Colors.blue),
              const SizedBox(height: 20),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              // Shows the button only if verification was successful
              if (message.contains("successfully")) ...[
                const SizedBox(height: 30),
                SizedBox(
                  width: 200,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => context.go('/login'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Go to Login",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                )
              ]
            ],
          ),
        ),
      ),
    );
  }
}
