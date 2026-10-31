import 'package:flutter/material.dart';

import 'login_page.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/validators.dart';
import '../widgets/auth_components.dart';

/// Halaman pendaftaran akun baru.
///
/// Setelah pendaftaran berhasil, pengguna diarahkan ke [LoginPage] dengan
/// semua riwayat rute auth dibersihkan. Tampilan dipasang di
/// [AuthPageScaffold] agar kerangkanya sama dengan halaman login.
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

  bool _loading = false;

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

  /// Pesan yang ramah pengguna untuk error dari [AuthService].
  String _messageFor(Object error) {
    if (error is ApiException) return error.message;
    return 'Terjadi kesalahan. Coba lagi.';
  }

  void _openLogin() {
    if (_loading) return;
    // `push`: Back dari form login kembali ke halaman daftar.
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final errorMessage = _errorMessage;

    return AuthPageScaffold(
      child: _RegisterForm(
        formKey: _formKey,
        usernameController: _usernameController,
        emailController: _emailController,
        passwordController: _passwordController,
        loading: _loading,
        errorMessage: errorMessage,
        onRegister: _register,
        onOpenLogin: _openLogin,
      ),
    );
  }
}

/// Form pendaftaran: struktur dan jaraknya sama dengan form login.
class _RegisterForm extends StatelessWidget {
  const _RegisterForm({
    required this.formKey,
    required this.usernameController,
    required this.emailController,
    required this.passwordController,
    required this.loading,
    required this.errorMessage,
    required this.onRegister,
    required this.onOpenLogin,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController usernameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool loading;
  final String? errorMessage;
  final VoidCallback onRegister;
  final VoidCallback onOpenLogin;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthHeader(
            title: 'Buat Akun',
            subtitle: 'Daftar untuk memulai dashboardmu.',
            showBadge: true,
          ),
          const SizedBox(height: 32),
          AuthField(
            label: 'Username',
            controller: usernameController,
            validator: Validators.username,
            hint: 'Minimal 3 karakter',
          ),
          const SizedBox(height: 16),
          AuthField(
            label: 'Email',
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            validator: Validators.email,
            hint: 'nama@email.com',
          ),
          const SizedBox(height: 16),
          AuthPasswordField(
            controller: passwordController,
            validator: Validators.password,
            hint: 'Minimal 8 karakter',
            onFieldSubmitted: (_) => onRegister(),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 16),
            AuthErrorBanner(message: errorMessage!),
          ],
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Buat Akun',
            loading: loading,
            onPressed: onRegister,
          ),
          const SizedBox(height: 24),
          AuthLinkRow(
            question: 'Sudah punya akun?',
            action: 'Masuk',
            onPressed: loading ? null : onOpenLogin,
          ),
        ],
      ),
    );
  }
}
