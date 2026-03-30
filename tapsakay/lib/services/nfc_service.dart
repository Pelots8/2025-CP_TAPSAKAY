import 'package:flutter/material.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NFCService {
  static final NFCService _instance = NFCService._internal();
  factory NFCService() => _instance;
  NFCService._internal();

  Future<String?> readCard() async {
    try {
      NFCTag tag = await FlutterNfcKit.poll(
        timeout: const Duration(seconds: 10),
      );
      String? uid = tag.id?.toUpperCase();
      await FlutterNfcKit.finish();
      return uid;
    } catch (e) {
      debugPrint('Error reading NFC card');
      try { await FlutterNfcKit.finish(); } catch (_) {}
      return null;
    }
  }

  Future<Map<String, dynamic>?> getCardInfo(String? identifier) async {
    if (identifier == null) return null;
    try {
      var response = await Supabase.instance.client
          .from('nfc_cards')
          .select('*, users!owner_id(full_name, email)')
          .eq('uid', identifier)
          .eq('is_active', true)
          .maybeSingle();
      if (response == null) {
        response = await Supabase.instance.client
            .from('nfc_cards')
            .select('*, users!owner_id(full_name, email)')
            .eq('card_number', identifier)
            .eq('is_active', true)
            .maybeSingle();
      }
      return response;
    } catch (e) {
      debugPrint('Error getting card info');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getCardInfoById(String cardId) async {
    try {
      final response = await Supabase.instance.client
          .from('nfc_cards')
          .select('*, users!owner_id(full_name, email)')
          .eq('id', cardId)
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('Error getting card info by ID');
      return null;
    }
  }

  Future<bool> processPayment({
    required String cardId,
    required double amount,
    required String tripId,
    required String passengerId,
  }) async {
    try {
      final card = await Supabase.instance.client
          .from('nfc_cards')
          .select('balance')
          .eq('id', cardId)
          .single();
      final balance = card['balance'] ?? 0.0;
      if (balance < amount) throw Exception('Insufficient balance');
      await Supabase.instance.client
          .from('nfc_cards')
          .update({'balance': balance - amount})
          .eq('id', cardId);
      await Supabase.instance.client.from('transactions').insert({
        'nfc_card_id': cardId,
        'trip_id': tripId,
        'passenger_id': passengerId,
        'amount': amount,
        'type': 'fare',
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('Error processing payment');
      return false;
    }
  }

  Future<bool> addBalance({required String cardId, required double amount}) async {
    try {
      await Supabase.instance.client.rpc('add_balance', params: {
        'card_id': cardId,
        'amount': amount,
      });
      return true;
    } catch (e) {
      debugPrint('Error adding balance');
      return false;
    }
  }

  Future<bool> registerCard({
    required String uid,
    required String cardNumber,
    required String ownerId,
    required double initialBalance,
  }) async {
    try {
      await Supabase.instance.client.from('nfc_cards').insert({
        'uid': uid,
        'card_number': cardNumber,
        'owner_id': ownerId,
        'balance': initialBalance,
        'card_type': 'reloadable', // Use valid card_type value
        'is_active': true,
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('Error registering card: $e');
      print('Error registering card: $e'); // Add this for console visibility
      rethrow; // Re-throw to show actual error in UI
    }
  }
}
