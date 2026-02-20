import 'package:flutter/material.dart';
import 'package:namer_app/router.dart';
import 'package:namer_app/services/contact_provider.dart';
import 'package:provider/provider.dart';
import 'theme/theme_provider.dart';
import 'theme/app_theme.dart';
import 'services/chat_service.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final contactProvider = ContactProvider();
  final chatService = ChatService(contactProvider);
  
  runApp(
    MultiProvider(providers: [
      ChangeNotifierProvider(create: (_) => chatService),
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(create: (_) => contactProvider),
    ],
    child: const MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget { 
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp.router(
          routerConfig: router,
          title: 'LiveChat App',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
        );
      },
    );
  }
}