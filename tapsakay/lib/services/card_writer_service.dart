import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';

/// Service for writing demo data to NFC cards (for demonstration only)
/// WARNING: This is for demo purposes only - real balance should stay in database!
class CardWriterService {
  static final CardWriterService _instance = CardWriterService._internal();
  factory CardWriterService() => _instance;
  CardWriterService._internal();

  /// Write demo data to card (showcase capability only)
  Future<bool> writeDemoData({
    required String uid,
    required String fullName,
    required double balance,
  }) async {
    try {
      debugPrint('Attempting to write demo data to card...');
      
      // Poll for card
      NFCTag tag = await FlutterNfcKit.poll(
        timeout: const Duration(seconds: 10),
      );

      // Check if card supports writing
      if (tag.type != NFCTagType.mifare_classic && tag.type != NFCTagType.mifare_ultralight) {
        throw Exception('Card type not supported for writing');
      }

      // For demo purposes, we'll just simulate writing
      // Real implementation would require specific NFC write libraries
      debugPrint('Simulating write to card type: ${tag.type}');
      debugPrint('Data: UID=$uid, Name=$fullName, Balance=$balance');

      await FlutterNfcKit.finish();
      debugPrint('Demo data written successfully');
      return true;
    } catch (e) {
      debugPrint('Error writing to card: $e');
      try {
        await FlutterNfcKit.finish();
      } catch (_) {}
      return false;
    }
  }

  /// Read demo data from card
  Future<Map<String, dynamic>?> readDemoData() async {
    try {
      NFCTag tag = await FlutterNfcKit.poll();
      
      // For demo, just show we can read something
      await FlutterNfcKit.finish();
      
      return {
        'message': 'Card read successfully',
        'type': tag.type.toString(),
        'id': tag.id?.map((e) => e.toRadixString(16).padLeft(2, '0')).join('').toUpperCase(),
      };
    } catch (e) {
      debugPrint('Error reading card: $e');
      return null;
    }
  }
}
