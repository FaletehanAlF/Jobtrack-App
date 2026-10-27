import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Error yang dilempar ketika server membalas dengan status gagal,
/// atau ketika perangkat tidak bisa terhubung ke server.
class ApiException implements Exception {
  /// Status HTTP dari server. Bernilai 0 bila gagal terhubung (mis. server mati).
  final int statusCode;

  /// Pesan yang aman ditampilkan ke pengguna.
  final String message;

  /// Pesan per field dari validasi backend, mis. {"email": "Email sudah terdaftar"}.
  final Map<String, dynamic>? errors;

  ApiException(this.statusCode, this.message, {this.errors});

  @override
  String toString() => message;
}

/// File biner dari endpoint unduhan, lengkap dengan nama dari server.
class ApiDownload {
  final Uint8List bytes;
  final String fileName;
  final String contentType;

  const ApiDownload({
    required this.bytes,
    required this.fileName,
    required this.contentType,
  });
}

/// Pembungkus semua komunikasi HTTP ke backend JobTrack.
class ApiService {
  // 10.0.2.2 adalah alamat komputer host dilihat dari Android Emulator.
  // Di iOS Simulator / Flutter Web gunakan http://localhost:3000/api.
  // Port 3000 dipilih karena port 6000 diblokir Chrome sebagai unsafe port.
  static const String _defaultBaseUrl = 'http://localhost:3000/api';

  // Kunci penyimpanan token di perangkat.
  static const String _tokenKey = 'auth_token';

  // Bisa diganti lewat constructor, misalnya untuk iOS Simulator atau pengujian.
  final String _baseUrl;

  ApiService({String? baseUrl}) : _baseUrl = baseUrl ?? _defaultBaseUrl;

  /// Menyimpan token JWT setelah login berhasil.
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  /// Mengambil token yang tersimpan. Mengembalikan null bila belum login.
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Menghapus token, dipakai saat pengguna keluar dari aplikasi.
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  /// Menyusun header request. Token hanya ditambahkan bila tersedia.
  Future<Map<String, String>> _headers() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final token = await getToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  /// Mengubah respons HTTP menjadi data Dart.
  ///
  /// Status 2xx dianggap berhasil dan isinya dikembalikan.
  /// Selain itu dilempar [ApiException] berisi pesan dari server.
  dynamic _handleResponse(http.Response response) {
    // Body bisa kosong (mis. 204 No Content) atau bukan JSON yang valid,
    // jadi decoding dilakukan hati-hati agar tidak melempar FormatException.
    dynamic body;
    final text = response.body.trim();

    if (text.isNotEmpty) {
      try {
        body = jsonDecode(text);
      } on FormatException {
        body = null;
      }
    }

    final isSuccess = response.statusCode >= 200 && response.statusCode < 300;

    if (isSuccess) {
      return body;
    }

    // Ambil pesan dari respons API bila bentuknya sesuai.
    var message = 'Terjadi kesalahan (${response.statusCode})';
    Map<String, dynamic>? errors;

    if (body is Map<String, dynamic>) {
      if (body['message'] is String) {
        message = body['message'] as String;
      }
      if (body['errors'] is Map) {
        errors = Map<String, dynamic>.from(body['errors'] as Map);
      }
    }

    throw ApiException(response.statusCode, message, errors: errors);
  }

  /// Membungkus pemanggilan HTTP: mengubah kegagalan jaringan menjadi
  /// [ApiException] agar pemanggil hanya perlu menangani satu jenis error.
  ///
  /// Timeout 15 detik ditambahkan sebagai pengaman: jika request menggantung
  /// (mis. port diblokir browser), UI tetap mendapat error, bukan loading
  /// tanpa akhir.
  Future<dynamic> _send(Future<http.Response> Function() request) async {
    try {
      final response = await request().timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException(
        0,
        'Tidak dapat terhubung ke server. Pastikan backend berjalan.',
      );
    } catch (_) {
      throw ApiException(
        0,
        'Tidak dapat terhubung ke server. Pastikan backend berjalan.',
      );
    }
  }

