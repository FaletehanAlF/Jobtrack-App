import 'application_model.dart';

class NotificationType {
  static const String applicationReceived = 'application_received';

  static const String applicationRejected = 'application_rejected';

  const NotificationType._();
}

class NotificationModel {
  final int id;
  final String type;
  final String message;
  final int? jobId;
  final int? applicationId;
  final DateTime? createdAt;
  final DateTime? readAt;
  final bool isRead;

  const NotificationModel({
    required this.id,
    required this.type,
    required this.message,
    required this.jobId,
    required this.applicationId,
    required this.createdAt,
    required this.readAt,
    required this.isRead,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! num) {
      throw FormatException(
        'Field "id" pada notifikasi harus berupa nomor, mendapat: '
        '${id.runtimeType}',
      );
    }

    final readAt = parseApiDate(json['read_at']);

    return NotificationModel(
      id: id.toInt(),
      type: json['type'] as String? ?? '',
      message: json['message'] as String? ?? '',
      jobId: _parseOptionalInt(json['job_id']),
      applicationId: _parseOptionalInt(json['application_id']),
      createdAt: parseApiDate(json['created_at']),
      readAt: readAt,
      isRead: json['is_read'] is bool
          ? json['is_read'] as bool
          : readAt != null,
    );
  }

  NotificationModel copyAsRead() {
    return NotificationModel(
      id: id,
      type: type,
      message: message,
      jobId: jobId,
      applicationId: applicationId,
      createdAt: createdAt,
      readAt: readAt ?? DateTime.now(),
      isRead: true,
    );
  }

  bool get isApplicationRejected => type == NotificationType.applicationRejected;

  bool get isApplicationReceived => type == NotificationType.applicationReceived;

  bool get isKnownType => isApplicationRejected || isApplicationReceived;

  static int? _parseOptionalInt(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

class NotificationPageData {
  final List<NotificationModel> notifications;
  final int total;
  final int unread;
  final int limit;
  final int offset;

  const NotificationPageData({
    required this.notifications,
    required this.total,
    required this.unread,
    required this.limit,
    required this.offset,
  });

  bool get hasMore => offset + notifications.length < total;

  factory NotificationPageData.fromJson(Map<String, dynamic> json) {
    final notifications = json['notifications'];

    if (notifications is! List) {
      throw const FormatException(
        'Respons notifikasi tidak berisi "notifications".',
      );
    }

    return NotificationPageData(
      notifications: notifications
          .whereType<Map<String, dynamic>>()
          .map(NotificationModel.fromJson)
          .toList(),
      total: _parseCount(json['total']),
      unread: _parseCount(json['unread']),
      limit: _parseCount(json['limit']),
      offset: _parseCount(json['offset']),
    );
  }

  static int _parseCount(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}