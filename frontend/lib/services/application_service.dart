import '../models/application_model.dart';
import 'api_service.dart';

/// Layanan riwayat lamaran jobseeker.
///
/// [ApiService] menambahkan header `Authorization: Bearer <token>` secara
/// otomatis. Backend mengambil `applicant_id` dari token tersebut, bukan dari
/// parameter klien, sehingga jobseeker hanya menerima lamarannya sendiri.
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
}
