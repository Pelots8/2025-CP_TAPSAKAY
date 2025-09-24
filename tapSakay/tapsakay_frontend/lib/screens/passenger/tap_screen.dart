import 'package:flutter/material.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import '../services/api_service.dart';

class TapScreen extends StatefulWidget {
  const TapScreen({super.key});
  @override
  State<TapScreen> createState() => _TapScreenState();
}

class _TapScreenState extends State<TapScreen> {
  String status = 'Ready';
  final api = ApiService();

  Future<void> startTap() async {
    setState(() { status = 'Scanning NFC...'; });
    try {
      final tag = await FlutterNfcKit.poll(timeout: const Duration(seconds: 10));
      final id = tag.id;
      await FlutterNfcKit.finish();
      final resp = await api.tapCard(id, 'android_device_001', null, null);
      if (resp['success'] == true) {
        setState(() { status = 'Tap success!'; });
        // you can display new balance: resp['wallet']['balance']
      } else {
        setState(() { status = 'Tap failed: ${resp['reason'] ?? resp['error'] ?? 'unknown'}'; });
      }
    } catch (e) {
      setState(() { status = 'NFC error: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tap Card')),
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(status),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: startTap, child: const Text('Start NFC')),
        ]),
      ),
    );
  }
}
