import 'package:flutter/material.dart';

import 'models/user_model.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'pages/onboarding_screen.dart';
import 'pages/register_page.dart';
import 'services/auth_service.dart';

void main() {
  runApp(const JobTrackApp());
}

class JobTrackApp extends StatelessWidget {
  const JobTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JobTrack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F9FB),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1F6FEB),
        ),
      ),
      // Halaman pertama adalah "gerbang sesi": sebelum menampilkan
      // onboarding, token tersimpan diperiksa lewat GET /auth/me.
      // Pengguna dengan sesi aktif langsung dibawa ke halaman utama
      // tanpa login ulang; pengguna lain tetap melihat onboarding.
      home: const _SessionGate(),
    );
  }

  static void _openLogin(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  static void _openRegister(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterPage()),
    );
  }
}

/// Gerbang sesi (persistent login).
///
/// Alur saat aplikasi dibuka:
/// 1. Tayangkan indikator loading singkat agar onboarding tidak muncul
///    sebentar lalu hilang.
/// 2. Periksa token tersimpan lewat [AuthService.getCurrentUser]. Token
///    diverifikasi server lewat `GET /auth/me`, bukan sekadar dilihat
///    apakah stringnya ada di perangkat.
/// 3. Token valid → halaman utama. Token tidak ada atau ditolak server
///    (401, token ikut dihapus) → onboarding. Pemeriksaan gagal karena
///    server tidak terjangkau → layar "Coba Lagi", karena token tidak
///    boleh dianggap valid hanya karena stringnya tersimpan.
///
/// Pemeriksaan berjalan satu kali dari [initState]; satu-satunya cara
/// memeriksa ulang adalah menekan tombol Coba Lagi. Token tidak pernah
/// ditampilkan maupun dicatat ke log.
class _SessionGate extends StatefulWidget {
  const _SessionGate();

  @override
  State<_SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<_SessionGate> {
  final _authService = AuthService();

  /// Berapa kali pemeriksaan dimulai. Dipakai untuk membuang hasil
  /// pemeriksaan lama yang selesai terlambat (mis. setelah Coba Lagi),
  /// supaya hasil basi tidak mengarahkan pengguna ke halaman yang salah.
  int _attempt = 0;

  /// True selama status sesi masih diperiksa.
  bool _checking = true;

  /// Pesan error untuk layar Coba Lagi. Null berarti layar itu tidak tampil.
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  /// Memeriksa sesi satu kali.
  ///
  /// Dipanggil dari initState (sekali per start aplikasi) dan dari tombol
  /// Coba Lagi — tidak pernah dipanggil berulang di belakang layar.
  Future<void> _checkSession() async {
    final attempt = ++_attempt;

    try {
      // Batas 10 detik: server yang "menggantung" tidak boleh membuat
      // pengguna menatap loading tanpa ujung. Kegagalan apa pun jatuh ke
      // catch di bawah dan tampil di layar Coba Lagi.
      final user = await _authService
          .getCurrentUser()
          .timeout(const Duration(seconds: 10));

      // mounted: gerbang bisa sudah tidak ada (mis. pengguna keluar aplikasi).
      // attempt: hasil ini basi bila pengguna sudah memicu pemeriksaan baru.
      if (!mounted || attempt != _attempt) return;

      if (user != null) {
        _openHome(user);
      } else {
        _openOnboarding();
      }
    } catch (error) {
      if (!mounted || attempt != _attempt) return;

      setState(() {
        _checking = false;
        _errorMessage = error.toString();
      });
    }
  }

  /// Menjalankan ulang pemeriksaan atas permintaan pengguna.
  void _retry() {
    if (_checking) return;

    setState(() {
      _checking = true;
      _errorMessage = null;
    });

    _checkSession();
  }

  /// Halaman utama. pushAndRemoveUntil menghapus gerbang dari riwayat agar
  /// tombol Back tidak mengembalikan pengguna ke layar pemeriksaan.
  void _openHome(UserModel user) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => HomePage(user: user)),
      (route) => false,
    );
  }

  /// Tidak ada sesi: tampilkan onboarding dengan hook yang sama seperti
  /// sebelumnya. Hook memakai context milik rute onboarding (routeContext),
  /// bukan context gerbang yang sudah dibuang, agar tetap sah saat tombol
  /// ditekan di kemudian hari.
  void _openOnboarding() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (routeContext) => OnboardingScreen(
          onLogin: () => JobTrackApp._openLogin(routeContext),
          onSignUp: () => JobTrackApp._openRegister(routeContext),
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Pemeriksaan berjalan: hanya indikator, tanpa halaman lain yang
    // muncul sebentar di belakangnya.
    if (_checking) {
      return const Scaffold(
        backgroundColor: JobTrackColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Pemeriksaan gagal (mis. backend belum berjalan). Token tidak dianggap
    // valid hanya karena stringnya tersimpan, jadi pengguna diminta mencoba
    // lagi, bukan langsung dibawa ke halaman utama atau onboarding.
    return Scaffold(
      backgroundColor: JobTrackColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    size: 56,
                    color: JobTrackColors.navyMuted,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Gagal memeriksa sesi',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: JobTrackColors.navy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage ?? 'Terjadi kesalahan yang tidak diketahui.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.55,
                      color: JobTrackColors.navyMuted,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _retry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: JobTrackColors.blue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Coba Lagi'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
