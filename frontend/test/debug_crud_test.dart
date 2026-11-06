import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/models/job_model.dart';
import 'package:frontend/models/user_model.dart';
import 'package:frontend/models/recruiter_model.dart';
import 'package:frontend/pages/home_page.dart';
import 'package:frontend/services/application_service.dart';
import 'package:frontend/services/job_service.dart';
import 'package:frontend/services/recruiter_service.dart';

class _FakeJobService extends JobService {
  _FakeJobService(this.jobs);
  List<JobModel> jobs;
  @override Future<List<JobModel>> fetchJobs() async => List.of(jobs);
}

class _EmptyApplicationService extends ApplicationService {
  @override Future<List<ApplicationModel>> fetchApplications() async => [];
}

class _FakeRecruiterService extends RecruiterService {
  @override Future<RecruiterDashboardData> fetchDashboard() async => const RecruiterDashboardData(stats: RecruiterDashboardStats.empty, jobs: []);
  @override Future<RecruiterApplicantsPageData> fetchApplicants({int? jobId, String? status, int limit = 50, int offset = 0}) async => RecruiterApplicantsPageData(applicants: const [], total: 0, limit: limit, offset: offset);
}

JobModel _job({required int id, required int recruiterId, required String title}) => JobModel(id:id, recruiterId:recruiterId, title:title, description:'desc', company:'PT Gamma', location:'Jakarta', createdAt:DateTime(2026,10,20), updatedAt:DateTime(2026,10,20));
UserModel _recruiter() => UserModel(id:42, username:'rekruter', email:'rekruter@example.com', role:'recruiter', createdAt:DateTime(2020));

void _setSurfaceSize(WidgetTester tester) { tester.view.physicalSize = const Size(1280,1000); tester.view.devicePixelRatio=1.0; addTearDown((){tester.view.resetPhysicalSize();tester.view.resetDevicePixelRatio();}); }

Future<void> _pumpHome(WidgetTester tester, {required UserModel user, required JobService jobService}) async {
  await tester.pumpWidget(MaterialApp(home: HomePage(user:user, jobService:jobService, applicationService:_EmptyApplicationService(), recruiterService:_FakeRecruiterService())));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Lowongan').first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('debug crud', (tester) async {
    _setSurfaceSize(tester);
    final service = _FakeJobService([_job(id:3, recruiterId:42, title:'Backend Developer')]);
    await _pumpHome(tester, user:_recruiter(), jobService:service);
    print('TEXTS: ${find.byType(Text).evaluate().map((e)=> (e.widget as Text).data).whereType<String>().toList()}');
    print('CREATE BUTTON: ${find.byKey(const Key('jobs-create-button')).evaluate().length}');
    print('JOBS CREATE TYPE: ${find.byKey(const Key('jobs-create-button')).evaluate().map((e)=> e.widget.runtimeType).toList()}');
  });
}
