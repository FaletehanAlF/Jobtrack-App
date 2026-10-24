import 'package:flutter/material.dart';

import 'login_page.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/jobtrack_theme.dart';
import '../utils/validators.dart';
import '../widgets/auth_components.dart';

/// Halaman pendaftaran akun baru.
///
/// Backend memvalidasi: username 3–50 karakter, email valid, password
/// 8–72 karakter. Field `confirmPassword` tetap dikirim ke backend
/// (disamakan dengan password) agar validasi server tetap berjalan,
/// tetapi tidak ditampilkan di form agar pengalaman pengguna lebih ringkas.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _authService = AuthService();

  bool _obscurePassword = true;
  bool _loading = false;

  /// Pesan gagal pendaftaran, ditampilkan sebagai banner di atas tombol.
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_loading) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final user = await _authService.register(
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Registrasi berhasil! Akun "${user.username}" dibuat. Silakan masuk.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Register tidak menghasilkan token, jadi pengguna diarahkan ke
      // halaman login. pushAndRemoveUntil membersihkan onboarding dan
      // register dari riwayat Back.
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;

      setState(() => _errorMessage = _messageFor(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Mengubah error menjadi kalimat yang bisa dibaca pengguna.
  ///
  /// [ApiException] membawa pesan dari server (mis. "Email sudah terdaftar").
  String _messageFor(Object error) {
    if (error is ApiException) return error.message;
    return 'Terjadi kesalahan. Coba lagi.';
  }

  void _openLogin() {
    if (_loading) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final errorMessage = _errorMessage;

    return AuthPageScaffold(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthHeader(
              title: 'Buat Akun JobTrack',
              subtitle: 'Mulai catat dan pantau lamaran kerjamu.',
              logoSize: 68,
            ),
            const SizedBox(height: 28),

            // Username, bukan "Full Name": backend menyimpan `username`
            // dengan aturan 3–50 karakter, jadi labelnya mengikuti data
            // yang benar-benar dikirim.
            TextFormField(
              controller: _usernameController,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              validator: Validators.username,
              style: const TextStyle(fontSize: 15, color: JobTrackColors.navy),
              decoration: authFieldDecoration(
                label: 'Username',
                hint: 'Minimal 3 karakter',
                prefixIcon: const AuthFieldIcon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              validator: Validators.email,
              style: const TextStyle(fontSize: 15, color: JobTrackColors.navy),
              decoration: authFieldDecoration(
                label: 'Email',
                hint: 'nama@email.com',
                prefixIcon: const AuthFieldIcon(Icons.mail_outline_rounded),
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _register(),
              validator: Validators.password,
              style: const TextStyle(fontSize: 15, color: JobTrackColors.navy),
              decoration: authFieldDecoration(
                label: 'Password',
                hint: 'Minimal 8 karakter',
                prefixIcon: const AuthFieldIcon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: _obscurePassword
                      ? 'Tampilkan password'
                      : 'Sembunyikan password',
                  onPressed: () => setState(
                    () => _obscurePassword = !_obscurePassword,
                  ),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 22,
                    color: JobTrackColors.navyMuted,
                  ),
                ),
              ),
            ),

            if (errorMessage != null) ...[
              const SizedBox(height: 16),
              AuthErrorBanner(message: errorMessage),
            ],

            const SizedBox(height: 24),

            PrimaryButton(
              label: 'Buat Akun',
              loading: _loading,
              onPressed: _register,
            ),
            const SizedBox(height: 12),
            AuthLinkRow(
              question: 'Sudah punya akun?',
              action: 'Masuk',
              onPressed: _openLogin,
            ),
          ],
        ),
      ),
    );
  }
}