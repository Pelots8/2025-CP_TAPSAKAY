import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final loginCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          // TODO: Replace below with your TapSakay logo from ZIP
          const FlutterLogo(size: 100),
          const SizedBox(height: 20),
          TextField(controller: loginCtrl, decoration: const InputDecoration(labelText: 'Email or Phone')),
          const SizedBox(height: 12),
          TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
          const SizedBox(height: 18),
          auth.loading ? const CircularProgressIndicator() :
          ElevatedButton(
            onPressed: () => auth.login(loginCtrl.text, passCtrl.text),
            child: const Text('Login')
          )
        ]),
      ),
    );
  }
}
