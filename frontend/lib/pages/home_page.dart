import 'package:flutter/material.dart';

import 'login_page.dart';
import 'onboarding_screen.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

/// Halaman utama setelah login.
///
/// Versi sederhana untuk menuntaskan alur autentikasi: menampilkan data
/// pengguna yang berhasil masuk dan tombol keluar. Fitur berikutnya
/// (daftar lowongan, dsb.) tinggal ditambahkan di [HomePage] ini.
class HomePage extends StatefulWidget {
  const HomePage({super.key, this.user});

  /// Pengguna yang login. Boleh kosong bila halaman dibuka tanpa data
  /// (misalnya dari hot restart); aplikasi lalu mencoba mengambilnya
  /// dari token yang tersimpan.
  final UserModel? user;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _authService = AuthService();
  UserModel? _user;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _loadUser();
  }

  /// Mengambil data pengguna dari token tersimpan (GET /auth/me).
  ///
  /// Bila token tidak ada atau sudah kedaluwarsa, pengguna dikembalikan
  /// ke halaman login supaya tidak berada di halaman utama tanpa sesi.
  Future<void> _loadUser() async {
    if (_user != null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final user = await _authService.getCurrentUser();

      if (!mounted) return;

      if (user == null) {
        _goToLogin();
        return;
      }

      setState(() {
        _user = user;
        _loading = false;
      });
    } catch (_) {
      // Server tidak terjangkau: tetap tampilkan halaman dengan data
      // yang ada, jangan memaksa keluar hanya karena jaringan mati.
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goToLogin() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  Future<void> _logout() async {
    await _authService.logout();

    if (!mounted) return;

    // Hapus semua riwayat agar Back tidak kembali ke halaman utama
    // setelah keluar.
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;

    return Scaffold(
      backgroundColor: JobTrackColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: JobTrackColors.navy),
        actions: [
          IconButton(
            tooltip: 'Keluar',
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: JobTrackColors.navy),
          ),
        ],
      ),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : Text(
                user == null
                    ? 'Selamat datang di JobTrack'
                    : 'Halo, ${user.username}!',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: JobTrackColors.navy,
                ),
              ),
      ),
    );
  }
}
