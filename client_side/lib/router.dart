import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:namer_app/screens/contact_requests_screen.dart';
import 'package:namer_app/screens/contacts_screen.dart';
import 'package:namer_app/services/auth_service.dart';
import 'package:namer_app/screens/chat_screen.dart';
import 'package:namer_app/screens/home_screen.dart';
import 'package:namer_app/screens/login_screen.dart';
import 'package:namer_app/screens/main_screen.dart';
import 'package:namer_app/screens/settings_screen.dart';
import 'package:namer_app/verify_email_page.dart';
import 'package:namer_app/screens/forgot_password_screen.dart';
import 'package:namer_app/screens/reset_password_screen.dart';
import 'package:namer_app/screens/signup_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorChatsKey = GlobalKey<NavigatorState>(debugLabel: 'home');
final _shellNavigatorContactsKey = GlobalKey<NavigatorState>(debugLabel: 'contacts');
final _shellNavigatorSettingsKey = GlobalKey<NavigatorState>(debugLabel: 'settings');

final router = GoRouter(
  initialLocation: '/home', // Redirect logic handles checking login state
  navigatorKey: _rootNavigatorKey,
  errorBuilder: (context, state) => const LoginScreen(),
  redirect: (context, state) async {
    final authService = AuthService();
    final isLoggedIn = await authService.isLoggedIn();

    // Pages that don't require being logged in
    final bool isAuthPage = state.matchedLocation == '/login' ||
        state.matchedLocation == '/forgot-password' ||
        state.matchedLocation == '/signup' ||
        state.matchedLocation.startsWith('/reset-password/') ||
        state.matchedLocation == '/verify-email';

    if (!isLoggedIn && !isAuthPage) {
      return '/login';
    }

    if (isLoggedIn && isAuthPage) {
      return '/home';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignupPage(),
    ),
    GoRoute(
      path: '/verify-email',
      builder: (context, state) => const VerifyEmailPage(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/reset-password/:token',
      builder: (context, state) {
        final token = state.pathParameters['token']!;
        return ResetPasswordScreen(token: token);
      },
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainScreen(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          navigatorKey: _shellNavigatorChatsKey,
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
              routes: [
                GoRoute(
                  path: '/chat/:chatId',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) {
                    final chatId = state.pathParameters['chatId']!;
                    return ChatScreen(chatId: chatId);
                  },
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _shellNavigatorContactsKey,
          routes: [
            GoRoute(
              path: '/contacts',
              builder: (context, state) => const ContactsScreen(),
              routes: [
                GoRoute(
                  path: '/requests', 
                  parentNavigatorKey: _rootNavigatorKey,
                  builder:(context, state) => const RequestsScreen(),
                )
              ]
              )
          ]
        ),
        StatefulShellBranch(
          navigatorKey: _shellNavigatorSettingsKey,
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);
