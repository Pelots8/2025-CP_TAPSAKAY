import 'package:supabase_flutter/supabase_flutter.dart';

class LoginApi {
  static final _supabase = Supabase.instance.client;

  /// Login user with email and password
  static Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Login failed. Please check your credentials.');
      }

      return response;
    } on AuthException catch (e) {
      throw Exception(_getAuthErrorMessage(e.message));
    } catch (e) {
      throw Exception('An unexpected error occurred. Please try again.');
    }
  }

  /// Get current user
  static User? getCurrentUser() {
    return _supabase.auth.currentUser;
  }

  /// Check if user is logged in
  static bool isLoggedIn() {
    return _supabase.auth.currentUser != null;
  }

  /// Get user role from database
/// Get user role from database
static Future<String?> getUserRole() async {
  try {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      print('No current user ID');
      return null;
    }

    print('Fetching role for user: $userId');

    // Use the database function instead
    final response = await _supabase
        .rpc('get_user_role', params: {'user_id': userId});

    print('Role response: $response');

    return response as String?;
  } catch (e) {
    print('Error fetching user role: $e');
    // Fallback to direct query
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;
      
      final response = await _supabase
          .from('users')
          .select('role')
          .eq('id', userId)
          .single();
      
      return response['role'] as String?;
    } catch (e2) {
      print('Fallback query also failed: $e2');
      return null;
    }
  }
}

  /// Get user profile from database
  static Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await _supabase
          .from('users')
          .select('*')
          .eq('id', userId)
          .single();

      return response;
    } catch (e) {
      throw Exception('Failed to fetch user profile: ${e.toString()}');
    }
  }

  /// Logout user
  static Future<void> logout() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      throw Exception('Failed to logout: ${e.toString()}');
    }
  }

  /// Helper method to get user-friendly error messages
  static String _getAuthErrorMessage(String message) {
    if (message.contains('Invalid login credentials')) {
      return 'Invalid email or password. Please try again.';
    } else if (message.contains('Email not confirmed')) {
      return 'Please verify your email address before logging in.';
    } else if (message.contains('User not found')) {
      return 'No account found with this email address.';
    } else if (message.contains('Too many requests')) {
      return 'Too many login attempts. Please try again later.';
    } else {
      return message;
    }
  }

  /// Listen to auth state changes
  static Stream<AuthState> get authStateChanges {
    return _supabase.auth.onAuthStateChange;
  }
}