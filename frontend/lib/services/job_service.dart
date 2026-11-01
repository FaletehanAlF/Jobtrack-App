import '../models/job_model.dart';
import 'api_service.dart';

class JobService {
  final ApiService _api;

  JobService({ApiService? api}) : _api = api ?? ApiService();

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
