import '../models/job_model.dart';
import 'api_service.dart';

// ApiException is defined in api_service.dart and re-exported via same file.


/// Layanan lowongan kerja.
///
/// Menggunakan [ApiService] yang sudah menangani token, sehingga
/// `GET /api/jobs` otomatis membawa header Authorization.
class JobService {
  final ApiService _api;

  JobService({ApiService? api}) : _api = api ?? ApiService();

  /// Mengambil seluruh lowongan dari `GET /api/jobs`.
  ///
  /// Backend mengembalikan `{ "jobs": [ ... ] }`.
  Future<List<JobModel>> fetchJobs() async {
    final data = await _api.get('/jobs');

    if (data is Map<String, dynamic>) {
      final jobs = data['jobs'];
      if (jobs is List) {
        return jobs
            .whereType<Map<String, dynamic>>()
            .map(JobModel.fromJson)
            .toList();
      }
    }

    return <JobModel>[];
  }

  /// Mengambil detail satu lowongan dari `GET /api/jobs/:id`.
  Future<JobModel> fetchJob(int id) async {
    final data = await _api.get('/jobs/$id');

    if (data is Map<String, dynamic>) {
      final job = data['job'];
      if (job is Map<String, dynamic>) {
        return JobModel.fromJson(job);
      }
    }

    throw ApiException(0, 'Respons detail lowongan tidak sesuai format.');
  }
}
