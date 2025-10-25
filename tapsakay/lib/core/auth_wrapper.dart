import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../user/login_api.dart';
import '../admin/admin_dashboard.dart';
import '../driver/driver_page.dart';
import '../passenger/passenger_page.dart';
import '../user/login.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _checkAuthAndGetRole();
    
    // Listen to auth state changes
    _supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn) {
        _checkAuthAndGetRole();
      } else if (event == AuthChangeEvent.signedOut) {
        setState(() {
          _userRole = null;
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _checkAuthAndGetRole() async {
    try {
      final user = _supabase.auth.currentUser;
      
      print('Current user: ${user?.id}');
      
      if (user == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Get user role from database
      final role = await LoginApi.getUserRole();
      
      print('User role: $role');
      
      setState(() {
        _userRole = role;
        _isLoading = false;
      });
    } catch (e) {
      print('Error in _checkAuthAndGetRole: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F7FA),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Not logged in
    if (_userRole == null) {
      return const LoginPage();
    }

    // Route based on role
    switch (_userRole) {
      case 'admin':
        return const AdminDashboard();
      case 'driver':
        return const DriverDashboard();
      case 'passenger':
        return const PassengerHome();
      default:
        return const LoginPage();
    }
  }
}