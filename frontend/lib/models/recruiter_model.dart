import 'application_model.dart';

/// Ringkasan satu lowongan milik recruiter beserta hitungan pelamarnya.
///
/// Bentuk JSON dari `GET /api/recruiter/dashboard`:
/// {
///   "id": 3, "title": "...", "company": "...", "location": "...",
///   "created_at": "...",
///   "applicant_count": 4, "submitted_count": 3, "rejected_count": 1
/// }
///
/// Hitungan dihitung database (COUNT), bukan dari daftar panjang di
/// aplikasi, sehingga tetap benar tanpa mengambil seluruh baris pelamar.
class RecruiterJobStats {
  final int id;
  final String title;
  final String company;
  final String location;
  final DateTime? createdAt;
  final int applicantCount;
  final int submittedCount;
  final int rejectedCount;

  const RecruiterJobStats({
    required this.id,
    required this.title,
    required this.company,
    required this.location,
    required this.createdAt,
    required this.applicantCount,
    required this.submittedCount,
    required this.rejectedCount,
  });

  factory RecruiterJobStats.fromJson(Map<String, dynamic> json) {
    return RecruiterJobStats(
      id: _parseInt(json['id'], 'id'),
      title: json['title'] as String? ?? '',
      company: json['company'] as String? ?? '',
      location: json['location'] as String? ?? '',
      createdAt: ApplicationModel._parseDate(json['created_at']),
      applicantCount: _parseInt(json['applicant_count'], 'applicant_count'),
      submittedCount: _parseInt(json['submitted_count'], 'submitted_count'),
      rejectedCount: _parseInt(json['rejected_count'], 'rejected_count'),
    );
  }

  static int _parseInt(dynamic value, String fieldName) {
    if (value is num) return value.toInt();
    // COUNT dari driver database bisa berupa string pada beberapa konfigurasi.
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }

    throw FormatException(
      'Field "$fieldName" harus berupa nomor, mendapat: ${value.runtimeType}',
    );
  }
}

/// Total dihitung dari lowongan milik recruiter yang sedang login.
class RecruiterDashboardStats {
  final int jobs;
  final int applicants;
  final int submitted;
  final int rejected;

  const RecruiterDashboardStats({
    required this.jobs,
    required this.applicants,
    required this.submitted,
    required this.rejected,
  });

  static const empty = RecruiterDashboardStats(
    jobs: 0,
    applicants: 0,
    submitted: 0,
    rejected: 0,
  );

  factory RecruiterDashboardStats.fromJson(Map<String, dynamic> json) {
    return RecruiterDashboardStats(
      jobs: RecruiterJobStats._parseInt(json['jobs'], 'stats.jobs'),
      applicants: RecruiterJobStats._parseInt(
        json['applicants'],
        'stats.applicants',
      ),
      submitted: RecruiterJobStats._parseInt(
        json['submitted'],
        'stats.submitted',
      ),
      rejected: RecruiterJobStats._parseInt(
        json['rejected'],
        'stats.rejected',
      ),
    );
  }
}

/// Hasil lengkap `GET /api/recruiter/dashboard`.
class RecruiterDashboardData {
  final RecruiterDashboardStats stats;
  final List<RecruiterJobStats> jobs;

  const RecruiterDashboardData({required this.stats, required this.jobs});

  factory RecruiterDashboardData.fromJson(Map<String, dynamic> json) {
    final statsJson = json['stats'];
    final jobsJson = json['jobs'];

    if (statsJson is! Map<String, dynamic>) {
      throw const FormatException('Respons dashboard tidak berisi "stats".');
    }

    if (jobsJson is! List) {
      throw const FormatException('Respons dashboard tidak berisi "jobs".');
    }

    return RecruiterDashboardData(
      stats: RecruiterDashboardStats.fromJson(statsJson),
      jobs: jobsJson
          .whereType<Map<String, dynamic>>()
          .map(RecruiterJobStats.fromJson)
          .toList(),
    );
  }
}

/// Hasil `GET /api/recruiter/applicants` dengan pagination.
class RecruiterApplicantsPageData {
  final List<RecruiterApplicantModel> applicants;
  final int total;
  final int limit;
  final int offset;

  const RecruiterApplicantsPageData({
    required this.applicants,
    required this.total,
    required this.limit,
    required this.offset,
  });

  /// True bila masih ada halaman berikutnya setelah data ini.
  bool get hasMore => offset + applicants.length < total;

  factory RecruiterApplicantsPageData.fromJson(Map<String, dynamic> json) {
    final applicants = json['applicants'];

    if (applicants is! List) {
      throw const FormatException('Respons pelamar tidak berisi "applicants".');
    }

    final parsed = applicants
        .whereType<Map<String, dynamic>>()
        .map(RecruiterApplicantModel.fromJson)
        .toList();

    return RecruiterApplicantsPageData(
      applicants: parsed,
      total: RecruiterJobStats._parseInt(json['total'], 'total'),
      limit: RecruiterJobStats._parseInt(json['limit'], 'limit'),
      offset: RecruiterJobStats._parseInt(json['offset'], 'offset'),
    );
  }
}
