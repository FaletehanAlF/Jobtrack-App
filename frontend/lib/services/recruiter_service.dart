import '../models/application_model.dart';
import '../models/recruiter_model.dart';
import 'api_service.dart';

/// Layanan data recruiter: dashboard dan manajemen pelamar.
///
/// [ApiService] menambahkan header `Authorization: Bearer <token>`.
/// Backend menentukan lowongan mana yang boleh dibaca dari `recruiter_id`
/// di token, bukan dari parameter yang dikirim klien — parameter di sini
/// hanya mempersempit hasil yang memang sudah dibatasi kepemilikan.
class RecruiterService {
  final ApiService _api;

  RecruiterService({ApiService? api}) : _api = api ?? ApiService();

  /// `GET /api/recruiter/dashboard`.
  Future<RecruiterDashboardData> fetchDashboard() async {
    final data = await _api.get('/recruiter/dashboard');

    if (data is Map<String, dynamic>) {
      return RecruiterDashboardData.fromJson(data);
    }

    throw ApiException(0, 'Respons dashboard tidak sesuai format.');
  }

  /// `GET /api/recruiter/applicants` dengan filter dan pagination.
  ///
  /// [jobId] dan [status] opsional. Nilai yang tidak valid ditolak backend
  /// dengan 400, jadi pemanggil cukup mengirim string yang diinginkan.
  Future<RecruiterApplicantsPageData> fetchApplicants({
    int? jobId,
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    final query = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
      // job_id perlu interpolasi, jadi tetap memakai `if`.
      if (jobId != null) 'job_id': '$jobId',
      // Status sudah String?, jadi bisa memakai null-aware element.
      'status': ?status,
    };

    final data = await _api.get('/recruiter/applicants', query: query);

    if (data is Map<String, dynamic>) {
      return RecruiterApplicantsPageData.fromJson(data);
    }

    throw ApiException(0, 'Respons daftar pelamar tidak sesuai format.');
  }

  /// `PATCH /api/recruiter/applicants/:id/status`.
  ///
  /// Backend memverifikasi bahwa lamaran itu milik lowongan recruiter yang
  /// sedang login; lamaran milik recruiter lain dijawab 404.
  Future<RecruiterApplicantModel> updateStatus({
    required int applicationId,
    required String status,
  }) async {
    final data = await _api.patch(
      '/recruiter/applicants/$applicationId/status',
      {'status': status},
    );

    if (data is Map<String, dynamic>) {
      final application = data['application'];
      if (application is Map<String, dynamic>) {
        return RecruiterApplicantModel.fromJson(application);
      }
    }

    throw ApiException(0, 'Respons perubahan status tidak sesuai format.');
  }
}
