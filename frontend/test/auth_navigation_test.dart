// Tes perilaku tombol Back setelah login dan logout.
//
// Bug yang dijaga di sini: setelah login berhasil, menekan Back (tombol Back
// browser di Flutter Web, atau tombol sistem Android) mengembalikan pengguna
// ke halaman Login meskipun sesinya masih valid.
//
// Penyebabnya ada di susunan rute, bukan di tombol Back itu sendiri. Alur
// autentikasi menumpuk rute dengan `Navigator.push`:
//
//   onboarding (akar) → login → register → login → ...
//
// Setelah login berhasil, `pushReplacement` hanya mengganti rute paling atas.
// Rute auth di bawahnya (onboarding, login sebelumnya, register) tetap
// tinggal di stack, sehingga Back berjalan mundur ke rute-rute itu — dan dari
// sana pengguna bisa membuka form Login lagi walau sudah masuk.
//
// Tes di bawah membangun susunan rute yang sama seperti aplikasi sebenarnya,
// lalu menekan Back lewat `handlePopRoute()` — jalur yang dipakai tombol Back
// browser Flutter Web maupun tombol sistem Android.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/models/application_model.dart';
import 'package:frontend/models/job_model.dart';
import 'package:frontend/models/user_model.dart';
import 'package:frontend/pages/home_page.dart';
import 'package:frontend/pages/login_page.dart';
import 'package:frontend/pages/onboarding_screen.dart';
import 'package:frontend/pages/register_page.dart';
import 'package:frontend/services/application_service.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/services/job_service.dart';

/// AuthService palsu: tidak menyentuh jaringan.
class _FakeAuthService extends AuthService {
  _FakeAuthService({this.loginResult, this.currentUser, this.loginError});

  /// Hasil login yang berhasil. Null berarti login ditolak.
  final UserModel? loginResult;

  /// Hasil `GET /auth/me`. Null berarti sesi tidak berlaku.
  final UserModel? currentUser;

  /// Bila diisi, login melempar error ini (mis. ApiException 401).
  final Object? loginError;

  int loginCalls = 0;
  int logoutCalls = 0;

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    loginCalls += 1;
    final error = loginError;
    if (error != null) throw error;
    final result = loginResult;
    if (result == null) throw Exception('Email atau password salah');
    return result;
  }

  @override
  Future<UserModel?> getCurrentUser() async => currentUser;

  @override
  Future<void> logout() async {
    logoutCalls += 1;
  }
}

class _EmptyJobService extends JobService {
  @override
  Future<List<JobModel>> fetchJobs() async => [];
}

class _EmptyApplicationService extends ApplicationService {
  @override
  Future<List<ApplicationModel>> fetchApplications() async => [];
}

final _user = UserModel(
  id: 1,
  username: 'tester',
  email: 'tester@example.com',
  role: 'jobseeker',
  createdAt: DateTime(2020),
);

/// Viewport tes default (800x600) terlalu pendek untuk kartu auth, sehingga
/// tombol submit berada di luar layar dan ketukan tidak mengenai apa pun.
void _useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// Membangun susunan rute yang sama dengan aplikasi sebenarnya: onboarding
/// sebagai rute akar, lalu login di-push di atasnya.
///
/// `JobTrackApp._openLogin` melakukan persis ini — `Navigator.push` ke
/// [LoginPage] dari konteks rute onboarding.
Future<_FakeAuthService> _pumpOnboardingThenLogin(
  WidgetTester tester, {
  UserModel? loginResult,
  Object? loginError,
}) async {
  final authService = _FakeAuthService(
    loginResult: loginResult,
    loginError: loginError,
  );
  final navigatorKey = GlobalKey<NavigatorState>();

  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      home: OnboardingScreen(
        onLogin: () => navigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (_) => LoginPage(
              authService: authService,
              jobService: _EmptyJobService(),
              applicationService: _EmptyApplicationService(),
            ),
          ),
        ),
        onSignUp: () {},
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.ensureVisible(find.text('Masuk'));
  await tester.tap(find.text('Masuk'));
  await tester.pumpAndSettle();

  return authService;
}

/// Mengisi form login lalu menekan tombol Masuk.
Future<void> _submitLogin(WidgetTester tester) async {
  await tester.enterText(
    find.byType(TextFormField).first,
    'tester@example.com',
  );
  await tester.enterText(find.byType(TextFormField).last, 'rahasia123');
  await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Masuk'));
  await tester.tap(find.widgetWithText(ElevatedButton, 'Masuk'));
  await tester.pumpAndSettle();
}

