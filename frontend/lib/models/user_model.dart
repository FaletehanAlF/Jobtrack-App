import 'package:flutter/foundation.dart';

/// Model pengguna yang merepresentasikan objek `user` dari respons API JobTrack.
///
/// Bentuk JSON dari backend (register, login, dan GET /auth/me):
/// {
///   "id": 1,
///   "username": "model",
///   "email": "model@test.local",
///   "role": "jobseeker",
///   "created_at": "2026-10-20T14:45:29.000Z"
/// }
///
/// Catatan: backend tidak pernah mengirim `password` maupun `password_hash`,
/// dan model ini juga sengaja tidak menyimpannya.
class UserModel {
  final int id;
  final String username;
  final String email;
  final String role;

  /// Waktu pembuatan akun.
  ///
  /// Disimpan sebagai waktu lokal perangkat supaya langsung bisa ditampilkan.
  /// Backend mengirimnya dalam UTC (akhiran "Z"), jadi dikonversi dengan
  /// [toLocal] setelah di-parse.
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    required this.createdAt,
  });

  /// Membuat [UserModel] dari satu objek JSON.
  ///
  /// Melempar [FormatException] bila `created_at` tidak bisa di-parse,
  /// supaya data yang rusak tidak diam-diam menjadi tanggal yang salah.
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: (json['id'] as num).toInt(),
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? '',
      createdAt: _parseDate(json['created_at']),
    );
  }

  /// Mengubah model kembali menjadi JSON.
  ///
  /// Berguna untuk menyimpan data pengguna di perangkat (mis. SharedPreferences)
  /// tanpa perlu memanggil API lagi. Tidak ada field password di sini.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'role': role,
      // Dikembalikan dalam UTC agar formatnya sama dengan yang dikirim backend.
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  /// Mem-parse `created_at` dari respons API.
  ///
  /// Backend mengirim string ISO-8601 (mis. "2026-10-20T14:45:29.000Z"),
  /// tetapi beberapa kondisi bisa membuat nilainya bukan string:
  /// - `null` bila kolomnya kosong,
  /// - angka bila driver database mengubahnya (mis. epoch milidetik).
  static DateTime _parseDate(dynamic value) {
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed.toLocal();
    }

    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true)
          .toLocal();
    }

    // Nilai yang tidak dikenali dianggap waktu sekarang agar aplikasi tidak
    // crash, tetapi tetap ditandai lewat debugPrint saat pengembangan.
    assert(() {
      debugPrint('[UserModel] created_at tidak dikenali: $value');
      return true;
    }());

    return DateTime.now();
  }
}
