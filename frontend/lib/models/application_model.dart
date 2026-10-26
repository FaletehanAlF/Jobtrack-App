import 'package:flutter/foundation.dart';

/// Status lamaran yang benar-benar didukung tabel `job_applications`.
///
/// Kolom status di database adalah ENUM('submitted', 'rejected'), jadi UI
/// hanya memberi label khusus untuk dua nilai ini. Nilai lain tetap
/// ditampilkan apa adanya agar data yang tidak dikenal tidak disembunyikan.
class ApplicationStatus {
  static const String submitted = 'submitted';
  static const String rejected = 'rejected';

  const ApplicationStatus._();
}

/// Label status yang konsisten untuk UI maupun ringkasan laporan.
String applicationStatusLabel(String status) {
  switch (status) {
    case ApplicationStatus.submitted:
      return 'Dikirim';
    case ApplicationStatus.rejected:
      return 'Ditolak';
    default:
      return status.isEmpty ? 'Tidak diketahui' : status;
  }
}

/// Ringkasan lowongan yang ikut dikirim pada respons `GET /api/applications`.
///
/// Endpoint lamaran hanya mengirim judul, perusahaan, dan lokasi lowongan,
/// bukan seluruh detail lowongan. Detail lengkap tetap diambil dari
/// `GET /api/jobs/:id` bila pengguna membuka lowongannya.
class ApplicationJob {
  final int id;
  final String title;
  final String company;
  final String location;

  const ApplicationJob({
    required this.id,
    required this.title,
    required this.company,
    required this.location,
  });

  factory ApplicationJob.fromJson(Map<String, dynamic> json) {
    return ApplicationJob(
      id: _parseInt(json['id'], 'job.id'),
      title: json['title'] as String? ?? '',
      company: json['company'] as String? ?? '',
      location: json['location'] as String? ?? '',
    );
  }

  static int _parseInt(dynamic value, String fieldName) {
    if (value is num) return value.toInt();

    throw FormatException(
      'Field "$fieldName" harus berupa nomor, mendapat: ${value.runtimeType}',
    );
  }
}

/// Satu baris riwayat lamaran milik pengguna yang sedang login.
///
/// Bentuk JSON dari backend:
/// {
///   "id": 12,
///   "job_id": 3,
///   "status": "submitted",
///   "created_at": "2026-10-20T14:45:29.000Z",
///   "job": { "id": 3, "title": "...", "company": "...", "location": "..." }
/// }
class ApplicationModel {
  final int id;
  final int jobId;
  final String status;
  final DateTime? createdAt;
  final ApplicationJob job;

  const ApplicationModel({
    required this.id,
    required this.jobId,
    required this.status,
    required this.createdAt,
    required this.job,
  });

  factory ApplicationModel.fromJson(Map<String, dynamic> json) {
    final jobJson = json['job'];

    if (jobJson is! Map<String, dynamic>) {
      throw const FormatException(
        'Field "job" pada data lamaran tidak ditemukan atau bukan objek.',
      );
    }

    return ApplicationModel(
      id: _parseInt(json['id'], 'id'),
      jobId: _parseInt(json['job_id'], 'job_id'),
      status: json['status'] as String? ?? '',
      createdAt: _parseDate(json['created_at']),
      job: ApplicationJob.fromJson(jobJson),
    );
  }

  bool get isSubmitted => status == ApplicationStatus.submitted;

  bool get isRejected => status == ApplicationStatus.rejected;

  /// Label status untuk UI. Status yang belum dikenal tetap ditampilkan
  /// agar pengguna tidak melihat riwayat yang tampak kosong.
  String get statusLabel => applicationStatusLabel(status);

  static int _parseInt(dynamic value, String fieldName) {
    if (value is num) return value.toInt();

    throw FormatException(
      'Field "$fieldName" harus berupa nomor, mendapat: ${value.runtimeType}',
    );
  }

  /// Tanggal yang hilang/tidak valid menjadi null, bukan waktu sekarang.
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

    if (kDebugMode && value != null) {
      debugPrint('[ApplicationModel] tanggal tidak valid: $value');
    }

    return null;
  }
}

/// Satu baris pelamar yang dikirim `GET /api/applications/recruiter`.
///
/// Backend hanya mengirim username pelamar, bukan email atau kolom sensitif
/// lain. `job` adalah lowongan milik recruiter yang sedang login.
class RecruiterApplicantModel {
  final int id;
  final String status;
  final DateTime? createdAt;
  final String applicantUsername;
  final ApplicationJob job;

  const RecruiterApplicantModel({
    required this.id,
    required this.status,
    required this.createdAt,
    required this.applicantUsername,
    required this.job,
  });

  factory RecruiterApplicantModel.fromJson(Map<String, dynamic> json) {
    final jobJson = json['job'];
    final applicantJson = json['applicant'];

    if (jobJson is! Map<String, dynamic>) {
      throw const FormatException(
        'Field "job" pada data pelamar tidak ditemukan atau bukan objek.',
      );
    }

    if (applicantJson is! Map<String, dynamic>) {
      throw const FormatException(
        'Field "applicant" pada data pelamar tidak ditemukan atau bukan objek.',
      );
    }

    return RecruiterApplicantModel(
      id: _parseInt(json['id'], 'id'),
      status: json['status'] as String? ?? '',
      createdAt: ApplicationModel._parseDate(json['created_at']),
      applicantUsername: applicantJson['username'] as String? ?? '',
      job: ApplicationJob.fromJson(jobJson),
    );
  }

  bool get isSubmitted => status == ApplicationStatus.submitted;

  bool get isRejected => status == ApplicationStatus.rejected;

  String get statusLabel => applicationStatusLabel(status);

  static int _parseInt(dynamic value, String fieldName) {
    if (value is num) return value.toInt();

    throw FormatException(
      'Field "$fieldName" harus berupa nomor, mendapat: ${value.runtimeType}',
    );
  }
}

/// Hitungan ringkasan yang diturunkan dari daftar lamaran milik pengguna.
///
/// Data asalnya tetap database: daftar lamaran diterima dari
/// `GET /api/applications` yang sudah difilter berdasarkan `applicant_id`
/// dari token JWT di backend.
class ApplicationStats {
  final int total;
  final int submitted;
  final int rejected;

  const ApplicationStats({
    required this.total,
    required this.submitted,
    required this.rejected,
  });

  factory ApplicationStats.fromApplications(
    Iterable<ApplicationModel> applications,
  ) {
    return ApplicationStats.fromStatuses(
      applications.map((application) => application.status),
    );
  }

  factory ApplicationStats.fromStatuses(Iterable<String> statuses) {
    var total = 0;
    var submitted = 0;
    var rejected = 0;

    for (final status in statuses) {
      total += 1;
      if (status == ApplicationStatus.submitted) submitted += 1;
      if (status == ApplicationStatus.rejected) rejected += 1;
    }

    return ApplicationStats(
      total: total,
      submitted: submitted,
      rejected: rejected,
    );
  }
}
