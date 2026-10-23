import 'package:flutter/material.dart';

import '../theme/jobtrack_theme.dart';
import '../widgets/auth_components.dart';

/// Halaman onboarding: layar pertama yang dilihat pengguna sebelum
/// masuk atau mendaftar.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key, this.onLogin, this.onSignUp});

  final VoidCallback? onLogin;
  final VoidCallback? onSignUp;

  // Tombol tetap terlihat aktif walau callback belum dipasang, supaya
  // tampilan onboarding tidak terlihat seperti aplikasi yang rusak.
  // Selama callback kosong, ketukan hanya menampilkan pemberitahuan singkat.
  void _notReady(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Halaman ini belum tersedia'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openLogin(BuildContext context) {
    final callback = onLogin;
    if (callback == null) {
      _notReady(context);
      return;
    }
    callback();
  }

  void _openSignUp(BuildContext context) {
    final callback = onSignUp;
    if (callback == null) {
      _notReady(context);
      return;
    }
    callback();
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageScaffold(
      showBackButton: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),

          // Area atas: logo berukuran besar sebagai satu-satunya ilustrasi.
          // Tidak memakai background gambar penuh agar teks tetap terbaca
          // dan aset baru tidak perlu ditambahkan.
          const Center(child: JobTrackLogo(size: 104)),
          const SizedBox(height: 20),

          // Nama aplikasi: bagian dari judul, sehingga tes yang mencari
          // teks "JobTrack" tetap menemukannya.
          const Text(
            'JobTrack',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: JobTrackColors.blue,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Temukan Peluang Kariermu',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 30,
              height: 1.2,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: JobTrackColors.navy,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Catat lowongan incaran, pantau status lamaran, dan kelola '
            'perjalanan kariermu dalam satu tempat.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: JobTrackColors.navyMuted,
            ),
          ),

          // Dorong blok tombol ke bawah pada layar tinggi tanpa mengunci
          // posisinya di layar pendek.
          const SizedBox(height: 36),

          // Satu tindakan utama. Tombol sosial (Google/Apple/Facebook)
          // sengaja tidak ditampilkan karena alurnya belum ada di backend —
          // menampilkannya akan menjadi tombol palsu.
          PrimaryButton(
            label: 'Mulai Sekarang',
            onPressed: () => _openSignUp(context),
          ),
          const SizedBox(height: 12),
          AuthLinkRow(
            question: 'Sudah punya akun?',
            action: 'Masuk',
            onPressed: () => _openLogin(context),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
