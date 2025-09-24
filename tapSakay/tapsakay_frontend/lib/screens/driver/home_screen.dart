import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/socket_service.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});
  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  final SocketService socket = SocketService();
  List<dynamic> taps = [];

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    await socket.connect();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.user != null) {
      socket.joinRoom('driver:${auth.user!.id}');
    } else {
      socket.joinRoom('driver:all');
    }
    socket.on('tap_recorded', (payload) {
      setState(() {
        taps.insert(0, payload);
      });
    });
  }

  @override
  void dispose() {
    socket.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TapSakay - Driver')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(children: [
          const Text('Recent Taps', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(itemCount: taps.length, itemBuilder: (ctx, i) {
              final t = taps[i];
              final id = t['cardId'] ?? t['tap']?['cardId'] ?? '-';
              final res = t['result'] ?? t['tap']?['result'] ?? '-';
              final ts = t['timestamp'] ?? t['tap']?['timestamp'] ?? DateTime.now().toIso8601String();
              return ListTile(title: Text('$id — $res'), subtitle: Text(ts.toString()));
            }),
          )
        ]),
      ),
    );
  }
}
