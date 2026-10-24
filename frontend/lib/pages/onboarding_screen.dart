import 'package:flutter/material.dart';

import '../theme/jobtrack_theme.dart';
import '../widgets/auth_components.dart';

/// Halaman onboarding: layar pertama yang dilihat pengguna sebelum
/// masuk atau mendaftar.
///
/// Desain modern: gradien lembut di bagian atas, logo dengan bayangan
/// halus, headline besar, daftar fitur singkat, dan tombol CTA yang
/// menonjol. Tetap menggunakan palet [JobTrackColors] agar konsisten
/// dengan halaman login/register.
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
    return Scaffold(
      backgroundColor: JobTrackColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 720;
            final horizontalPadding = constraints.maxWidth < 380 ? 20.0 : 28.0;

            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: 24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 12),

                          // ── Hero section ──────────────────────────────
                          _HeroSection(),

                          const SizedBox(height: 36),

                          // ── Feature highlights ────────────────────────
                          _FeatureRow(
                            icon: Icons.bookmark_outline_rounded,
                            title: 'Simpan Lowongan',
                            subtitle:
                                'Catat semua lowongan yang menarik perhatianmu.',
                          ),
                          const SizedBox(height: 12),
                          _FeatureRow(
                            icon: Icons.track_changes_rounded,
                            title: 'Pantau Status',
                            subtitle:
                                'Lacak setiap tahap lamaran dari satu tempat.',
                          ),
                          const SizedBox(height: 12),
                          _FeatureRow(
                            icon: Icons.insights_rounded,
                            title: 'Analisis Progres',
                            subtitle:
                                'Lihat statistik lamaran untuk strategi yang lebih baik.',
                          ),

                          const SizedBox(height: 40),

                          // ── CTA buttons ───────────────────────────────
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
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Bagian atas onboarding: gradien, logo, nama app, headline.
class _HeroSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFEAF2FF),
            Color(0xFFF7F9FB),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: JobTrackColors.border),
      ),
      child: Column(
        children: [
          // Logo dengan bayangan halus
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: JobTrackColors.blue.withValues(alpha: 0.15),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: const JobTrackLogo(size: 96),
          ),
          const SizedBox(height: 20),

          // Nama aplikasi
          const Text(
            'JobTrack',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.0,
              color: JobTrackColors.blue,
            ),
          ),
          const SizedBox(height: 8),

          // Headline
          const Text(
            'Temukan Peluang\nKariermu',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              height: 1.15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              color: JobTrackColors.navy,
            ),
          ),
          const SizedBox(height: 12),

          // Subtitle
          const Text(
            'Catat lowongan incaran, pantau status lamaran, '
            'dan kelola perjalanan kariermu dalam satu tempat.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: JobTrackColors.navyMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Baris fitur: ikon + judul + deskripsi singkat.
class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: JobTrackColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: JobTrackColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: JobTrackColors.blueSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 22,
              color: JobTrackColors.blue,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: JobTrackColors.navy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: JobTrackColors.navyMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}