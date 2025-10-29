import 'package:supabase_flutter/supabase_flutter.dart';

class NFCCardService {
  static final _supabase = Supabase.instance.client;

  /// Fetch all NFC cards with owner information
  static Future<List<Map<String, dynamic>>> getAllCards() async {
    try {
      final response = await _supabase
          .from('nfc_cards')
          .select('*, users!nfc_cards_owner_id_fkey(full_name, email)')
          .order('created_at', ascending: false);

      // Transform the response to include owner_name at root level
      return List<Map<String, dynamic>>.from(response.map((card) {
        final users = card['users'];
        return {
          ...card,
          'owner_name': users != null ? users['full_name'] : null,
          'owner_email': users != null ? users['email'] : null,
        };
      }));
    } catch (e) {
      print('Error fetching NFC cards: $e');
      rethrow;
    }
  }

  /// Create a new NFC card
  static Future<Map<String, dynamic>> createCard({
    required String cardNumber,
    required String cardType,
    String? ownerId,
    required double initialBalance,
    required String discountType,
  }) async {
    try {
      // Check if card number already exists
      final existing = await _supabase
          .from('nfc_cards')
          .select('id')
          .eq('card_number', cardNumber)
          .maybeSingle();

      if (existing != null) {
        throw Exception('Card number already exists');
      }

      // Create the card
      final response = await _supabase.from('nfc_cards').insert({
        'card_number': cardNumber,
        'card_type': cardType,
        'owner_id': ownerId,
        'balance': initialBalance,
        'discount_type': discountType,
        'is_active': true,
        'is_blocked': false,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).select().single();

      return response;
    } catch (e) {
      print('Error creating NFC card: $e');
      rethrow;
    }
  }

  /// Update card status (activate/deactivate)
  static Future<void> updateCardStatus(String cardId, bool isActive) async {
    try {
      await _supabase.from('nfc_cards').update({
        'is_active': isActive,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', cardId);
    } catch (e) {
      print('Error updating card status: $e');
      rethrow;
    }
  }

  /// Delete a card
  static Future<void> deleteCard(String cardId) async {
    try {
      await _supabase.from('nfc_cards').delete().eq('id', cardId);
    } catch (e) {
      print('Error deleting card: $e');
      rethrow;
    }
  }

  /// Update card balance
  static Future<void> updateCardBalance(String cardId, double newBalance) async {
    try {
      await _supabase.from('nfc_cards').update({
        'balance': newBalance,
        'last_used_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', cardId);
    } catch (e) {
      print('Error updating card balance: $e');
      rethrow;
    }
  }

  /// Block/Unblock a card
  static Future<void> toggleBlockStatus(String cardId, bool isBlocked) async {
    try {
      await _supabase.from('nfc_cards').update({
        'is_blocked': isBlocked,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', cardId);
    } catch (e) {
      print('Error toggling block status: $e');
      rethrow;
    }
  }

  /// Assign card to a user
  static Future<void> assignCardToUser(String cardId, String userId) async {
    try {
      await _supabase.from('nfc_cards').update({
        'owner_id': userId,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', cardId);
    } catch (e) {
      print('Error assigning card to user: $e');
      rethrow;
    }
  }

  /// Get card by card number
  static Future<Map<String, dynamic>?> getCardByNumber(String cardNumber) async {
    try {
      final response = await _supabase
          .from('nfc_cards')
          .select('*, users!nfc_cards_owner_id_fkey(full_name, email)')
          .eq('card_number', cardNumber)
          .maybeSingle();

      if (response == null) return null;

      final users = response['users'];
      return {
        ...response,
        'owner_name': users != null ? users['full_name'] : null,
        'owner_email': users != null ? users['email'] : null,
      };
    } catch (e) {
      print('Error fetching card by number: $e');
      rethrow;
    }
  }

  /// Get cards statistics
  static Future<Map<String, dynamic>> getCardStatistics() async {
    try {
      final allCards = await _supabase
          .from('nfc_cards')
          .select('card_type, is_active, balance');

      int totalCards = allCards.length;
      int activeCards = allCards.where((c) => c['is_active'] == true).length;
      int reloadableCards = allCards.where((c) => c['card_type'] == 'reloadable').length;
      int singleUseCards = allCards.where((c) => c['card_type'] == 'single_use').length;
      
      double totalBalance = 0;
      for (var card in allCards) {
        totalBalance += (card['balance'] ?? 0.0).toDouble();
      }

      return {
        'total': totalCards,
        'active': activeCards,
        'reloadable': reloadableCards,
        'single_use': singleUseCards,
        'total_balance': totalBalance,
      };
    } catch (e) {
      print('Error fetching card statistics: $e');
      return {
        'total': 0,
        'active': 0,
        'reloadable': 0,
        'single_use': 0,
        'total_balance': 0.0,
      };
    }
  }

  /// Get transaction history for a card
  static Future<List<Map<String, dynamic>>> getCardTransactions(String cardId) async {
    try {
      final response = await _supabase
          .from('transactions')
          .select('*')
          .eq('nfc_card_id', cardId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching card transactions: $e');
      rethrow;
    }
  }
}