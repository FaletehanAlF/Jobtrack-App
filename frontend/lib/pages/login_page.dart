import 'package:flutter/material.dart';

import 'home_page.dart';
import 'register_page.dart';
import '../services/api_service.dart';
import '../services/application_service.dart';
import '../services/auth_service.dart';
import '../services/job_service.dart';
import '../utils/validators.dart';
import '../widgets/auth_components.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    this.authService,
    this.jobService,
    this.applicationService,
  });

  final AuthService? authService;

  final JobService? jobService;

  final ApplicationService? applicationService;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  late final AuthService _authService = widget.authService ?? AuthService();

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
      final user = await _authService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => HomePage(
            user: user,
            jobService: widget.jobService,
            applicationService: widget.applicationService,
            authService: widget.authService,
          ),
        ),
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
        loading: _loading,
        errorMessage: errorMessage,
        onLogin: _login,
        onOpenRegister: _openRegister,
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.loading,
    required this.errorMessage,
    required this.onLogin,
    required this.onOpenRegister,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
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
          const SizedBox(height: 32),
          AuthField(
            label: 'Email',
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            validator: Validators.email,
            hint: 'Masukkan email',
          ),
          const SizedBox(height: 16),
          AuthPasswordField(
            controller: passwordController,
            validator: Validators.loginPassword,
            hint: 'Masukkan password',
            onFieldSubmitted: (_) => onLogin(),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 16),
            AuthErrorBanner(message: errorMessage!),
          ],
          const SizedBox(height: 24),
          PrimaryButton(label: 'Masuk', loading: loading, onPressed: onLogin),
          const SizedBox(height: 24),
          AuthLinkRow(
            question: 'Belum punya akun?',
            action: 'Daftar',
            onPressed: loading ? null : onOpenRegister,
          ),
        ],
      ),
    );
  }
}
