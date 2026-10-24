import 'package:flutter/material.dart';

import 'home_page.dart';
import 'register_page.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/jobtrack_theme.dart';
import '../utils/validators.dart';
import '../widgets/auth_components.dart';

/// Halaman login: memasukkan email dan password untuk masuk ke aplikasi.
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

  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
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
      child: _LoginForm(
        formKey: _formKey,
        emailController: _emailController,
        passwordController: _passwordController,
        obscurePassword: _obscurePassword,
        onToggleObscure: () =>
            setState(() => _obscurePassword = !_obscurePassword),
        loading: _loading,
        errorMessage: errorMessage,
        onLogin: _login,
        onOpenRegister: _openRegister,
      ),
    );
  }
}

/// Form login yang digunakan di halaman login.
class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onToggleObscure,
    required this.loading,
    required this.errorMessage,
    required this.onLogin,
    required this.onOpenRegister,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onToggleObscure;
  final bool loading;
  final String? errorMessage;
  final VoidCallback onLogin;
  final VoidCallback onOpenRegister;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthHeader(
            title: 'Selamat Datang Kembali',
            subtitle: 'Masuk untuk melanjutkan perjalanan kariermu.',
          ),
          const SizedBox(height: 28),

          const AuthFieldLabel('Email'),
          const SizedBox(height: 8),
          TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            validator: Validators.email,
            style: const TextStyle(fontSize: 14.5, color: JobTrackColors.navy),
            decoration: authFieldDecoration(hint: 'Masukkan email'),
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
            onFieldSubmitted: (_) => onLogin(),
            validator: Validators.loginPassword,
            style: const TextStyle(fontSize: 14.5, color: JobTrackColors.navy),
            decoration: authFieldDecoration(
              hint: 'Masukkan password',
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

          // Lupa password
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: loading ? null : () {},
              style: TextButton.styleFrom(
                foregroundColor: JobTrackColors.blue,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Lupa password?'),
            ),
          ),

          if (errorMessage != null) ...[
            const SizedBox(height: 4),
            AuthErrorBanner(message: errorMessage!),
            const SizedBox(height: 8),
          ],

          const SizedBox(height: 8),
          PrimaryButton(label: 'Masuk', loading: loading, onPressed: onLogin),
          const SizedBox(height: 24),

          const AuthDivider(),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SocialCircleButton(
                tooltip: 'Masuk dengan Google',
                icon: const GoogleIcon(),
                onPressed: loading ? null : () {},
              ),
              const SizedBox(width: 14),
              SocialCircleButton(
                tooltip: 'Masuk dengan Apple',
                icon: const Icon(Icons.apple, size: 23, color: Colors.black),
                onPressed: loading ? null : () {},
              ),
              const SizedBox(width: 14),
              SocialCircleButton(
                tooltip: 'Masuk dengan Facebook',
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
            question: 'Belum punya akun?',
            action: 'Daftar',
            onPressed: onOpenRegister,
          ),
        ],
      ),
    );
  }
}
