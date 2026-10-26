import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/models/application_model.dart';
import 'package:frontend/models/job_model.dart';
import 'package:frontend/models/user_model.dart';
import 'package:frontend/pages/applications_page.dart';
import 'package:frontend/pages/home_page.dart';
import 'package:frontend/pages/home_tab.dart';
import 'package:frontend/pages/jobs_page.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/application_service.dart';
import 'package:frontend/services/job_service.dart';
import 'package:frontend/widgets/application_widgets.dart';

class _FakeJobService extends JobService {
  _FakeJobService(this.jobs);

  final List<JobModel> jobs;
  int calls = 0;

  @override
  Future<List<JobModel>> fetchJobs() async {
    calls += 1;
    return jobs;
  }
}

class _FakeApplicationService extends ApplicationService {
  _FakeApplicationService(this.applications);

  final List<ApplicationModel> applications;
  int calls = 0;

  @override
  Future<List<ApplicationModel>> fetchApplications() async {
    calls += 1;
    return applications;
  }
}

class _FailingApplicationService extends ApplicationService {
  @override
  Future<List<ApplicationModel>> fetchApplications() async {
    throw ApiException(500, 'Gagal memuat lamaran');
  }
}

UserModel _user() {
  return UserModel(
    id: 1,
    username: 'tester',
    email: 'tester@example.com',
    role: 'jobseeker',
    createdAt: DateTime(2020),
  );
}

JobModel _job({
  required int id,
  required String title,
  required String company,
  required String location,
}) {
  return JobModel(
    id: id,
    recruiterId: 2,
    title: title,
    description: 'Deskripsi $title',
    company: company,
    location: location,
    createdAt: DateTime(2026, 10, 20),
    updatedAt: DateTime(2026, 10, 20),
  );
}

ApplicationModel _application({
  required int id,
  required int jobId,
  required String title,
  required String status,
}) {
  return ApplicationModel(
    id: id,
    jobId: jobId,
    status: status,
    createdAt: DateTime(2026, 10, 21),
    job: ApplicationJob(
      id: jobId,
      title: title,
      company: 'PT Contoh',
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

void main() {
  testWidgets(
    'dashboard menampilkan ringkasan dan data lamaran milik pengguna',
    (WidgetTester tester) async {
      _setSurfaceSize(tester, const Size(1280, 900));

      final jobs = [
        _job(
          id: 1,
          title: 'Flutter Developer',
          company: 'PT Alpha',
          location: 'Jakarta',
        ),
        _job(
          id: 2,
          title: 'Data Analyst',
          company: 'PT Beta',
          location: 'Bandung',
        ),
      ];
      final applications = [
        _application(
          id: 10,
          jobId: 1,
          title: 'Flutter Developer',
          status: 'submitted',
        ),
        _application(
          id: 11,
          jobId: 2,
          title: 'Data Analyst',
          status: 'rejected',
        ),
        _application(
          id: 12,
          jobId: 1,
          title: 'Flutter Developer',
          status: 'submitted',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: HomePage(
            user: _user(),
            jobService: _FakeJobService(jobs),
            applicationService: _FakeApplicationService(applications),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(const Key('dashboard-stat-total'))).data,
        '3',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('dashboard-stat-submitted')))
            .data,
        '2',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('dashboard-stat-rejected')))
            .data,
        '1',
      );

      expect(find.text('Lowongan terbaru'), findsOneWidget);
      expect(find.text('Lamaran terbaru'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(HomeTab),
          matching: find.byType(ApplicationCard),
        ),
        findsNWidgets(3),
      );
      expect(find.text('Flutter Developer'), findsWidgets);
      expect(find.text('Data Analyst'), findsWidgets);

      // Desktop memakai NavigationRail, bukan bottom navigation.
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsNothing);

      await tester.tap(find.byKey(const Key('dashboard-open-applications')));
      await tester.pumpAndSettle();

      expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 2);
      expect(find.byType(ApplicationsPage), findsOneWidget);
      expect(find.text('Riwayat lamaran'), findsOneWidget);
      expect(find.text('Dikirim'), findsWidgets);
      expect(find.text('Ditolak'), findsWidgets);
    },
  );

  testWidgets('lamaran terbaru dapat membuka detail lowongan', (
    WidgetTester tester,
  ) async {
    _setSurfaceSize(tester, const Size(1280, 900));

    final job = _job(
      id: 1,
      title: 'Flutter Developer',
      company: 'PT Alpha',
      location: 'Jakarta',
    );
    final application = _application(
      id: 10,
      jobId: 1,
      title: 'Flutter Developer',
      status: 'submitted',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          user: _user(),
          jobService: _FakeJobService([job]),
          applicationService: _FakeApplicationService([application]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find
          .descendant(
            of: find.byType(HomeTab),
            matching: find.byType(ApplicationCard),
          )
          .first,
    );
    await tester.pumpAndSettle();

    expect(find.byType(JobDetailPage), findsOneWidget);
    expect(find.text('Detail Lowongan'), findsOneWidget);
    expect(find.text('Deskripsi Flutter Developer'), findsOneWidget);
  });

  testWidgets('empty state lamaran mengarahkan ke daftar lowongan', (
    WidgetTester tester,
  ) async {
    _setSurfaceSize(tester, const Size(800, 900));

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          user: _user(),
          jobService: _FakeJobService([
            _job(
              id: 1,
              title: 'Flutter Developer',
              company: 'PT Alpha',
              location: 'Jakarta',
            ),
          ]),
          applicationService: _FakeApplicationService([]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Belum ada lamaran'), findsWidgets);
    expect(
      tester.widget<Text>(find.byKey(const Key('dashboard-stat-total'))).data,
      '0',
    );
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);

    await tester.ensureVisible(
      find.byKey(const Key('dashboard-empty-applications-cta')),
    );
    await tester.tap(find.byKey(const Key('dashboard-empty-applications-cta')));
    await tester.pumpAndSettle();

    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 1);
    expect(find.byType(JobsPage), findsOneWidget);
  });

  testWidgets('error endpoint lamaran tampil dengan tombol coba lagi', (
    WidgetTester tester,
  ) async {
    _setSurfaceSize(tester, const Size(1280, 900));

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          user: _user(),
          jobService: _FakeJobService([]),
          applicationService: _FailingApplicationService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gagal memuat lamaran'), findsWidgets);
    expect(find.text('Coba Lagi'), findsWidgets);
  });
}
