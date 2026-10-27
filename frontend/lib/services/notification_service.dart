import '../models/notification_model.dart';
import 'api_service.dart';

/// Layanan notifikasi untuk jobseeker dan recruiter.
///
/// [ApiService] menambahkan header `Authorization: Bearer <token>`.
/// Penerima notifikasi ditentukan backend dari JWT, bukan dari parameter
/// yang dikirim klien — tidak ada `user_id` yang bisa dipalsukan di sini.
class NotificationService {
  final ApiService _api;

  NotificationService({ApiService? api}) : _api = api ?? ApiService();

  /// `GET /api/notifications` dengan pagination.
  Future<NotificationPageData> fetchNotifications({
    int limit = 50,
    int offset = 0,
  }) async {
    final data = await _api.get(
      '/notifications',
      query: {'limit': '$limit', 'offset': '$offset'},
    );

    if (data is Map<String, dynamic>) {
      return NotificationPageData.fromJson(data);
    }

    throw ApiException(0, 'Respons notifikasi tidak sesuai format.');
  }

  /// `GET /api/notifications/unread-count`.
  ///
  /// Dipakai untuk indikator pada ikon lonceng tanpa memuat daftar penuh.
  Future<int> fetchUnreadCount() async {
    final data = await _api.get('/notifications/unread-count');

    if (data is Map<String, dynamic>) {
      final unread = data['unread'];
      if (unread is num) return unread.toInt();
      if (unread is String) return int.tryParse(unread) ?? 0;
    }

    throw ApiException(0, 'Respons jumlah notifikasi tidak sesuai format.');
  }

  /// `PATCH /api/notifications/:id/read`.
  Future<NotificationModel> markRead(int notificationId) async {
    final data = await _api.patch('/notifications/$notificationId/read', {});

    if (data is Map<String, dynamic>) {
      final notification = data['notification'];
      if (notification is Map<String, dynamic>) {
        return NotificationModel.fromJson(notification);
      }
    }

    throw ApiException(0, 'Respons baca notifikasi tidak sesuai format.');
  }

  /// `PATCH /api/notifications/read-all`.
  Future<void> markAllRead() async {
    await _api.patch('/notifications/read-all', {});
  }
}