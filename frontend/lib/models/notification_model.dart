class NotificationModel {
  final int? id;
  final String type;
  final String message;
  final int? jobId;
  final int? applicationId;
  final DateTime createdAt;
  final DateTime? readAt;
  final bool isRead;

  const NotificationModel({
    required this.id,
    required this.type,
    required this.message,
    this.jobId,
    this.applicationId,
    required this.createdAt,
    this.readAt,
    required this.isRead,
  });

  NotificationModel copyWith({
    DateTime? readAt,
    bool? isRead,
  }) {
    return NotificationModel(
      id: id,
      type: type,
      message: message,
      jobId: jobId,
      applicationId: applicationId,
      createdAt: createdAt,
      readAt: readAt ?? this.readAt,
      isRead: isRead ?? this.isRead,
    );
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final readAt = _parseDate(json['read_at']);
    final isRead = json['is_read'] is bool
        ? json['is_read'] as bool
        : readAt != null;

    final idValue = json['id'];

    return NotificationModel(
      id: idValue is num ? idValue.toInt() : int.tryParse('$idValue'),
      type: json['type'] as String? ?? '',
      message: json['message'] as String? ?? '',
      jobId: (json['job_id'] as num?)?.toInt(),
      applicationId: (json['application_id'] as num?)?.toInt(),
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      readAt: readAt,
      isRead: isRead,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is String && value.isNotEmpty && value != 'null') {
      // Sebagian driver MySQL menyerialisasikan DATETIME sebagai
      // "2026-10-27 10:00:00"; DateTime.parse lebih aman dengan ISO-8601.
      final normalized = value.replaceFirst(' ', 'T');
      final parsed = DateTime.tryParse(normalized);
      if (parsed != null) return parsed.toLocal();
    }

    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        value.toInt(),
        isUtc: true,
      ).toLocal();
    }

    return null;
  }

  /// Label waktu relatif sederhana, mis. "baru saja", "5 menit lalu".
  String get relativeTime {
    final diff = DateTime.now().difference(createdAt);

    if (diff.inSeconds < 60) return 'baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';

    final day = createdAt.day.toString().padLeft(2, '0');
    final month = createdAt.month.toString().padLeft(2, '0');
    return '$day/$month/${createdAt.year}';
  }
}