/// Menekan tombol Back: jalur yang sama dengan Back browser dan tombol sistem.
Future<void> _pressBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Setelah login, Back tidak kembali ke halaman Login', (
    WidgetTester tester,
  ) async {
    _useTallViewport(tester);

    final authService = await _pumpOnboardingThenLogin(
      tester,
      loginResult: _user,
    );

    await _submitLogin(tester);

    // Login berhasil: shell utama tampil, satu request saja.
    expect(find.byType(HomePage), findsOneWidget);
    expect(authService.loginCalls, 1);

    await _pressBack(tester);

    // Inti perbaikan: riwayat auth tidak boleh tersisa di bawah Home.
    expect(
      find.byType(LoginPage),
      findsNothing,
      reason: 'Back setelah login tidak boleh membuka halaman Login',
    );
    expect(
      find.byType(OnboardingScreen),
      findsNothing,
      reason: 'Back setelah login tidak boleh membuka onboarding',
    );
    expect(
      find.byType(HomePage),
      findsOneWidget,
      reason: 'Pengguna dengan sesi valid harus tetap di shell utama',
    );
  });

  testWidgets('Setelah logout, Back tidak membuka Home yang terlindungi', (
    WidgetTester tester,
  ) async {
    _useTallViewport(tester);

    final authService = await _pumpOnboardingThenLogin(
      tester,
      loginResult: _user,
    );

    await _submitLogin(tester);
    expect(find.byType(HomePage), findsOneWidget);

    // Logout hanya lewat tindakan eksplisit pengguna di tab Profil.
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();

    expect(authService.logoutCalls, 1);
    expect(find.byType(HomePage), findsNothing);
    expect(find.byType(LoginPage), findsOneWidget);

    await _pressBack(tester);

    expect(
      find.byType(HomePage),
      findsNothing,
      reason: 'Back setelah logout tidak boleh membuka Home terlindungi',
    );
  });

  testWidgets('Login gagal menampilkan pesan dan tetap di halaman Login', (
    WidgetTester tester,
  ) async {
    _useTallViewport(tester);

    // loginResult null berarti backend menolak kredensial.
    await _pumpOnboardingThenLogin(tester);

    await _submitLogin(tester);

    expect(find.byType(HomePage), findsNothing);
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.textContaining('Email atau password salah'), findsOneWidget);
  });

  testWidgets('Back dari Login kembali ke onboarding, bukan menutup aplikasi', (
    WidgetTester tester,
  ) async {
    _useTallViewport(tester);

    // Perilaku normal yang harus tetap berfungsi: sebelum login, Back dari
    // form login memang seharusnya kembali ke onboarding.
    await _pumpOnboardingThenLogin(tester, loginResult: _user);

    expect(find.byType(LoginPage), findsOneWidget);

    await _pressBack(tester);

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
  });

  testWidgets('Sesi tidak valid diarahkan ke Login', (
    WidgetTester tester,
  ) async {
    _useTallViewport(tester);

    final navigatorKey = GlobalKey<NavigatorState>();

    // HomePage tanpa data user akan memeriksa sesi lewat GET /auth/me.
    // currentUser null berarti token tidak berlaku.
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: HomePage(
          authService: _FakeAuthService(currentUser: null),
          jobService: _EmptyJobService(),
          applicationService: _EmptyApplicationService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);

    // Halaman Login hasil pengalihan ini adalah satu-satunya rute, jadi Back
    // tidak bisa kembali ke Home yang tidak sah.
    expect(navigatorKey.currentState!.canPop(), isFalse);
  });

  testWidgets('Navigasi internal Home tetap berfungsi dan tidak memicu Login', (
    WidgetTester tester,
  ) async {
    _useTallViewport(tester);

    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: HomePage(
          user: _user,
          authService: _FakeAuthService(currentUser: _user),
          jobService: _EmptyJobService(),
          applicationService: _EmptyApplicationService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Berpindah tab tidak menumpuk rute dan tidak mengarahkan ke Login.
    await tester.tap(find.text('Lowongan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lamaran'));
    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
    expect(navigatorKey.currentState!.canPop(), isFalse);

    // Back pada shell utama tidak menutup sesi pengguna.
    await _pressBack(tester);
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
  });
}
