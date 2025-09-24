import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/passenger/home_screen.dart';
import 'screens/driver/home_screen.dart';

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    if (!auth.isLoggedIn) return const LoginScreen();
    if (auth.user!.role == 'driver') return const DriverHomeScreen();
    return const PassengerHomeScreen();
  }
}