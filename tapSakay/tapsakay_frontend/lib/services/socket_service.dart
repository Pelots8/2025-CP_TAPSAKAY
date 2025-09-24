import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../models/user.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? user;
  bool loading = false;
  final storage = const FlutterSecureStorage();
  final api = ApiService();
  final socket = SocketService();

  bool get isLoggedIn => user != null;

  Future<void> login(String login, String password) async {
    loading = true; notifyListeners();
    final res = await api.login(login, password);
    if (res['token'] != null) {
      await storage.write(key: 'jwt', value: res['token']);
    }
    if (res['user'] != null) {
      user = UserModel.fromJson(res['user']);
      // connect socket and join room
      await socket.connect();
      socket.joinRoom('user:${user!.id}');
      // listen to realtime events
      socket.on('wallet_updated', (p) {
        if (p['ownerId'] == user!.id) {
          // update wallet if present
          notifyListeners();
        }
      });
      socket.on('user_updated', (p) {
        if (p['userId'] == user!.id) {
          user = UserModel.fromJson(p['user']);
          notifyListeners();
        }
      });
    }
    loading = false; notifyListeners();
  }

  Future<void> logout() async {
    user = null;
    await storage.delete(key: 'jwt');
    socket.disconnect();
    notifyListeners();
  }
}
