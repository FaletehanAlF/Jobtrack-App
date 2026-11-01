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
    return _readJob(data);
  }

  Future<JobModel> createJob({
    required String title,
    required String description,
    required String company,
    required String location,
  }) async {
    final data = await _api.post('/jobs', {
      'title': title,
      'description': description,
      'company': company,
      'location': location,
    });

    return _readJob(data);
  }

  Future<JobModel> updateJob(
    int id, {
    required String title,
    required String description,
    required String company,
    required String location,
  }) async {
    final data = await _api.put('/jobs/$id', {
      'title': title,
      'description': description,
      'company': company,
      'location': location,
    });

    return _readJob(data);
  }

  Future<void> deleteJob(int id) async {
    await _api.delete('/jobs/$id');
  }

  JobModel _readJob(dynamic data) {
    if (data is Map<String, dynamic>) {
      final job = data['job'];
      if (job is Map<String, dynamic>) {
        return JobModel.fromJson(job);
      }
    }

    throw ApiException(0, 'Respons lowongan tidak sesuai format.');
  }
}
