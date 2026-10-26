import '../models/application_model.dart';
import 'api_service.dart';

/// Layanan riwayat lamaran dan laporan Excel.
///
/// [ApiService] menambahkan header `Authorization: Bearer <token>` secara
/// otomatis. Backend mengambil `applicant_id`/`recruiter_id` dari token
/// tersebut, bukan dari parameter klien, sehingga setiap role hanya menerima
/// data yang menjadi haknya.
class ApplicationService {
  final ApiService _api;

  ApplicationService({ApiService? api}) : _api = api ?? ApiService();

  /// Mengambil seluruh riwayat lamaran pengguna dari `GET /api/applications`.
  ///
  /// Backend mengurutkan dari lamaran terbaru dan mengembalikan
  /// `{ "applications": [ ... ] }`.
  Future<List<ApplicationModel>> fetchApplications() async {
    final data = await _api.get('/applications');

    if (data is Map<String, dynamic>) {
      final applications = data['applications'];
      if (applications is List) {
        return applications
            .whereType<Map<String, dynamic>>()
            .map(ApplicationModel.fromJson)
            .toList();
      }
    }

    throw ApiException(0, 'Respons daftar lamaran tidak sesuai format.');
  }

  /// Mengambil pelamar untuk lowongan milik recruiter yang sedang login.
  ///
  /// Backend memfilter dengan `jobs.recruiter_id` dari JWT dan hanya
  /// mengembalikan username pelamar.
  Future<List<RecruiterApplicantModel>> fetchRecruiterApplicants() async {
    final data = await _api.get('/applications/recruiter');

    if (data is Map<String, dynamic>) {
      final applicants = data['applicants'];
      if (applicants is List) {
        return applicants
            .whereType<Map<String, dynamic>>()
            .map(RecruiterApplicantModel.fromJson)
            .toList();
      }
    }

    throw ApiException(0, 'Respons daftar pelamar tidak sesuai format.');
  }

  /// Mengunduh laporan lamaran milik jobseeker sebagai .xlsx.
  Future<ApiDownload> exportApplications() {
    return _api.getFile(
      '/applications/export',
      fallbackFileName: 'laporan_lamaran_${_dateStamp()}.xlsx',
    );
  }

  /// Mengunduh laporan pelamar dari lowongan milik recruiter sebagai .xlsx.
  Future<ApiDownload> exportRecruiterApplicants() {
    return _api.getFile(
      '/applications/recruiter/export',
      fallbackFileName: 'laporan_pelamar_${_dateStamp()}.xlsx',
    );
  }

  static String _dateStamp() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }
}
