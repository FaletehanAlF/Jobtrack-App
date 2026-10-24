// Tes dasar untuk halaman onboarding dan alur navigasi autentikasi JobTrack.
//
// Memastikan aplikasi berhasil dibangun, elemen utama onboarding tampil,
// dan tombol "Mulai Sekarang" serta "Masuk" membuka halaman register dan login.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/main.dart';
import 'package:frontend/pages/login_page.dart';
import 'package:frontend/pages/register_page.dart';

void main() {
  setUp(() {
    // Gerbang sesi membaca token dari perangkat. Mock kosong berarti
    // "belum pernah login", jadi pemeriksaan tidak menyentuh jaringan dan
    // aplikasi diarahkan ke onboarding seperti alur pengguna baru.
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Onboarding menampilkan nama aplikasi, judul, dan tombol', (
    WidgetTester tester,
  ) async {
    // Bangun aplikasi: frame pertama adalah indikator pemeriksaan sesi.
    await tester.pumpWidget(const JobTrackApp());

    // Dua kali pump: mengalirkan pemeriksaan sesi (tanpa token) dan
    // menyelesaikan transisi menuju onboarding. pumpAndSettle tidak dipakai
    // di sini karena tunda indikatornya berputar tanpa henti.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Nama aplikasi muncul di tengah layar.
    expect(find.text('JobTrack'), findsOneWidget);

    // Tombol utama tersedia untuk pengguna.
    expect(find.text('Mulai Sekarang'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);
  });

  testWidgets('Tombol Mulai Sekarang membuka halaman register', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const JobTrackApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Mulai Sekarang'));
    await tester.pumpAndSettle();

    // Halaman register tampil dengan tiga field-nya.
    expect(find.byType(RegisterPage), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });

  testWidgets('Tautan Masuk membuka halaman login', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const JobTrackApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();

    // Halaman login tampil: ada judulnya, field email, dan tombol Masuk.
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });
}