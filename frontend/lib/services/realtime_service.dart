import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../models/notification_model.dart';
import 'api_service.dart';

/// Membungkus koneksi Socket.IO ke backend JobTrack.
///
/// Koneksi memakai token JWT yang sama dengan REST API
/// (`handshake.auth.token`) dan berlangganan event `notification`.
class RealtimeService {
  RealtimeService({String? socketUrl, String? baseUrl})
      : _socketUrl = socketUrl,
        _baseUrl = baseUrl;

  static const String _tokenKey = 'auth_token';

  final String? _socketUrl;
  final String? _baseUrl;

  io.Socket? _socket;
  final StreamController<NotificationModel> _controller =
      StreamController<NotificationModel>.broadcast();

  /// Stream notifikasi yang masuk dari server.
  Stream<NotificationModel> get notifications => _controller.stream;

  bool get isConnected => _socket?.connected ?? false;

  String _resolveUrl() {
    if (_socketUrl != null) return _socketUrl!;

    final base = _baseUrl ?? ApiService.defaultBaseUrl;

    if (base.endsWith('/api/')) {
      return base.substring(0, base.length - 5);
    }
    if (base.endsWith('/api')) {
      return base.substring(0, base.length - 4);
    }
    return base;
  }

  /// Membuka koneksi (tidak melempar ke caller bila token tidak ada atau
  /// server tidak tersedia; realtime bersifat opsional terhadap polling).
  Future<void> connect() async {
    if (_socket != null) {
      if (!(_socket?.connected ?? false)) {
        _socket?.connect();
      }
      return;
    }

    String token = '';
    try {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString(_tokenKey) ?? '';
    } catch (_) {
      return;
    }

    if (token.isEmpty) return;

    final options = io.OptionBuilder()
        .setTransports(const ['websocket', 'polling'])
        .setAuth(<String, dynamic>{'token': token})
        .setReconnectionDelay(1000)
        .setReconnectionDelayMax(10000)
        .build();

    final socket = io.io(_resolveUrl(), options);

    socket.on('notification', (data) => _handleNotification(data));
    socket.on('connect_error', (_) {
      // Server tidak menjangkau atau token ditolak — abaikan;
      // polling REST tetap menjaga badge tetap segar.
    });

    _socket = socket;
    socket.connect();
  }

  void _handleNotification(dynamic data) {
    if (_controller.isClosed) return;

    try {
      if (data is Map) {
        _controller.add(
          NotificationModel.fromJson(Map<String, dynamic>.from(data)),
        );
      }
    } catch (_) {
      // Payload tidak valid — abaikan, jangan putuskan socket.
    }
  }

  Future<void> disconnect() async {
    final socket = _socket;
    _socket = null;

    try {
      await socket?.dispose();
    } catch (_) {
      // Abaikan — socket mungkin sedang dalam status setengah terbuka.
    }
  }

  Future<void> dispose() async {
    await disconnect();

    if (!_controller.isClosed) {
      await _controller.close();
    }
  }
}
