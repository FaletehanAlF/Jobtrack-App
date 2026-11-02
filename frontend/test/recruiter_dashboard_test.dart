import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/models/application_model.dart';
import 'package:frontend/models/job_model.dart';
import 'package:frontend/models/recruiter_model.dart';
import 'package:frontend/models/user_model.dart';
import 'package:frontend/pages/home_page.dart';
import 'package:frontend/pages/recruiter_dashboard_page.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/application_service.dart';
import 'package:frontend/services/job_service.dart';
import 'package:frontend/services/recruiter_service.dart';

class _FakeJobService extends JobService {
  @override
  Future<List<JobModel>> fetchJobs() async => const [];
}

class _FakeApplicationService extends ApplicationService {
  @override
  Future<List<ApplicationModel>> fetchApplications() async => const [];
}

class _FakeRecruiterService extends RecruiterService {
  _FakeRecruiterService({
    this.dashboard,
    this.applicants = const [],
    this.dashboardError,
    this.applicantsError,
    this.updateError,
  });

  RecruiterDashboardData? dashboard;
  List<RecruiterApplicantModel> applicants;
  int? total;
  Object? dashboardError;
  Object? applicantsError;
  Object? updateError;

  int dashboardCalls = 0;
  final List<Map<String, Object?>> applicantRequests = [];
  final List<Map<String, Object?>> updateRequests = [];

