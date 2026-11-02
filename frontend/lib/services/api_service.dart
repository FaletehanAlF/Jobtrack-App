import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  final int statusCode;

  final String message;

  final Map<String, dynamic>? errors;

  ApiException(this.statusCode, this.message, {this.errors});

  @override
  String toString() => message;
}

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

class ApiService {
  static const String _defaultBaseUrl = 'http://localhost:3000/api';

  static const String _tokenKey = 'auth_token';

  final String _baseUrl;

  ApiService({String? baseUrl}) : _baseUrl = baseUrl ?? _defaultBaseUrl;

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

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

  dynamic _handleResponse(http.Response response) {
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

  Future<dynamic> get(String endpoint, {Map<String, String>? query}) async {
    final headers = await _headers();
    final uri = Uri.parse(
      '$_baseUrl$endpoint',
    ).replace(queryParameters: query == null || query.isEmpty ? null : query);
    return _send(() => http.get(uri, headers: headers));
  }

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
        } catch (_) {}
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

  /// Mengirim multipart/form-data. Content-Type tidak diisi manual supaya
  /// package:http menambahkan boundary yang benar.
  Future<dynamic> postMultipart(
    String endpoint, {
    Map<String, String> fields = const {},
    String? fileField,
    Uint8List? fileBytes,
    String? fileName,
  }) async {
    final headers = await _headers();
    headers.remove('Content-Type');

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl$endpoint'),
    )..headers.addAll(headers);

    request.fields.addAll(fields);

    if (fileField != null && fileBytes != null && fileName != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          fileField,
          fileBytes,
          filename: fileName,
        ),
      );
    }

    try {
      final streamed = await request
          .send()
          .timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);
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

  Future<dynamic> delete(String endpoint) async {
    final headers = await _headers();
    return _send(
      () => http.delete(Uri.parse('$_baseUrl$endpoint'), headers: headers),
    );
  }
}
