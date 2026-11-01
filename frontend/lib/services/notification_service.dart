import '../models/notification_model.dart';
import 'api_service.dart';

class NotificationService {
  final ApiService _api;

  NotificationService({ApiService? api}) : _api = api ?? ApiService();

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

  Future<int> fetchUnreadCount() async {
    final data = await _api.get('/notifications/unread-count');

    if (data is Map<String, dynamic>) {
      final unread = data['unread'];
      if (unread is num) return unread.toInt();
      if (unread is String) return int.tryParse(unread) ?? 0;
    }

    throw ApiException(0, 'Respons jumlah notifikasi tidak sesuai format.');
  }

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

  Future<void> markAllRead() async {
    await _api.patch('/notifications/read-all', {});
  }
}
