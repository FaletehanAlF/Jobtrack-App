import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../services/realtime_service.dart';

/// Mengelola state notifikasi untuk shell aplikasi:
///
/// - mengambil jumlah belum dibaca (badge) lewat REST,
/// - mendengarkan notifikasi masuk lewat Socket.IO (real-time),
/// - polling REST ringan sebagai fallback bila socket terputus,
/// - aksi tandai dibaca (satu & semua).
class NotificationController extends ChangeNotifier {
  NotificationController({
    NotificationService? notificationService,
    RealtimeService? realtimeService,
    Duration pollInterval = const Duration(seconds: 45),
  })  : _notificationService = notificationService ?? NotificationService(),
        _realtimeService = realtimeService ?? RealtimeService(),
        _pollInterval = pollInterval;

  final NotificationService _notificationService;
  final RealtimeService _realtimeService;
  final Duration _pollInterval;

  List<NotificationModel> notifications = const [];
  int unreadCount = 0;
  bool loading = false;
  String? error;

  /// Dipanggil setiap ada notifikasi baru (mis. untuk menampilkan SnackBar).
  void Function(NotificationModel notification)? onNewNotification;

  StreamSubscription<NotificationModel>? _subscription;
  Timer? _pollTimer;
  bool _started = false;
  bool _disposed = false;

  bool get hasNotifications => notifications.isNotEmpty;

  /// Menghidupkan koneksi realtime + polling fallback. Idempotent.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    await refreshUnreadCount();

    _subscription = _realtimeService.notifications.listen(
      _handleRealtimeNotification,
      onError: (_) {},
    );
    unawaited(_realtimeService.connect());

    _pollTimer = Timer.periodic(_pollInterval, (_) => refreshUnreadCount());
  }

  void _handleRealtimeNotification(NotificationModel notification) {
    unreadCount += 1;
    notifications = [notification, ...notifications];
    _notify();
    onNewNotification?.call(notification);
  }

  /// Menyegarkan badge unread dari REST (dipakai saat start & polling).
  Future<void> refreshUnreadCount() async {
    try {
      final unread = await _notificationService.fetchUnreadCount();
      if (_disposed) return;
      unreadCount = unread;
      _notify();
    } catch (_) {
      // Server tidak terjangkau — biarkan nilai badge apa adanya.
    }
  }

  /// Memuat (ulang) daftar notifikasi dari REST.
  Future<void> loadNotifications({int limit = 50}) async {
    loading = true;
    error = null;
    _notify();

    try {
      final page =
          await _notificationService.fetchNotifications(limit: limit);

      if (_disposed) return;

      notifications = page.notifications;
      unreadCount = page.unread;
      loading = false;
    } catch (loadError) {
      if (_disposed) return;

      error = loadError.toString();
      loading = false;
    }

    _notify();
  }

  Future<void> markRead(NotificationModel notification) async {
    final id = notification.id;

    if (id == null || notification.isRead) return;

    final now = DateTime.now();
    notifications = [
      for (final item in notifications)
        if (item.id == id) item.copyWith(readAt: now, isRead: true) else item,
    ];
    if (unreadCount > 0) unreadCount -= 1;
    _notify();

    try {
      await _notificationService.markRead(id);
    } catch (_) {
      // Gagal menandai — resync dari server agar state tidak drift.
      await loadNotifications();
    }
  }

  Future<void> markAllRead() async {
    final hasUnread = notifications.any((item) => !item.isRead);

    if (unreadCount == 0 && !hasUnread) return;

    final now = DateTime.now();
    notifications = [
      for (final item in notifications)
        item.isRead ? item : item.copyWith(readAt: now, isRead: true),
    ];
    unreadCount = 0;
    _notify();

    try {
      await _notificationService.markAllRead();
    } catch (_) {
      await loadNotifications();
    }
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    _pollTimer = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
    unawaited(_realtimeService.dispose());
    super.dispose();
  }
}
