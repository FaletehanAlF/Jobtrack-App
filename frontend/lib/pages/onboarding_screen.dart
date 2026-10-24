import 'package:flutter/material.dart';

import '../widgets/auth_components.dart';

/// Halaman onboarding: layar pertama yang dilihat pengguna sebelum
/// masuk atau mendaftar.
///
/// Desain mengikuti referensi baru: kartu putih di atas latar gradien,
/// avatar logo di tengah, judul besar, tombol utama pill, pemisah "Atau",
/// dan tiga tombol sosial lebar penuh. Tata letak tetap responsif dan dapat
/// digulir pada layar pendek.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key, this.onLogin, this.onSignUp});

  final VoidCallback? onLogin;
  final VoidCallback? onSignUp;

  void _notReady(BuildContext context, [String? provider]) {
    final message = provider == null
        ? 'Halaman ini belum tersedia'
        : 'Masuk dengan $provider belum tersedia';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
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
          const AuthHeader(
            brand: 'JobTrack',
            title: 'Selamat Datang',
            subtitle:
                'Jelajahi pengalaman modern yang dibuat untuk kecepatan '
                'dan kesederhanaan.',
          ),
          const SizedBox(height: 32),

          PrimaryButton(
            label: 'Mulai Sekarang',
            onPressed: () => _openSignUp(context),
          ),
          const SizedBox(height: 24),

          const AuthDivider(),
          const SizedBox(height: 20),

          SocialButton(
            label: 'Lanjutkan dengan Google',
            icon: const GoogleIcon(),
            onPressed: () => _notReady(context, 'Google'),
          ),
          const SizedBox(height: 12),
          SocialButton(
            label: 'Lanjutkan dengan Apple',
            icon: const Icon(Icons.apple, size: 23, color: Colors.black),
            onPressed: () => _notReady(context, 'Apple'),
          ),
          const SizedBox(height: 12),
          SocialButton(
            label: 'Lanjutkan dengan Facebook',
            icon: const Icon(
              Icons.facebook,
              size: 24,
              color: Color(0xFF1877F2),
            ),
            onPressed: () => _notReady(context, 'Facebook'),
          ),

          const SizedBox(height: 28),
          AuthLinkRow(
            question: 'Sudah punya akun?',
            action: 'Masuk',
            onPressed: () => _openLogin(context),
          ),
        ],
      ),
    );
  }
}
