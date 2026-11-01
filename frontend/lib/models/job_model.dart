class JobModel {
  final int id;
  final int recruiterId;
  final String title;
  final String description;
  final String company;
  final String location;
  final DateTime? createdAt;
  final DateTime? updatedAt;

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
      id: _parseId(json['id'], 'id'),
      recruiterId: _parseId(json['recruiter_id'], 'recruiter_id'),
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      company: json['company'] as String? ?? '',
      location: json['location'] as String? ?? '',
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
    );
  }

  static int _parseId(dynamic value, String fieldName) {
    if (value is num) {
      return value.toInt();
    }

    throw FormatException(
      'Field "$fieldName" harus berupa nomor, mendapat: ${value.runtimeType}',
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is String) {
      final parsed = DateTime.tryParse(value);
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
}
