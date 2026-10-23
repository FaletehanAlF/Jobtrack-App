import '../models/user_model.dart';
import 'api_service.dart';

/// Layanan autentikasi: mendaftar, masuk, mengambil pengguna aktif, dan keluar.
///
/// Semua komunikasi HTTP ditangani [ApiService], jadi kelas ini hanya mengurus
/// alur autentikasi dan pemetaan data ke [UserModel].
class AuthService {
  final ApiService _api;

  /// [api] bisa diisi sendiri saat pengujian. Bila tidak, dibuat otomatis.
  AuthService({ApiService? api}) : _api = api ?? ApiService();

  /// Mendaftarkan akun baru lewat `POST /auth/register`.
  ///
  /// Respons backend berbentuk `{ "message": ..., "user": {...} }`.
  /// Perhatikan: register **tidak** mengembalikan token, jadi pengguna
  /// masih harus memanggil [login] setelah berhasil mendaftar.
  ///
  /// Backend mewajibkan `confirmPassword`. Bila [confirmPassword] tidak diisi,
  /// nilainya disamakan dengan [password] sehingga pemanggil cukup mengirim
  /// tiga argumen. Bila form punya kolom konfirmasi, isi [confirmPassword]
  /// agar backend benar-benar memeriksa kecocokannya.
  Future<UserModel> register({
    required String username,
    required String email,
    required String password,
    String? confirmPassword,
  }) async {
    final data = await _api.post('/auth/register', {
      'username': username,
      'email': email,
      'password': password,
      'confirmPassword': confirmPassword ?? password,
    });

    return _readUser(data);
  }

  /// Masuk lewat `POST /auth/login`.
  ///
  /// Respons backend berbentuk `{ "message": ..., "token": ..., "user": {...} }`.
  /// Token disimpan lewat [ApiService.saveToken] agar request berikutnya
  /// otomatis membawa header `Authorization: Bearer <token>`.
  ///
  /// Password tidak pernah disimpan, hanya dikirim sekali saat login.
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final data = await _api.post('/auth/login', {
      'email': email,
      'password': password,
    });

    final body = _readBody(data);

    final token = body['token'];
    if (token is! String || token.isEmpty) {
      throw ApiException(0, 'Respons login tidak berisi token.');
    }

    // Simpan token lebih dulu supaya pemanggil tidak perlu melakukannya lagi.
    await _api.saveToken(token);

    return _readUser(data);
  }

  /// Mengambil pengguna yang sedang login lewat `GET /auth/me`.
  ///
  /// Mengembalikan `null` bila belum ada token atau sesinya sudah tidak valid
  /// (mis. token kedaluwarsa). Pada kasus itu token yang tersimpan ikut
  /// dihapus, sehingga aplikasi tidak terus mencoba dengan token mati.
  ///
  /// Error lain — misalnya server tidak bisa dihubungi — tetap dilempar
  /// sebagai [ApiException] agar bisa dibedakan dari "belum login".
  Future<UserModel?> getCurrentUser() async {
    final token = await _api.getToken();
    if (token == null || token.isEmpty) {
      return null;
    }

    try {
      final data = await _api.get('/auth/me');
      return _readUser(data);
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        // Token tidak berlaku lagi: bersihkan supaya tidak dipakai terus.
        await _api.logout();
        return null;
      }
      rethrow;
    }
  }

  /// Keluar dari aplikasi dengan menghapus token di perangkat.
  ///
  /// Ini hanya mengakhiri sesi di sisi aplikasi. Akun pengguna di database
  /// tidak dihapus dan tidak ada request ke server.
  Future<void> logout() async {
    await _api.logout();
  }

  /// Memastikan respons berbentuk objek JSON, bukan null atau tipe lain.
  Map<String, dynamic> _readBody(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }

    throw ApiException(0, 'Respons server tidak sesuai format yang diharapkan.');
  }

  /// Mengambil objek `user` dari respons lalu mengubahnya menjadi [UserModel].
  UserModel _readUser(dynamic data) {
    final body = _readBody(data);
    final user = body['user'];

    if (user is! Map<String, dynamic>) {
      throw ApiException(0, 'Respons server tidak berisi data pengguna.');
    }

    return UserModel.fromJson(user);
  }
}
