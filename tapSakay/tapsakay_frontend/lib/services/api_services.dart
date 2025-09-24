import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  final Dio dio;
  final FlutterSecureStorage storage = const FlutterSecureStorage();

  ApiService({String? baseUrl}) : dio = Dio(BaseOptions(baseUrl: baseUrl ?? 'http://10.0.2.2:3000/api')) {
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) async {
      final token = await storage.read(key: 'jwt');
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
      return handler.next(options);
    }));
  }

  Future<Map<String, dynamic>> login(String login, String password) async {
    final r = await dio.post('/auth/login', data: {'login': login, 'password': password});
    return Map<String, dynamic>.from(r.data);
  }

  Future<Map<String, dynamic>> getWallet(String ownerId) async {
    final r = await dio.get('/wallets/owner/$ownerId');
    return Map<String, dynamic>.from(r.data);
  }

  Future<Map<String, dynamic>> tapCard(String cardId, String deviceId, double? lat, double? lng) async {
    final r = await dio.post('/taps', data: {'cardId': cardId, 'deviceId': deviceId, 'lat': lat, 'lng': lng});
    return Map<String, dynamic>.from(r.data);
  }

  Future<Map<String, dynamic>> topUp(String ownerId, int amount) async {
    final r = await dio.post('/wallets/topup', data: {'ownerId': ownerId, 'amount': amount});
    return Map<String, dynamic>.from(r.data);
  }
}
