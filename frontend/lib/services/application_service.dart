import '../models/application_model.dart';
import '../models/cv_file.dart';
import 'api_service.dart';

class ApplicationService {
  final ApiService _api;

  ApplicationService({ApiService? api}) : _api = api ?? ApiService();

  Future<void> createApplication({
    required int jobId,
    PickedCvFile? cv,
  }) async {
    final data = await _api.postMultipart(
      '/applications',
      fields: {'job_id': '$jobId'},
      fileField: cv == null ? null : 'cv',
      fileBytes: cv?.bytes,
      fileName: cv == null ? null : 'cv.pdf',
    );

    if (data is! Map<String, dynamic> || data['application'] is! Map) {
      throw ApiException(0, 'Respons pembuatan lamaran tidak sesuai format.');
    }
  }

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

  Future<ApiDownload> exportApplications() {
    return _api.getFile(
      '/applications/export',
      fallbackFileName: 'laporan_lamaran_${_dateStamp()}.xlsx',
    );
  }

  Future<ApiDownload> exportRecruiterApplicants() {
    return _api.getFile(
      '/applications/recruiter/export',
      fallbackFileName: 'laporan_pelamar_${_dateStamp()}.xlsx',
    );
  }

  Future<String> fetchApplicantCvUrl(
    int applicationId, {
    bool download = false,
  }) async {
    final data = await _api.get(
      '/recruiter/applicants/$applicationId/cv',
      query: download ? const {'download': '1'} : null,
    );

    if (data is Map<String, dynamic>) {
      final urlString = data['download_url'] is String
          ? data['download_url'] as String
          : data['url'] is String
              ? data['url'] as String
              : null;

      if (urlString != null && urlString.isNotEmpty) {
        return urlString;
      }
    }

    throw ApiException(0, 'Respons akses CV tidak sesuai format.');
  }

  static String _dateStamp() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }
}
