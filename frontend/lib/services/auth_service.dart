import '../models/user_model.dart';
import 'api_service.dart';

class AuthService {
  final ApiService _api;

  AuthService({ApiService? api}) : _api = api ?? ApiService();

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

    await _api.saveToken(token);

    return _readUser(data);
  }

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
        await _api.logout();
        return null;
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    await _api.logout();
  }

  Map<String, dynamic> _readBody(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }

    throw ApiException(
      0,
      'Respons server tidak sesuai format yang diharapkan.',
    );
  }

  UserModel _readUser(dynamic data) {
    final body = _readBody(data);
    final user = body['user'];

    if (user is! Map<String, dynamic>) {
      throw ApiException(0, 'Respons server tidak berisi data pengguna.');
    }

    return UserModel.fromJson(user);
  }
}
