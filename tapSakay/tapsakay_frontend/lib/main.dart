import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'theme.dart';
import 'screens/auth/login_screen.dart';
import 'app_root.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const TapSakayApp(),
    ),
  );
}

class TapSakayApp extends StatelessWidget {
  const TapSakayApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TapSakay',
      theme: appTheme,
      debugShowCheckedModeBanner: false,
      home: const AppRoot(),
    );
  }
}
