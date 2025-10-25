import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterApi {
  static final _supabase = Supabase.instance.client;

  /// Register a new user with email, password, and profile information
  static Future<AuthResponse> register({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
  }) async {
    try {
      // Sign up with Supabase Auth
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'phone_number': phoneNumber,  // Add this line
          'role': 'passenger',
        },
      );

      if (response.user == null) {
        throw Exception('Registration failed. Please try again.');
      }

      // Update the users table with additional info
      // The trigger should have created the record, but we'll update phone number
 

      return response;
    } on AuthException catch (e) {
      throw Exception(_getAuthErrorMessage(e.message));
    } catch (e) {
      throw Exception('An unexpected error occurred during registration.');
    }
  }

  /// Validate email format
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  /// Validate phone number format (basic validation)
  static bool isValidPhoneNumber(String phone) {
    final phoneRegex = RegExp(r'^\d{10,15}$');
    return phoneRegex.hasMatch(phone.replaceAll(RegExp(r'[\s\-\(\)]'), ''));
  }

  /// Validate password strength
  static String? validatePassword(String password) {
    if (password.length < 6) {
      return 'Password must be at least 6 characters long';
    }
    if (password.length < 8) {
      return 'For better security, use at least 8 characters';
    }
    
    // Optional: Check for stronger password requirements
    bool hasUppercase = password.contains(RegExp(r'[A-Z]'));
    bool hasLowercase = password.contains(RegExp(r'[a-z]'));
    bool hasDigit = password.contains(RegExp(r'\d'));
    
    if (!hasUppercase || !hasLowercase || !hasDigit) {
      return 'Password should contain uppercase, lowercase, and numbers';
    }
    
    return null; // Password is valid
  }

  /// Check if email already exists
  static Future<bool> emailExists(String email) async {
    try {
      final response = await _supabase
          .from('users')
          .select('id')
          .eq('email', email)
          .maybeSingle();

      return response != null;
    } catch (e) {
      // If error occurs, assume email doesn't exist to let auth handle it
      return false;
    }
  }

  /// Helper method to get user-friendly error messages
  static String _getAuthErrorMessage(String message) {
    if (message.contains('User already registered')) {
      return 'An account with this email already exists.';
    } else if (message.contains('Password should be at least')) {
      return 'Password must be at least 6 characters long.';
    } else if (message.contains('Unable to validate email address')) {
      return 'Please enter a valid email address.';
    } else if (message.contains('Email rate limit exceeded')) {
      return 'Too many registration attempts. Please try again later.';
    } else if (message.contains('Signup requires a valid password')) {
      return 'Please enter a valid password.';
    } else {
      return message;
    }
  }

  /// Register admin user (should only be called by existing admins)
  static Future<AuthResponse> registerAdmin({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
  }) async {
    try {
      // This would require service role key for production
      // For now, we'll create a regular user and manually update role
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'role': 'admin',
        },
      );

      if (response.user == null) {
        throw Exception('Admin registration failed.');
      }

      // Update users table
      await _supabase.from('users').update({
        'phone_number': phoneNumber,
        'role': 'admin',
      }).eq('id', response.user!.id);

      return response;
    } catch (e) {
      throw Exception('Failed to register admin: ${e.toString()}');
    }
  }

  /// Register driver user (should only be called by admins)
  static Future<AuthResponse> registerDriver({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'role': 'driver',
        },
      );

      if (response.user == null) {
        throw Exception('Driver registration failed.');
      }

      // Update users table
      await _supabase.from('users').update({
        'phone_number': phoneNumber,
        'role': 'driver',
      }).eq('id', response.user!.id);

      return response;
    } catch (e) {
      throw Exception('Failed to register driver: ${e.toString()}');
    }
  }
}