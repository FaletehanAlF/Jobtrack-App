import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/models/application_model.dart';
import 'package:frontend/models/job_model.dart';
import 'package:frontend/models/user_model.dart';
import 'package:frontend/pages/home_page.dart';
import 'package:frontend/pages/login_page.dart';
import 'package:frontend/pages/register_page.dart';
import 'package:frontend/services/application_service.dart';
import 'package:frontend/services/job_service.dart';

class _EmptyJobService extends JobService {
  @override
  Future<List<JobModel>> fetchJobs() async {
    return [];
  }
}

class _EmptyApplicationService extends ApplicationService {
  @override
  Future<List<ApplicationModel>> fetchApplications() async {
    return [];
  }
}

class _RecordingJobService extends JobService {
  @override
  Future<List<JobModel>> fetchJobs() async {
    calls += 1;
    return [];
  }

  int calls = 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Lowongan hanya dimuat satu kali di shell', (WidgetTester tester) async {
    final service = _RecordingJobService();
    final user = UserModel(
      id: 1,
      username: 'tester',
      email: 'tester@example.com',
      role: 'jobseeker',
      createdAt: DateTime(2020),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          user: user,
          jobService: service,
          applicationService: _EmptyApplicationService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lowongan'));
    await tester.pumpAndSettle();

    expect(service.calls, 1);
  });

  testWidgets('Logout membuka onboarding dan tombol Masuk membuka LoginPage', (
    WidgetTester tester,
  ) async {
    final user = UserModel(
      id: 1,
      username: 'tester',
      email: 'tester@example.com',
      role: 'jobseeker',
      createdAt: DateTime(2020),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          user: user,
          jobService: _EmptyJobService(),
          applicationService: _EmptyApplicationService(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();

    expect(find.text('Selamat Datang'), findsOneWidget);

    await tester.ensureVisible(find.text('Masuk'));
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('Logout membuka onboarding dan tombol Mulai Sekarang membuka RegisterPage', (
    WidgetTester tester,
  ) async {
    final user = UserModel(
      id: 1,
      username: 'tester',
      email: 'tester@example.com',
      role: 'jobseeker',
      createdAt: DateTime(2020),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          user: user,
          jobService: _EmptyJobService(),
          applicationService: _EmptyApplicationService(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();

    expect(find.text('Selamat Datang'), findsOneWidget);

    await tester.tap(find.text('Mulai Sekarang'));
    await tester.pumpAndSettle();

    expect(find.byType(RegisterPage), findsOneWidget);
  });
}
