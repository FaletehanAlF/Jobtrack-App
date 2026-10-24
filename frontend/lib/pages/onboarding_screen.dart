import 'package:flutter/material.dart';

import '../theme/jobtrack_theme.dart';
import '../widgets/auth_components.dart';

/// Halaman onboarding: layar pertama yang dilihat pengguna sebelum
/// masuk atau mendaftar.
///
/// Desain: background krem hangat, logo JobTrack di atas, headline
/// singkat, deskripsi ringkas, tombol "Mulai Sekarang", dan tautan
/// "Sudah punya akun? Masuk". Tanpa gradient, glow, atau dekorasi berlebihan.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key, this.onLogin, this.onSignUp});

  final VoidCallback? onLogin;
  final VoidCallback? onSignUp;

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
      backgroundColor: JobTrackColors.warmBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth < 380 ? 20.0 : 28.0;

            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: 32,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 16),

                          // ── Logo ──────────────────────────────────────
                          const Center(child: JobTrackLogo(size: 88)),
                          const SizedBox(height: 24),

                          // ── Nama app ──────────────────────────────────
                          const Text(
                            'JobTrack',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.0,
                              color: JobTrackColors.blue,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // ── Headline ──────────────────────────────────
                          const Text(
                            'Temukan Peluang Kariermu',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 28,
                              height: 1.2,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              color: JobTrackColors.navy,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // ── Deskripsi ─────────────────────────────────
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

                          const SizedBox(height: 40),

                          // ── Tombol utama ──────────────────────────────
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