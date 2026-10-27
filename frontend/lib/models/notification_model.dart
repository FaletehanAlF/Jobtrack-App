import 'application_model.dart';

/// Jenis notifikasi yang dikenal backend.
///
/// Nilainya sama dengan ENUM `notifications.type` pada migration
/// `table-notifications.sql`. Nilai tak dikenal tetap ditampilkan apa adanya
/// agar notifikasi lama tidak hilang dari daftar.
class NotificationType {
  /// Jobseeker melamar lowongan milik recruiter.
  static const String applicationReceived = 'application_received';

  /// Recruiter menolak lamaran.
  static const String applicationRejected = 'application_rejected';

  const NotificationType._();
}

/// Satu notifikasi milik pengguna yang sedang login.
///
/// Bentuk JSON dari `GET /api/notifications`:
/// {
///   "id": 5,
///   "type": "application_rejected",
///   "message": "Lamaranmu untuk \"Backend Developer\" ditolak.",
///   "job_id": 3,
///   "application_id": 9,
///   "created_at": "2026-10-27T10:00:00.000Z",
///   "read_at": null,
///   "is_read": false
/// }
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
      // `is_read` dari server diutamakan; read_at dipakai sebagai cadangan
      // bila field itu tidak ada.
      isRead: json['is_read'] is bool
          ? json['is_read'] as bool
          : readAt != null,
    );
  }

  /// Menandai notifikasi ini sudah dibaca tanpa menunggu respons server.
  ///
  /// `createdAt` dan field lain dipertahankan; hanya status bacanya berubah.
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

  /// Ikon yang sesuai jenis notifikasi.
  bool get isKnownType => isApplicationRejected || isApplicationReceived;

  static int? _parseOptionalInt(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

/// Hasil `GET /api/notifications` dengan pagination dan jumlah belum dibaca.
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