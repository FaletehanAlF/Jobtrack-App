import 'package:flutter/material.dart';

import 'home_page.dart';
import 'register_page.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/jobtrack_theme.dart';
import '../utils/validators.dart';
import '../widgets/auth_components.dart';

/// Halaman login: memasukkan email dan password untuk masuk ke aplikasi.
///
/// Setelah login berhasil, token disimpan oleh [AuthService.login] dan
/// pengguna dibawa ke [HomePage] menggantikan halaman ini (tidak bisa
/// kembali ke login lewat tombol Back).
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _authService = AuthService();

  bool _obscurePassword = true;
  bool _loading = false;

  /// Pesan gagal login. Ditampilkan sebagai banner di atas tombol, bukan
  /// SnackBar, supaya tetap terbaca selama pengguna memperbaiki isian.
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    // Validasi form lebih dulu; bila tidak valid, Form menampilkan pesan
    // errornya sendiri dan request tidak dikirim.
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Mencegah request terkirim dua kali saat tombol ditekan berulang.
    if (_loading) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      await _authService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      // pushReplacement: halaman login digantikan home, jadi tombol Back
      // tidak mengembalikan pengguna ke form login.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
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
  /// [ApiException.toString] sudah berisi pesan dari server; error lain
  /// (mis. bug di luar alur API) tidak dibocorkan apa adanya.
  String _messageFor(Object error) {
    if (error is ApiException) return error.message;
    return 'Terjadi kesalahan. Coba lagi.';
  }

  void _openRegister() {
    if (_loading) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterPage()),
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
              title: 'Selamat Datang Kembali',
              subtitle: 'Masuk untuk melanjutkan perjalanan kariermu.',
              logoSize: 68,
            ),
            const SizedBox(height: 28),

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
              onFieldSubmitted: (_) => _login(),
              validator: Validators.loginPassword,
              style: const TextStyle(fontSize: 15, color: JobTrackColors.navy),
              decoration: authFieldDecoration(
                label: 'Password',
                hint: 'Masukkan password',
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

            // Tombol dinonaktifkan dan menampilkan indikator selama loading
            // agar request tidak terkirim dua kali.
            PrimaryButton(
              label: 'Masuk',
              loading: _loading,
              onPressed: _login,
            ),
            const SizedBox(height: 12),
            AuthLinkRow(
              question: 'Belum punya akun?',
              action: 'Daftar',
              onPressed: _openRegister,
            ),
          ],
        ),
      ),
    );
  }
}
