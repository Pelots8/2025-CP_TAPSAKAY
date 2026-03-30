import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'hardware_service.dart';

class HardwareNFCService {
  static final HardwareNFCService _instance = HardwareNFCService._internal();
  factory HardwareNFCService() => _instance;
  HardwareNFCService._internal();

  final HardwareService _hardwareService = HardwareService();
  Timer? _pollingTimer;
  StreamController<String>? _cardStreamController;
  String? _lastDetectedUID;
  bool _isPolling = false;

  Stream<String> get cardStream =>
      _cardStreamController?.stream ?? const Stream.empty();

  String? get lastDetectedUID => _lastDetectedUID;

  /// Start polling for NFC cards from PN532 hardware module
  Future<void> startPolling() async {
    if (_isPolling) return;

    _cardStreamController = StreamController<String>.broadcast();
    _isPolling = true;

    // Poll every 500ms for responsive card detection
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      await _checkForCard();
    });

    debugPrint('Hardware NFC polling started');
  }

  /// Stop polling for NFC cards
  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isPolling = false;
    debugPrint('Hardware NFC polling stopped');
  }

  /// Check for NFC card on PN532 module
  Future<void> _checkForCard() async {
    final ip = _hardwareService.connectedIP;
    if (ip == null) return;

    try {
      final response = await http
          .get(Uri.parse('http://$ip/nfc/read'))
          .timeout(const Duration(milliseconds: 400));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['detected'] == true && data['uid'] != null) {
          final uid = data['uid'].toString().toUpperCase();
          if (uid.isNotEmpty && uid != _lastDetectedUID) {
            _lastDetectedUID = uid;
            _cardStreamController?.add(uid);
            debugPrint('Hardware NFC card detected: $uid');
          }
        }
      }
    } catch (e) {
      // Ignore timeout errors - normal when no card present
    }
  }

  /// Read a single card (waits for a FRESH card detection)
  Future<String?> readCard({Duration timeout = const Duration(seconds: 10)}) async {
    final ip = _hardwareService.connectedIP;
    if (ip == null) {
      // Try to discover hardware module
      await _hardwareService.autoDiscover();
      if (_hardwareService.connectedIP == null) {
        debugPrint('Hardware module not connected');
        return null;
      }
    }

    final startTime = DateTime.now();
    _lastDetectedUID = null; // Reset last detected
    
    // First, clear any stale card data by making an initial request
    // This triggers the ESP8266 to clear the lastScannedUID
    try {
      await http
          .get(Uri.parse('http://${_hardwareService.connectedIP}/nfc/read'))
          .timeout(const Duration(milliseconds: 500));
    } catch (e) {
      // Ignore errors on initial clear
    }
    
    debugPrint('Waiting for NFC card tap...');

    while (DateTime.now().difference(startTime) < timeout) {
      try {
        final response = await http
            .get(Uri.parse('http://${_hardwareService.connectedIP}/nfc/read'))
            .timeout(const Duration(milliseconds: 500));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['detected'] == true && data['uid'] != null) {
            final uid = data['uid'].toString().toUpperCase();
            if (uid.isNotEmpty) {
              _lastDetectedUID = uid;
              debugPrint('Hardware NFC card read: $uid');
              return uid;
            }
          }
        }
      } catch (e) {
        // Continue polling
      }
      await Future.delayed(const Duration(milliseconds: 300));
    }

    debugPrint('Hardware NFC read timeout - no card detected');
    return null;
  }

  /// Get card info from database by UID
  Future<Map<String, dynamic>?> getCardInfo(String? uid) async {
    if (uid == null || uid.isEmpty) return null;

    try {
      // First try to find by UID
      var response = await Supabase.instance.client
          .from('nfc_cards')
          .select('*, users!owner_id(full_name, email)')
          .eq('uid', uid)
          .eq('is_active', true)
          .maybeSingle();

      // If not found by UID, try card_number
      if (response == null) {
        response = await Supabase.instance.client
            .from('nfc_cards')
            .select('*, users!owner_id(full_name, email)')
            .eq('card_number', uid)
            .eq('is_active', true)
            .maybeSingle();
      }

      return response;
    } catch (e) {
      debugPrint('Error getting card info: $e');
      return null;
    }
  }

  /// Get NFC hardware status
  Future<Map<String, dynamic>?> getStatus() async {
    final ip = _hardwareService.connectedIP;
    if (ip == null) return null;

    try {
      final response = await http
          .get(Uri.parse('http://$ip/nfc'))
          .timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint('Error getting NFC status: $e');
    }
    return null;
  }

  /// Check if hardware NFC is available
  Future<bool> isAvailable() async {
    final status = await getStatus();
    return status != null && status['ready'] == true;
  }

  void dispose() {
    stopPolling();
    _cardStreamController?.close();
  }
}
