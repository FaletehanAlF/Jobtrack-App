import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/models/application_model.dart';
import 'package:frontend/models/job_model.dart';
import 'package:frontend/models/user_model.dart';
import 'package:frontend/pages/home_page.dart';
import 'package:frontend/pages/login_page.dart';
import 'package:frontend/services/application_service.dart';
import 'package:frontend/services/auth_service.dart';
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

/// AuthService palsu: logout tidak menyentuh penyimpanan sungguhan.
class _FakeAuthService extends AuthService {
  int logoutCalls = 0;

  @override
  Future<void> logout() async {
    logoutCalls += 1;
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

final _user = UserModel(
  id: 1,
  username: 'tester',
  email: 'tester@example.com',
  role: 'jobseeker',
  createdAt: DateTime(2020),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Lowongan hanya dimuat satu kali di shell', (
    WidgetTester tester,
  ) async {
    final service = _RecordingJobService();

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          user: _user,
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

  testWidgets('Logout menghapus sesi dan membuka halaman Login', (
    WidgetTester tester,
  ) async {
    final authService = _FakeAuthService();

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          user: _user,
          authService: authService,
          jobService: _EmptyJobService(),
          applicationService: _EmptyApplicationService(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Keluar'));
    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();

    // Token dihapus lewat AuthService, lalu pengguna diarahkan ke Login.
    expect(authService.logoutCalls, 1);
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);
  });

  testWidgets('Setelah logout, riwayat dibersihkan sehingga Home tidak bisa '
      'dibuka lewat Back', (WidgetTester tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: HomePage(
          user: _user,
          authService: _FakeAuthService(),
          jobService: _EmptyJobService(),
          applicationService: _EmptyApplicationService(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Keluar'));
    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();

    // Login menjadi satu-satunya rute: tidak ada Home terlindungi di bawahnya.
    expect(navigatorKey.currentState!.canPop(), isFalse);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsNothing);
    expect(find.byType(LoginPage), findsOneWidget);
  });
}
