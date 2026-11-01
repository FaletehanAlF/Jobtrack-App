class UserModel {
  final int id;
  final String username;
  final String email;
  final String role;

  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: (json['id'] as num).toInt(),
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? '',
      createdAt: _parseDate(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'role': role,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  static DateTime _parseDate(dynamic value) {
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed.toLocal();
    }

    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        value.toInt(),
        isUtc: true,
      ).toLocal();
    }

    return DateTime.now();
  }
}
