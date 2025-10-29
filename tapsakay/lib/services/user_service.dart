import 'package:supabase_flutter/supabase_flutter.dart';

class UserService {
  static final _supabase = Supabase.instance.client;

  /// Fetch all users with optional filtering
  static Future<List<Map<String, dynamic>>> getUsers({
    String? searchQuery,
    String? roleFilter,
  }) async {
    try {
      dynamic query = _supabase.from('users').select('*');

      // Apply role filter
      if (roleFilter != null && roleFilter != 'all') {
        query = query.eq('role', roleFilter);
      }

      // Apply search filter
      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.or(
          'full_name.ilike.%$searchQuery%,'
          'email.ilike.%$searchQuery%,'
          'phone_number.ilike.%$searchQuery%',
        );
      }

      // Apply order after filters
      query = query.order('created_at', ascending: false);

      final response = await query;
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching users: $e');
      rethrow;
    }
  }

  /// Get user's NFC cards
  static Future<List<Map<String, dynamic>>> getUserNFCCards(String userId) async {
    try {
      final response = await _supabase
          .from('nfc_cards')
          .select('*')
          .eq('owner_id', userId)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching user NFC cards: $e');
      rethrow;
    }
  }

  /// Top up an NFC card
  static Future<void> topUpCard(String cardId, double amount) async {
    try {
      // Get current admin user
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('No authenticated user');
      }

      // Get current card details
      final cardResponse = await _supabase
          .from('nfc_cards')
          .select('balance, owner_id')
          .eq('id', cardId)
          .single();

      final currentBalance = (cardResponse['balance'] ?? 0.0).toDouble();
      final ownerId = cardResponse['owner_id'];
      final newBalance = currentBalance + amount;

      // Update card balance
      await _supabase.from('nfc_cards').update({
        'balance': newBalance,
        'last_used_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', cardId);

      // Create transaction record for the top-up
      await _supabase.from('transactions').insert({
        'passenger_id': ownerId,
        'nfc_card_id': cardId,
        'transaction_type': 'reload',
        'amount': amount,
        'balance_before': currentBalance,
        'balance_after': newBalance,
        'discount_applied': 0.0,
        'discount_type': 'none',
        'status': 'success',
        'admin_id': currentUser.id,
        'location_name': 'Admin Top-up',
        'created_at': DateTime.now().toIso8601String(),
      });

      print('Card topped up successfully: $cardId, Amount: $amount');
    } catch (e) {
      print('Error topping up card: $e');
      rethrow;
    }
  }

  /// Get user statistics
  static Future<Map<String, dynamic>> getUserStatistics() async {
    try {
      final allUsers = await _supabase.from('users').select('role, is_active');

      int totalUsers = allUsers.length;
      int activeUsers = allUsers.where((u) => u['is_active'] == true).length;
      int admins = allUsers.where((u) => u['role'] == 'admin').length;
      int drivers = allUsers.where((u) => u['role'] == 'driver').length;
      int passengers = allUsers.where((u) => u['role'] == 'passenger').length;

      return {
        'total': totalUsers,
        'active': activeUsers,
        'admins': admins,
        'drivers': drivers,
        'passengers': passengers,
      };
    } catch (e) {
      print('Error fetching user statistics: $e');
      return {
        'total': 0,
        'active': 0,
        'admins': 0,
        'drivers': 0,
        'passengers': 0,
      };
    }
  }

  /// Update user status (activate/deactivate)
  static Future<void> updateUserStatus(String userId, bool isActive) async {
    try {
      final response = await _supabase
          .from('users')
          .update({
            'is_active': isActive, 
            'updated_at': DateTime.now().toIso8601String()
          })
          .eq('id', userId)
          .select();
      
      if (response.isEmpty) {
        throw Exception('Failed to update user status');
      }
    } catch (e) {
      print('Error updating user status: $e');
      rethrow;
    }
  }

  /// Delete a user (soft delete - marks as inactive and deleted)
  static Future<void> deleteUser(String userId) async {
    try {
      await _supabase.from('users').update({
        'is_active': false,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
    } catch (e) {
      print('Error deleting user: $e');
      rethrow;
    }
  }

  /// Update user role
  static Future<void> updateUserRole(String userId, String newRole) async {
    try {
      await _supabase
          .from('users')
          .update({'role': newRole, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', userId);
    } catch (e) {
      print('Error updating user role: $e');
      rethrow;
    }
  }

  /// Update user profile information
  static Future<void> updateUserProfile({
    required String userId,
    required String fullName,
    required String email,
    String? phoneNumber,
  }) async {
    try {
      await _supabase.from('users').update({
        'full_name': fullName,
        'email': email,
        'phone_number': phoneNumber,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
    } catch (e) {
      print('Error updating user profile: $e');
      rethrow;
    }
  }
}