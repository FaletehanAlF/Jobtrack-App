import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/application_model.dart';
import 'package:frontend/models/job_model.dart';
import 'package:frontend/models/user_model.dart';
import 'package:frontend/pages/home_page.dart';
import 'package:frontend/services/application_service.dart';
import 'package:frontend/services/job_service.dart';
import 'package:frontend/services/recruiter_service.dart';

class _J extends JobService { @override Future<List<JobModel>> fetchJobs() async => []; }
class _A extends ApplicationService { @override Future<List<ApplicationModel>> fetchApplications() async => []; }
class _R extends RecruiterService { @override Future<RecruiterDashboardData> fetchDashboard() async => const RecruiterDashboardData(stats: RecruiterDashboardStats.empty, jobs: []); @override Future<RecruiterApplicantsPageData> fetchApplicants({int? jobId, String? status, int limit=50, int offset=0}) async => RecruiterApplicantsPageData(applicants: const [], total:0, limit:limit, offset:offset); }
void main() {
  testWidgets('debug', (tester) async {
    tester.view.physicalSize = const Size(1280,1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() { tester.view.resetPhysicalSize(); tester.view.resetDevicePixelRatio(); });
    final user = UserModel(id:42,username:'rekruter',email:'r@e.com',role:'recruiter',createdAt:DateTime(2020));
    await tester.pumpWidget(MaterialApp(home: HomePage(user:user, jobService: _J(), applicationService: _A(), recruiterService: _R())));
    await tester.pumpAndSettle();
    print('BEFORE TEXTS: ${find.byType(Text).evaluate().map((e)=> (e.widget as Text).data).whereType<String>().toList()}');
    await tester.tap(find.text('Lowongan').first);
    await tester.pumpAndSettle();
    print('AFTER TEXTS: ${find.byType(Text).evaluate().map((e)=> (e.widget as Text).data).whereType<String>().toList()}');
    print('CREATE BUTTON: ${find.byKey(const Key('jobs-create-button')).evaluate().length}');
  });
}
