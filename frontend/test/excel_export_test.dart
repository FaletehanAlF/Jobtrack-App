import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/models/application_model.dart';
import 'package:frontend/models/job_model.dart';
import 'package:frontend/models/recruiter_model.dart';
import 'package:frontend/models/user_model.dart';
import 'package:frontend/pages/applications_page.dart';
import 'package:frontend/pages/home_page.dart';
import 'package:frontend/pages/recruiter_applicants_page.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/application_service.dart';
import 'package:frontend/services/job_service.dart';
import 'package:frontend/services/recruiter_service.dart';

class _FakeJobService extends JobService {
  @override
  Future<List<JobModel>> fetchJobs() async => const [];
}

/// RecruiterService palsu untuk HomePage: dashboard dan daftar pelamar
/// sekarang diambil lewat service ini, bukan ApplicationService.
class _FakeRecruiterService extends RecruiterService {
  _FakeRecruiterService({this.applicants = const []});

  final List<RecruiterApplicantModel> applicants;
  int dashboardCalls = 0;
  int applicantsCalls = 0;

  @override
  Future<RecruiterDashboardData> fetchDashboard() async {
    dashboardCalls += 1;
    return RecruiterDashboardData(
      stats: RecruiterDashboardStats.empty,
      jobs: const [],
    );
  }

  @override
  Future<RecruiterApplicantsPageData> fetchApplicants({
    int? jobId,
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    applicantsCalls += 1;
    return RecruiterApplicantsPageData(
      applicants: applicants,
      total: applicants.length,
      limit: limit,
      offset: offset,
    );
  }
}

class _FakeApplicationService extends ApplicationService {
  _FakeApplicationService({
    this.applications = const [],
    this.applicants = const [],
    this.exportError,
  });

  final List<ApplicationModel> applications;
  final List<RecruiterApplicantModel> applicants;
  final Object? exportError;
  int jobseekerFetchCalls = 0;
  int recruiterFetchCalls = 0;
  int jobseekerExportCalls = 0;
  int recruiterExportCalls = 0;

  @override
  Future<List<ApplicationModel>> fetchApplications() async {
    jobseekerFetchCalls += 1;
    return applications;
  }

  @override
  Future<List<RecruiterApplicantModel>> fetchRecruiterApplicants() async {
    recruiterFetchCalls += 1;
    return applicants;
  }

  @override
  Future<ApiDownload> exportApplications() async {
    jobseekerExportCalls += 1;
    if (exportError != null) throw exportError!;
    return _download('laporan_lamaran_2026-10-26.xlsx');
  }

  @override
  Future<ApiDownload> exportRecruiterApplicants() async {
    recruiterExportCalls += 1;
    if (exportError != null) throw exportError!;
    return _download('laporan_pelamar_2026-10-26.xlsx');
  }
}

class _PendingExportService extends ApplicationService {
  final Completer<ApiDownload> completer = Completer<ApiDownload>();

  @override
  Future<ApiDownload> exportApplications() => completer.future;
}

ApiDownload _download(String fileName) {
  return ApiDownload(
    bytes: Uint8List.fromList([80, 75, 3, 4]),
    fileName: fileName,
    contentType:
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  );
}

UserModel _user({required String role}) {
  return UserModel(
    id: 1,
    username: role == 'recruiter' ? 'recruiter' : 'tester',
    email: '$role@example.com',
    role: role,
    createdAt: DateTime(2020),
  );
}

ApplicationModel _application({required int id, required String status}) {
  return ApplicationModel(
    id: id,
    jobId: id,
    status: status,
    createdAt: DateTime(2026, 10, 21),
    job: ApplicationJob(
      id: id,
      title: 'Flutter Developer $id',
      company: 'PT Contoh',
      location: 'Jakarta',
    ),
  );
}

RecruiterApplicantModel _applicant({
  required int id,
  required String username,
  required String status,
}) {
  return RecruiterApplicantModel(
    id: id,
    status: status,
    createdAt: DateTime(2026, 10, 22),
    applicantUsername: username,
    job: ApplicationJob(
      id: id,
      title: 'Backend Developer $id',
      company: 'PT Gamma',
      location: 'Bandung',
    ),
  );
}

Widget _applicationsPage({
  required List<ApplicationModel> applications,
  required ApplicationService service,
  Future<void> Function(ApiDownload file)? downloadHandler,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ApplicationsPage(
        applications: applications,
        loading: false,
        error: null,
        canView: true,
        onRefresh: () async {},
        onOpenApplication: (_) {},
        onShowJobs: () {},
        applicationService: service,
        downloadHandler: downloadHandler ?? (file) async {},
      ),
    ),
  );
}

Widget _recruiterPage({
  required List<RecruiterApplicantModel> applicants,
  required ApplicationService service,
  Future<void> Function(ApiDownload file)? downloadHandler,
}) {
  return MaterialApp(
    home: Scaffold(
      body: RecruiterApplicantsPage(
        applicants: applicants,
        loading: false,
        error: null,
        onRefresh: () async {},
        applicationService: service,
        downloadHandler: downloadHandler ?? (file) async {},
      ),
    ),
  );
}