  /// GET, mis. get('/auth/me').
  ///
  /// [query] opsional; nilai null tidak ikut dikirim sehingga parameter yang
  /// tidak dipakai tidak muncul di URL.
  Future<dynamic> get(String endpoint, {Map<String, String>? query}) async {
    final headers = await _headers();
    final uri = Uri.parse('$_baseUrl$endpoint').replace(
      queryParameters: query == null || query.isEmpty ? null : query,
    );
    return _send(() => http.get(uri, headers: headers));
  }

  /// GET file biner, mis. laporan Excel.
  ///
  /// Nama file diambil dari header `Content-Disposition` yang diekspos CORS.
  /// [fallbackFileName] dipakai bila server/proxy tidak mengirim header itu.
  Future<ApiDownload> getFile(
    String endpoint, {
    String fallbackFileName = 'laporan.xlsx',
  }) async {
    final headers = await _headers();
    headers['Accept'] =
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

    try {
      final response = await http
          .get(Uri.parse('$_baseUrl$endpoint'), headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        _handleResponse(response);
        throw ApiException(
          response.statusCode,
          'Gagal mengunduh laporan (${response.statusCode}).',
        );
      }

      if (response.bodyBytes.isEmpty) {
        throw ApiException(0, 'File laporan kosong. Silakan coba lagi.');
      }

      return ApiDownload(
        bytes: response.bodyBytes,
        fileName: _fileNameFromHeaders(
          response.headers['content-disposition'],
          fallbackFileName,
        ),
        contentType:
            response.headers['content-type'] ??
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException(
        0,
        'Tidak dapat terhubung ke server. Pastikan backend berjalan.',
      );
    } catch (_) {
      throw ApiException(
        0,
        'Tidak dapat terhubung ke server. Pastikan backend berjalan.',
      );
    }
  }

  static String _fileNameFromHeaders(
    String? contentDisposition,
    String fallback,
  ) {
    if (contentDisposition == null || contentDisposition.isEmpty) {
      return fallback;
    }

    final encodedMatch = RegExp(
      r"filename\*\s*=\s*(?:UTF-8'')?([^;]+)",
      caseSensitive: false,
    ).firstMatch(contentDisposition);

    if (encodedMatch != null) {
      final encoded = encodedMatch.group(1)?.trim();
      if (encoded != null && encoded.isNotEmpty) {
        try {
          return _safeFileName(Uri.decodeComponent(encoded));
        } catch (_) {
          // Lanjut ke filename biasa bila encoding tidak valid.
        }
      }
    }

    final match = RegExp(
      r'filename\s*=\s*"([^"]+)"|filename\s*=\s*([^;]+)',
      caseSensitive: false,
    ).firstMatch(contentDisposition);
    final raw = (match?.group(1) ?? match?.group(2))?.trim();

    if (raw == null || raw.isEmpty) return fallback;

    return _safeFileName(raw);
  }

  static String _safeFileName(String value) {
    final sanitized = value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();

    return sanitized.isEmpty ? 'laporan.xlsx' : sanitized;
  }

  /// POST dengan body JSON, mis. post('/auth/login', {...}).
  Future<dynamic> post(String endpoint, Map<String, dynamic> data) async {
    final headers = await _headers();
    return _send(
      () => http.post(
        Uri.parse('$_baseUrl$endpoint'),
        headers: headers,
        body: jsonEncode(data),
      ),
    );
  }

  /// PUT dengan body JSON, mis. put('/jobs/1', {...}).
  Future<dynamic> put(String endpoint, Map<String, dynamic> data) async {
    final headers = await _headers();
    return _send(
      () => http.put(
        Uri.parse('$_baseUrl$endpoint'),
        headers: headers,
        body: jsonEncode(data),
      ),
    );
  }

  /// PATCH dengan body JSON, mis. patch('/recruiter/applicants/9/status').
  ///
  /// Dipakai untuk mengubah sebagian field saja (status lamaran), sesuai
  /// semantik PATCH di backend.
  Future<dynamic> patch(String endpoint, Map<String, dynamic> data) async {
    final headers = await _headers();
    return _send(
      () => http.patch(
        Uri.parse('$_baseUrl$endpoint'),
        headers: headers,
        body: jsonEncode(data),
      ),
    );
  }

  /// DELETE, mis. delete('/jobs/1').
  Future<dynamic> delete(String endpoint) async {
    final headers = await _headers();
    return _send(
      () => http.delete(Uri.parse('$_baseUrl$endpoint'), headers: headers),
    );
  }
}
