class UserModel {
  final String id;
  final String name;
  final String role;
  final String? email;
  final int? walletBalance;

  UserModel({required this.id, required this.name, required this.role, this.email, this.walletBalance});

  factory UserModel.fromJson(Map<String, dynamic> j) {
    return UserModel(
      id: j['_id'] ?? j['id'],
      name: j['name'] ?? '',
      role: j['role'] ?? 'passenger',
      email: j['email'],
      walletBalance: j['walletBalance'] != null ? j['walletBalance'] as int : null
    );
  }
}
