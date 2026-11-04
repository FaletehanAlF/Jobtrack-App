import '../models/notification_model.dart';
import 'api_service.dart';

class NotificationPage {
  final List<NotificationModel> notifications;
  final int total;
  final int unread;

  const NotificationPage({
    required this.notifications,
    required this.total,
    required this.unread,
  });
}

class NotificationService {
  NotificationService({ApiService? apiService})
      : _api = apiService ?? ApiService();

  final ApiService _api;

  Future<NotificationPage> fetchNotifications({
    int limit = 50,
    int offset = 0,
  }) async {
    final body = await _api.get(
      '/notifications',
      query: {'limit': '$limit', 'offset': '$offset'},
    );

    final map = body is Map<String, dynamic>
        ? body
        : Map<String, dynamic>.from(body as Map);

    final items = (map['notifications'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => NotificationModel.fromJson(
              Map<String, dynamic>.from(item),
            ))
        .toList();

    return NotificationPage(
      notifications: items,
      total: (map['total'] as num?)?.toInt() ?? items.length,
      unread: (map['unread'] as num?)?.toInt() ?? 0,
    );
  }

  Future<int> fetchUnreadCount() async {
    final body = await _api.get('/notifications/unread-count');

    if (body is Map<String, dynamic>) {
      return (body['unread'] as num?)?.toInt() ?? 0;
    }

    if (body is Map) {
      return (body['unread'] as num?)?.toInt() ?? 0;
    }

    return 0;
  }

  Future<void> markRead(int id) async {
    await _api.patch('/notifications/$id/read', const {});
  }

  Future<void> markAllRead() async {
    await _api.patch('/notifications/read-all', const {});
  }
}
