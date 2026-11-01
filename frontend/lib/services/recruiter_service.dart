import '../models/application_model.dart';
import '../models/recruiter_model.dart';
import 'api_service.dart';

class RecruiterService {
  final ApiService _api;

  RecruiterService({ApiService? api}) : _api = api ?? ApiService();

  Future<RecruiterDashboardData> fetchDashboard() async {
    final data = await _api.get('/recruiter/dashboard');

    if (data is Map<String, dynamic>) {
      return RecruiterDashboardData.fromJson(data);
    }

    throw ApiException(0, 'Respons dashboard tidak sesuai format.');
  }

  Future<RecruiterApplicantsPageData> fetchApplicants({
    int? jobId,
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    final query = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
      if (jobId != null) 'job_id': '$jobId',
      'status': ?status,
    };

    final data = await _api.get('/recruiter/applicants', query: query);

    if (data is Map<String, dynamic>) {
      return RecruiterApplicantsPageData.fromJson(data);
    }

    throw ApiException(0, 'Respons daftar pelamar tidak sesuai format.');
  }

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