void main() {
  testWidgets('jobseeker dapat mengekspor laporan lamaran dari riwayat', (
    WidgetTester tester,
  ) async {
    _setSurfaceSize(tester, const Size(900, 900));

    final service = _FakeApplicationService(
      applications: [
        _application(id: 1, status: 'submitted'),
        _application(id: 2, status: 'rejected'),
      ],
    );
    final downloads = <ApiDownload>[];

    await tester.pumpWidget(
      _applicationsPage(
        applications: service.applications,
        service: service,
        downloadHandler: (file) async => downloads.add(file),
      ),
    );

    await tester.tap(find.byKey(const Key('jobseeker-export-button')));
    await tester.pumpAndSettle();

    expect(service.jobseekerExportCalls, 1);
    expect(downloads.single.fileName, 'laporan_lamaran_2026-10-26.xlsx');
    expect(find.text('Laporan lamaran berhasil diunduh.'), findsOneWidget);
  });

  testWidgets('tombol ekspor jobseeker nonaktif saat belum ada lamaran', (
    WidgetTester tester,
  ) async {
    _setSurfaceSize(tester, const Size(900, 900));

    await tester.pumpWidget(
      _applicationsPage(
        applications: const [],
        service: _FakeApplicationService(),
      ),
    );

    final button = tester.widget<OutlinedButton>(
      find.byKey(const Key('jobseeker-export-button')),
    );

    expect(button.onPressed, isNull);
    expect(find.text('Belum ada lamaran'), findsOneWidget);
  });

  testWidgets('status loading ekspor terlihat sampai file siap', (
    WidgetTester tester,
  ) async {
    _setSurfaceSize(tester, const Size(900, 900));

    final service = _PendingExportService();
    final downloads = <ApiDownload>[];

    await tester.pumpWidget(
      _applicationsPage(
        applications: [_application(id: 1, status: 'submitted')],
        service: service,
        downloadHandler: (file) async => downloads.add(file),
      ),
    );

    await tester.tap(find.byKey(const Key('jobseeker-export-button')));
    await tester.pump();

    expect(find.text('Menyiapkan...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    service.completer.complete(_download('laporan_lamaran.xlsx'));
    await tester.pumpAndSettle();

    expect(downloads, hasLength(1));
    expect(find.text('Laporan lamaran berhasil diunduh.'), findsOneWidget);
  });

  testWidgets('kegagalan ekspor ditampilkan sebagai pesan error', (
    WidgetTester tester,
  ) async {
    _setSurfaceSize(tester, const Size(900, 900));

    final service = _FakeApplicationService(
      applications: [_application(id: 1, status: 'submitted')],
      exportError: ApiException(500, 'Gagal membuat laporan'),
    );

    await tester.pumpWidget(
      _applicationsPage(applications: service.applications, service: service),
    );

    await tester.tap(find.byKey(const Key('jobseeker-export-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Gagal mengekspor laporan'), findsOneWidget);
  });

  testWidgets('recruiter dapat mengekspor laporan pelamar miliknya', (
    WidgetTester tester,
  ) async {
    _setSurfaceSize(tester, const Size(900, 900));

    final applicants = [
      _applicant(id: 1, username: 'budi', status: 'submitted'),
      _applicant(id: 2, username: 'sari', status: 'rejected'),
    ];
    final service = _FakeApplicationService(applicants: applicants);
    final downloads = <ApiDownload>[];

    await tester.pumpWidget(
      _recruiterPage(
        applicants: applicants,
        service: service,
        downloadHandler: (file) async => downloads.add(file),
      ),
    );

    expect(find.text('budi'), findsOneWidget);
    expect(find.text('sari'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('recruiter-stat-total')),
        matching: find.text('Total 2'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('recruiter-export-button')));
    await tester.pumpAndSettle();

    expect(service.recruiterExportCalls, 1);
    expect(downloads.single.fileName, 'laporan_pelamar_2026-10-26.xlsx');
    expect(find.text('Laporan pelamar berhasil diunduh.'), findsOneWidget);
  });

  testWidgets('tombol ekspor recruiter nonaktif saat belum ada pelamar', (
    WidgetTester tester,
  ) async {
    _setSurfaceSize(tester, const Size(900, 900));

    await tester.pumpWidget(
      _recruiterPage(applicants: const [], service: _FakeApplicationService()),
    );

    final button = tester.widget<OutlinedButton>(
      find.byKey(const Key('recruiter-export-button')),
    );

    expect(button.onPressed, isNull);
    expect(find.byKey(const Key('recruiter-empty')), findsOneWidget);
  });

  testWidgets(
    'home recruiter memakai endpoint pelamar, bukan endpoint jobseeker',
    (WidgetTester tester) async {
      _setSurfaceSize(tester, const Size(1280, 900));

      final applicants = [
        _applicant(id: 1, username: 'budi', status: 'submitted'),
      ];
      final service = _FakeApplicationService(applicants: applicants);
      final recruiterService = _FakeRecruiterService(applicants: applicants);

      await tester.pumpWidget(
        MaterialApp(
          home: HomePage(
            user: _user(role: 'recruiter'),
            jobService: _FakeJobService(),
            applicationService: service,
            recruiterService: recruiterService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tab Pelamar ada di navigasi recruiter, dan datanya dari
      // RecruiterService (bukan endpoint jobseeker).
      expect(find.text('Pelamar'), findsOneWidget);
      expect(find.text('Tersimpan'), findsNothing);
      expect(recruiterService.dashboardCalls, 1);
      expect(recruiterService.applicantsCalls, 1);
      expect(service.jobseekerFetchCalls, 0);
      expect(service.recruiterFetchCalls, 0);

      // Empat tab recruiter: Dashboard, Lowongan, Pelamar, Profil.
      expect(
        tester.widget<IndexedStack>(find.byType(IndexedStack)).children.length,
        4,
      );

      // Pindah ke tab Pelamar lalu pastikan pelamarnya tampil.
      await tester.tap(find.text('Pelamar'));
      await tester.pumpAndSettle();
      expect(find.byType(RecruiterApplicantsPage), findsOneWidget);
      expect(find.text('budi'), findsOneWidget);
    },
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
