import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class BalanceCard extends StatefulWidget {
  const BalanceCard({super.key});
  @override
  State<BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<BalanceCard> {
  int balance = 0;
  bool loading = true;
  final api = ApiService();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  Future<void> _load() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.user == null) { setState(() { loading = false;}); return; }
    try {
      final w = await api.getWallet(auth.user!.id);
      setState(() {
        balance = (w['balance'] ?? 0) as int;
        loading = false;
      });
    } catch (e) {
      setState(() { loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: loading ? const Center(child: CircularProgressIndicator()) :
        Row(children: [
          Icon(Icons.account_balance_wallet, size: 40, color: Theme.of(context).primaryColor),
          const SizedBox(width: 16),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Wallet Balance', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 6),
            Text('₱ ${(balance/100).toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ])
        ]),
      ),
    );
  }
}
