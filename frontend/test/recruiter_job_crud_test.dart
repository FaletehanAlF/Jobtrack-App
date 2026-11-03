import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/models/application_model.dart';
import 'package:frontend/models/job_model.dart';
import 'package:frontend/models/recruiter_model.dart';
import 'package:frontend/models/user_model.dart';
import 'package:frontend/pages/home_page.dart';
import 'package:frontend/pages/job_form_page.dart';
import 'package:frontend/services/application_service.dart';
import 'package:frontend/services/job_service.dart';

import 'package:frontend/services/recruiter_service.dart';

class _FakeJobService extends JobService {
  _FakeJobService(this.jobs);

  List<JobModel> jobs;

  int createCalls = 0;
  int updateCalls = 0;
  int deleteCalls = 0;

  @override
  Future<List<JobModel>> fetchJobs() async => List.of(jobs);

  @override
  Future<JobModel> createJob({
    required String title,
    required String description,
    required String company,
    required String location,
  }) async {
    createCalls += 1;
    final job = JobModel(
      id: 99,
      recruiterId: 42,
      title: title,
      description: description,
      company: company,
      location: location,
      createdAt: DateTime(2026, 11, 1),
      updatedAt: DateTime(2026, 11, 1),
    );
    jobs = [job, ...jobs];
    return job;
  }

  @override
  Future<JobModel> updateJob(
    int id, {
    required String title,
    required String description,
    required String company,
    required String location,
  }) async {
    updateCalls += 1;
    final updated = JobModel(
      id: id,
      recruiterId: 42,
      title: title,
      description: description,
      company: company,
      location: location,
      createdAt: DateTime(2026, 10, 20),
      updatedAt: DateTime(2026, 11, 1),
    );
    jobs = [
      for (final job in jobs)
        if (job.id == id) updated else job,
    ];
    return updated;
  }

  @override
  Future<void> deleteJob(int id) async {
    deleteCalls += 1;
    jobs = [
      for (final job in jobs)
        if (job.id != id) job,
    ];
  }
}

class _EmptyApplicationService extends ApplicationService {
  @override
  Future<List<ApplicationModel>> fetchApplications() async => const [];
}

class _FakeRecruiterService extends RecruiterService {
  @override
  Future<RecruiterDashboardData> fetchDashboard() async {
    return const RecruiterDashboardData(
      stats: RecruiterDashboardStats.empty,
      jobs: [],
    );
  }

  @override
  Future<RecruiterApplicantsPageData> fetchApplicants({
    int? jobId,
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    return RecruiterApplicantsPageData(
      applicants: const [],
      total: 0,
      limit: limit,
      offset: offset,
    );
  }
}

JobModel _job({
  required int id,
  required int recruiterId,
  required String title,
}) {
  return JobModel(
    id: id,
    recruiterId: recruiterId,
    title: title,
    description: 'Deskripsi lowongan yang cukup panjang.',
    company: 'PT Gamma',
    location: 'Jakarta',
    createdAt: DateTime(2026, 10, 20),
    updatedAt: DateTime(2026, 10, 20),
  );
}

UserModel _recruiter() => UserModel(
  id: 42,
  username: 'rekruter',
  email: 'rekruter@example.com',
  role: 'recruiter',
  createdAt: DateTime(2020),
);

UserModel _jobseeker() => UserModel(
  id: 7,
  username: 'pencari',
  email: 'pencari@example.com',
  role: 'jobseeker',
  createdAt: DateTime(2020),
);

void _setSurfaceSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pumpHome(
  WidgetTester tester, {
  required UserModel user,
  required JobService jobService,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: HomePage(
        user: user,
        jobService: jobService,
        applicationService: _EmptyApplicationService(),
        recruiterService: _FakeRecruiterService(),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text('Lowongan').first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Recruiter dapat membuat lowongan baru dari tab Lowongan', (
    WidgetTester tester,
  ) async {
    _setSurfaceSize(tester);

    final service = _FakeJobService([
      _job(id: 3, recruiterId: 42, title: 'Backend Developer'),
    ]);

    await _pumpHome(tester, user: _recruiter(), jobService: service);

    await tester.tap(find.byKey(const Key('jobs-create-button')));
    await tester.pumpAndSettle();

    expect(find.byType(JobFormPage), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('job-form-title')),
      'Flutter Developer',
    );
    await tester.enterText(
      find.byKey(const Key('job-form-company')),
      'PT Baru',
    );
    await tester.enterText(
      find.byKey(const Key('job-form-location')),
      'Bandung',
    );
    await tester.enterText(
      find.byKey(const Key('job-form-description')),
      'Membangun aplikasi mobile bersama tim produk.',
    );
    await tester.tap(find.byKey(const Key('job-form-submit')));
    await tester.pumpAndSettle();

    expect(service.createCalls, 1);
    expect(find.byType(JobFormPage), findsNothing);
    expect(find.text('Flutter Developer'), findsOneWidget);
    expect(find.textContaining('berhasil dibuat'), findsOneWidget);
  });

  testWidgets('Recruiter dapat mengubah lowongan miliknya', (
    WidgetTester tester,
  ) async {
    _setSurfaceSize(tester);

    final service = _FakeJobService([
      _job(id: 3, recruiterId: 42, title: 'Backend Developer'),
    ]);

    await _pumpHome(tester, user: _recruiter(), jobService: service);

    await tester.tap(find.byKey(const Key('job-3-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ubah'));
    await tester.pumpAndSettle();

    expect(find.byType(JobFormPage), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('job-form-title')),
      'Senior Backend Developer',
    );
    await tester.tap(find.byKey(const Key('job-form-submit')));
    await tester.pumpAndSettle();

    expect(service.updateCalls, 1);
    expect(find.text('Senior Backend Developer'), findsOneWidget);
  });

  testWidgets('Recruiter dapat menghapus lowongan setelah konfirmasi', (
    WidgetTester tester,
  ) async {
    _setSurfaceSize(tester);

    final service = _FakeJobService([
      _job(id: 3, recruiterId: 42, title: 'Backend Developer'),
    ]);

    await _pumpHome(tester, user: _recruiter(), jobService: service);

    await tester.tap(find.byKey(const Key('job-3-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();

    expect(find.text('Hapus lowongan?'), findsOneWidget);
    expect(service.deleteCalls, 0);

    await tester.tap(find.byKey(const Key('confirm-delete-job-button')));
    await tester.pumpAndSettle();

    expect(service.deleteCalls, 1);
    expect(find.text('Backend Developer'), findsNothing);
  });

  testWidgets('Recruiter tidak dapat mengubah lowongan milik recruiter lain', (
    WidgetTester tester,
  ) async {
    _setSurfaceSize(tester);

    final service = _FakeJobService([
      _job(id: 5, recruiterId: 7, title: 'Data Analyst'),
    ]);

    await _pumpHome(tester, user: _recruiter(), jobService: service);

    expect(find.text('Data Analyst'), findsOneWidget);
    expect(find.byKey(const Key('job-5-menu')), findsNothing);
  });

  testWidgets('Jobseeker tidak melihat tombol kelola lowongan', (
    WidgetTester tester,
  ) async {
    _setSurfaceSize(tester);

    final service = _FakeJobService([
      _job(id: 3, recruiterId: 42, title: 'Backend Developer'),
    ]);

    await _pumpHome(tester, user: _jobseeker(), jobService: service);

    expect(find.byKey(const Key('jobs-create-button')), findsNothing);
    expect(find.byKey(const Key('job-3-menu')), findsNothing);
  });
}
