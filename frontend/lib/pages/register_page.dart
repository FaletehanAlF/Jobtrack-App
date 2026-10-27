import 'package:flutter/material.dart';

import 'login_page.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/jobtrack_theme.dart';
import '../utils/validators.dart';
import '../widgets/auth_components.dart';

/// Halaman pendaftaran akun baru.
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

  String _messageFor(Object error) {
    if (error is ApiException) return error.message;
    return 'Terjadi kesalahan. Coba lagi.';
  }

  void _openLogin() {
    if (_loading) return;
    // Tetap `push`: Back dari form login memang harus kembali ke halaman
    // daftar yang tadi dibuka pengguna.
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
        obscurePassword: _obscurePassword,
        onToggleObscure: () =>
            setState(() => _obscurePassword = !_obscurePassword),
        loading: _loading,
        errorMessage: errorMessage,
        onRegister: _register,
        onOpenLogin: _openLogin,
      ),
    );
  }
}

class _RegisterForm extends StatelessWidget {
  const _RegisterForm({
    required this.formKey,
    required this.usernameController,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onToggleObscure,
    required this.loading,
    required this.errorMessage,
    required this.onRegister,
    required this.onOpenLogin,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController usernameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onToggleObscure;
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
          const SizedBox(height: 28),

          const AuthFieldLabel('Username'),
          const SizedBox(height: 8),
          TextFormField(
            controller: usernameController,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            validator: Validators.username,
            style: const TextStyle(fontSize: 14.5, color: JobTrackColors.navy),
            decoration: authFieldDecoration(hint: 'Minimal 3 karakter'),
          ),
          const SizedBox(height: 16),

          const AuthFieldLabel('Email'),
          const SizedBox(height: 8),
          TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            validator: Validators.email,
            style: const TextStyle(fontSize: 14.5, color: JobTrackColors.navy),
            decoration: authFieldDecoration(hint: 'nama@email.com'),
          ),
          const SizedBox(height: 16),

          const AuthFieldLabel('Password'),
          const SizedBox(height: 8),
          TextFormField(
            controller: passwordController,
            obscureText: obscurePassword,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => onRegister(),
            validator: Validators.password,
            style: const TextStyle(fontSize: 14.5, color: JobTrackColors.navy),
            decoration: authFieldDecoration(
              hint: 'Minimal 8 karakter',
              suffixIcon: IconButton(
                tooltip: obscurePassword
                    ? 'Tampilkan password'
                    : 'Sembunyikan password',
                onPressed: onToggleObscure,
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                  color: JobTrackColors.navyMuted,
                ),
              ),
            ),
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

          const AuthDivider(),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SocialCircleButton(
                tooltip: 'Daftar dengan Google',
                icon: const GoogleIcon(),
                onPressed: loading ? null : () {},
              ),
              const SizedBox(width: 14),
              SocialCircleButton(
                tooltip: 'Daftar dengan Apple',
                icon: const Icon(Icons.apple, size: 23, color: Colors.black),
                onPressed: loading ? null : () {},
              ),
              const SizedBox(width: 14),
              SocialCircleButton(
                tooltip: 'Daftar dengan Facebook',
                icon: const Icon(
                  Icons.facebook,
                  size: 24,
                  color: Color(0xFF1877F2),
                ),
                onPressed: loading ? null : () {},
              ),
            ],
          ),
          const SizedBox(height: 28),

          AuthLinkRow(
            question: 'Sudah punya akun?',
            action: 'Masuk',
            onPressed: onOpenLogin,
          ),
        ],
      ),
    );
  }
}
