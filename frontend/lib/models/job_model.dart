import 'package:flutter/foundation.dart';

/// Model lowongan kerja yang merepresentasikan objek dari respons
/// `GET /api/jobs` backend JobTrack.
///
/// Bentuk JSON yang dikirim backend:
/// {
///   "id": 1,
///   "recruiter_id": 2,
///   "title": "...",
///   "description": "...",
///   "company": "...",
///   "location": "...",
///   "created_at": "2026-10-20T14:45:29.000Z",
///   "updated_at": "2026-10-20T14:45:29.000Z"
/// }
class JobModel {
  final int id;
  final int recruiterId;
  final String title;
  final String description;
  final String company;
  final String location;
  final DateTime createdAt;
  final DateTime updatedAt;

  const JobModel({
    required this.id,
    required this.recruiterId,
    required this.title,
    required this.description,
    required this.company,
    required this.location,
    required this.createdAt,
    required this.updatedAt,
  });

  factory JobModel.fromJson(Map<String, dynamic> json) {
    return JobModel(
      id: (json['id'] as num).toInt(),
      recruiterId: (json['recruiter_id'] as num).toInt(),
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      company: json['company'] as String? ?? '',
      location: json['location'] as String? ?? '',
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed.toLocal();
    }

    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true)
          .toLocal();
    }

    assert(() {
      debugPrint('[JobModel] tanggal tidak dikenali: $value');
      return true;
    }());

    return DateTime.now();
  }
}
