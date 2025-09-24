import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/balance_card.dart';
import 'tap_screen.dart';

class PassengerHomeScreen extends StatefulWidget {
  const PassengerHomeScreen({super.key});
  @override
  State<PassengerHomeScreen> createState() => _PassengerHomeScreenState();
}

class _PassengerHomeScreenState extends State<PassengerHomeScreen> {
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('TapSakay - Passenger')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BalanceCard(),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TapScreen())), child: const Text('Tap Card')),
          const SizedBox(height: 12),
          ListTile(title: const Text('Profile'), subtitle: Text(auth.user?.name ?? '-')),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