  @override
  Future<RecruiterDashboardData> fetchDashboard() async {
    dashboardCalls += 1;
    final error = dashboardError;
    if (error != null) throw error;
    return dashboard ??
        const RecruiterDashboardData(
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
    applicantRequests.add({
      'job_id': jobId,
      'status': status,
      'limit': limit,
      'offset': offset,
    });

    final error = applicantsError;
    if (error != null) throw error;

    return RecruiterApplicantsPageData(
      applicants: applicants,
      total: total ?? applicants.length,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<RecruiterApplicantModel> updateStatus({
    required int applicationId,
    required String status,
  }) async {
    updateRequests.add({'id': applicationId, 'status': status});

    final error = updateError;
    if (error != null) throw error;

    final original = applicants.firstWhere((item) => item.id == applicationId);
    final updated = RecruiterApplicantModel(
      id: original.id,
      status: status,
      createdAt: original.createdAt,
      applicantUsername: original.applicantUsername,
      job: original.job,
    );

    applicants = [
      for (final item in applicants)
        if (item.id == applicationId) updated else item,
    ];

    return updated;
  }
}

UserModel _recruiter() => UserModel(
  id: 42,
  username: 'rekruter',
  email: 'rekruter@example.com',
  role: 'recruiter',
  createdAt: DateTime(2020),
);

RecruiterJobStats _jobStats({
  int id = 3,
  String title = 'Backend Developer',
  int applicants = 4,
  int submitted = 3,
  int rejected = 1,
}) {
  return RecruiterJobStats(
    id: id,
    title: title,
    company: 'PT Gamma',
    location: 'Jakarta',
    createdAt: DateTime(2026, 10, 20),
    applicantCount: applicants,
    submittedCount: submitted,
    rejectedCount: rejected,
  );
}

RecruiterApplicantModel _applicant({
  required int id,
  String username = 'budi',
  String status = 'submitted',
  int jobId = 3,
  String jobTitle = 'Backend Developer',
}) {
  return RecruiterApplicantModel(
    id: id,
    status: status,
    createdAt: DateTime(2026, 10, 23),
    applicantUsername: username,
    job: ApplicationJob(
      id: jobId,
      title: jobTitle,
      company: 'PT Gamma',
      location: 'Jakarta',
    ),
  );
}

void _setSurfaceSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pumpRecruiterHome(
  WidgetTester tester,
  _FakeRecruiterService service,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: HomePage(
        user: _recruiter(),
        jobService: _FakeJobService(),
        recruiterService: service,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Dashboard recruiter menampilkan angka dari backend', (
    WidgetTester tester,
  ) async {
    _setSurfaceSize(tester, const Size(1280, 1000));

    final service = _FakeRecruiterService(
      dashboard: RecruiterDashboardData(
        stats: const RecruiterDashboardStats(
          jobs: 2,
          applicants: 7,
          submitted: 5,
          rejected: 2,
        ),
        jobs: [
          _jobStats(id: 3, applicants: 4, submitted: 3, rejected: 1),
          _jobStats(
            id: 4,
            title: 'Flutter Developer',
            applicants: 3,
            submitted: 2,
            rejected: 1,
          ),
        ],
      ),
    );

    await _pumpRecruiterHome(tester, service);

    expect(
      tester.widget<Text>(find.byKey(const Key('recruiter-stat-jobs'))).data,
      '2',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('recruiter-stat-applicants')))
          .data,
      '7',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('recruiter-stat-submitted')))
          .data,
      '5',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('recruiter-stat-rejected')))
          .data,
      '2',
    );

    expect(find.byType(RecruiterDashboardPage), findsOneWidget);
    expect(find.text('Backend Developer'), findsOneWidget);
    expect(find.text('Flutter Developer'), findsOneWidget);
    expect(find.text('4 pelamar'), findsOneWidget);
    expect(find.text('3 pelamar'), findsOneWidget);
  });

  testWidgets('Dashboard kosong menampilkan empty state, bukan angka palsu', (
    WidgetTester tester,
  ) async {
    _setSurfaceSize(tester, const Size(1280, 1000));

    await _pumpRecruiterHome(tester, _FakeRecruiterService());

    expect(find.byKey(const Key('recruiter-dashboard-empty')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('recruiter-stat-jobs'))).data,
      '0',
    );
  });

  testWidgets('Error dashboard menampilkan pesan dan tombol coba lagi', (
    WidgetTester tester,
  ) async {
    _setSurfaceSize(tester, const Size(1280, 1000));

    final service = _FakeRecruiterService(
      dashboardError: ApiException(500, 'Terjadi kesalahan pada server'),
    );

    await _pumpRecruiterHome(tester, service);

    expect(find.text('Terjadi kesalahan pada server'), findsOneWidget);
    expect(find.text('Coba Lagi'), findsOneWidget);

    final callsBefore = service.dashboardCalls;
    await tester.tap(find.text('Coba Lagi').first);
    await tester.pumpAndSettle();

    expect(service.dashboardCalls, greaterThan(callsBefore));
  });

  testWidgets(
    'Tombol Lihat pelamar membuka tab Pelamar dengan filter lowongan',
    (WidgetTester tester) async {
      _setSurfaceSize(tester, const Size(1280, 1000));

      final service = _FakeRecruiterService(
        dashboard: RecruiterDashboardData(
          stats: const RecruiterDashboardStats(
            jobs: 1,
            applicants: 1,
            submitted: 1,
            rejected: 0,
          ),
          jobs: [_jobStats(id: 3)],
        ),
        applicants: [_applicant(id: 9)],
      );

      await _pumpRecruiterHome(tester, service);

      await tester.tap(find.byKey(const Key('recruiter-job-3-open')));
      await tester.pumpAndSettle();

      expect(service.applicantRequests.last['job_id'], 3);
      expect(find.text('budi'), findsOneWidget);
    },
  );

  testWidgets('Filter status diteruskan ke backend, bukan disaring di UI', (
    WidgetTester tester,
  ) async {
    _setSurfaceSize(tester, const Size(1280, 1000));

    final service = _FakeRecruiterService(
      dashboard: RecruiterDashboardData(
        stats: const RecruiterDashboardStats(
          jobs: 1,
          applicants: 2,
          submitted: 1,
          rejected: 1,
        ),
        jobs: [_jobStats(id: 3)],
      ),
      applicants: [
        _applicant(id: 9, status: 'submitted'),
        _applicant(id: 10, username: 'siti', status: 'rejected'),
      ],
    );

    await _pumpRecruiterHome(tester, service);

    await tester.tap(find.text('Pelamar'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('recruiter-filter-status')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ditolak').last);
    await tester.pumpAndSettle();

    expect(service.applicantRequests.last['status'], 'rejected');
  });

  testWidgets('Menolak lamaran memanggil backend dan memperbarui kartu', (
    WidgetTester tester,
  ) async {
    _setSurfaceSize(tester, const Size(1280, 1000));

    final service = _FakeRecruiterService(
      applicants: [_applicant(id: 9, status: 'submitted')],
    );

    await _pumpRecruiterHome(tester, service);

    await tester.tap(find.text('Pelamar'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('recruiter-9-reject')));
    await tester.pumpAndSettle();

    expect(service.updateRequests, [
      {'id': 9, 'status': 'rejected'},
    ]);

    expect(find.text('Ditolak'), findsWidgets);
    expect(find.byKey(const Key('recruiter-9-restore')), findsOneWidget);
    expect(find.byKey(const Key('recruiter-9-reject')), findsNothing);
  });

  testWidgets('Gagal mengubah status menampilkan pesan error', (
    WidgetTester tester,
  ) async {
    _setSurfaceSize(tester, const Size(1280, 1000));

    final service = _FakeRecruiterService(
      applicants: [_applicant(id: 9, status: 'submitted')],
      updateError: ApiException(404, 'Lamaran tidak ditemukan'),
    );

    await _pumpRecruiterHome(tester, service);

    await tester.tap(find.text('Pelamar'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('recruiter-9-reject')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Lamaran tidak ditemukan'), findsOneWidget);
  });

  testWidgets('Daftar pelamar kosong menampilkan empty state', (
    WidgetTester tester,
  ) async {
    _setSurfaceSize(tester, const Size(1280, 1000));

    await _pumpRecruiterHome(tester, _FakeRecruiterService());

    await tester.tap(find.text('Pelamar'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('recruiter-empty')), findsOneWidget);
    expect(find.text('Belum ada pelamar'), findsOneWidget);
  });

  testWidgets('Error daftar pelamar menampilkan tombol coba lagi', (
    WidgetTester tester,
  ) async {
    _setSurfaceSize(tester, const Size(1280, 1000));

    final service = _FakeRecruiterService(
      applicantsError: ApiException(0, 'Tidak dapat terhubung ke server.'),
    );

    await _pumpRecruiterHome(tester, service);

    await tester.tap(find.text('Pelamar'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Tidak dapat terhubung ke server'),
      findsOneWidget,
    );
    expect(find.text('Coba Lagi'), findsWidgets);
  });

  testWidgets('Dashboard recruiter responsif di mobile dan web', (
    WidgetTester tester,
  ) async {
    final service = _FakeRecruiterService(
      dashboard: RecruiterDashboardData(
        stats: const RecruiterDashboardStats(
          jobs: 2,
          applicants: 7,
          submitted: 5,
          rejected: 2,
        ),
        jobs: [
          _jobStats(id: 3, applicants: 4, submitted: 3, rejected: 1),
          _jobStats(
            id: 4,
            title: 'Flutter Developer',
            applicants: 3,
            submitted: 2,
            rejected: 1,
          ),
        ],
      ),
    );

    _setSurfaceSize(tester, const Size(360, 780));
    await _pumpRecruiterHome(tester, service);

    final mobileFirst = tester.getTopLeft(find.text('Backend Developer'));
    final mobileSecond = tester.getTopLeft(find.text('Flutter Developer'));
    expect(mobileFirst.dx, mobileSecond.dx);
    expect(mobileSecond.dy, greaterThan(mobileFirst.dy));

    _setSurfaceSize(tester, const Size(1280, 1000));
    await _pumpRecruiterHome(tester, service);

    final webFirst = tester.getTopLeft(find.text('Backend Developer'));
    final webSecond = tester.getTopLeft(find.text('Flutter Developer'));
    expect(webSecond.dx, greaterThan(webFirst.dx));
    expect(webSecond.dy, closeTo(webFirst.dy, 1));
  });

  testWidgets('Jobseeker tidak melihat menu recruiter', (
    WidgetTester tester,
  ) async {
    _setSurfaceSize(tester, const Size(1280, 1000));

    final jobseeker = UserModel(
      id: 1,
      username: 'tester',
      email: 'tester@example.com',
      role: 'jobseeker',
      createdAt: DateTime(2020),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          user: jobseeker,
          jobService: _FakeJobService(),
          applicationService: _FakeApplicationService(),
          recruiterService: _FakeRecruiterService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pelamar'), findsNothing);
    expect(find.text('Tersimpan'), findsOneWidget);
  });
}
