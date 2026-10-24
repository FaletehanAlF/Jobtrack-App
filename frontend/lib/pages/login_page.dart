import 'package:flutter/material.dart';

import 'home_page.dart';
import 'register_page.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/jobtrack_theme.dart';
import '../utils/validators.dart';
import '../widgets/auth_components.dart';

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

    return Scaffold(
      backgroundColor: JobTrackColors.warmBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 720;
            final horizontalPadding = constraints.maxWidth < 380 ? 20.0 : 28.0;

            if (isWide) {
              // ── Desktop/web: dua kolom ──────────────────────────────
              return Row(
                children: [
                  // Panel kiri: branding
                  Expanded(
                    child: Container(
                      color: JobTrackColors.navy,
                      padding: const EdgeInsets.all(48),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const JobTrackLogo(size: 72),
                          const SizedBox(height: 24),
                          const Text(
                            'JobTrack',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.0,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Temukan Peluang\nKariermu',
                            style: TextStyle(
                              fontSize: 36,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.8,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Catat lowongan incaran, pantau status lamaran, '
                            'dan kelola perjalanan kariermu dalam satu tempat.',
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.6,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Panel kanan: form
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(48),
                          child: _LoginForm(
                            formKey: _formKey,
                            emailController: _emailController,
                            passwordController: _passwordController,
                            obscurePassword: _obscurePassword,
                            onToggleObscure: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            loading: _loading,
                            errorMessage: errorMessage,
                            onLogin: _login,
                            onOpenRegister: _openRegister,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            // ── Mobile: satu kolom dengan header navy ────────────────
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header navy
                  Container(
                    padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                    decoration: const BoxDecoration(
                      color: JobTrackColors.navy,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(28),
                        bottomRight: Radius.circular(28),
                      ),
                    ),
                    child: Column(
                      children: [
                        const JobTrackLogo(size: 64),
                        const SizedBox(height: 16),
                        const Text(
                          'JobTrack',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.0,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Selamat Datang Kembali',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Masuk untuk melanjutkan perjalanan kariermu.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Form card
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: 24,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: JobTrackColors.warmSurface,
                        borderRadius: BorderRadius.circular(JobTrackRadii.card),
                        border: Border.all(color: JobTrackColors.border),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0A0F2137),
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: _LoginForm(
                        formKey: _formKey,
                        emailController: _emailController,
                        passwordController: _passwordController,
                        obscurePassword: _obscurePassword,
                        onToggleObscure: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        loading: _loading,
                        errorMessage: errorMessage,
                        onLogin: _login,
                        onOpenRegister: _openRegister,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Form login yang digunakan di kedua layout (mobile & desktop).
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
          TextFormField(
            controller: emailController,
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
            controller: passwordController,
            obscureText: obscurePassword,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => onLogin(),
            validator: Validators.loginPassword,
            style: const TextStyle(fontSize: 15, color: JobTrackColors.navy),
            decoration: authFieldDecoration(
              label: 'Password',
              hint: 'Masukkan password',
              prefixIcon: const AuthFieldIcon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                tooltip: obscurePassword
                    ? 'Tampilkan password'
                    : 'Sembunyikan password',
                onPressed: onToggleObscure,
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 22,
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
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                textStyle: const TextStyle(
                  fontSize: 13,
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

          PrimaryButton(
            label: 'Masuk',
            loading: loading,
            onPressed: onLogin,
          ),

          const SizedBox(height: 24),

          // Divider
          Row(
            children: [
              Expanded(child: Divider(color: JobTrackColors.border, thickness: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'atau masuk dengan',
                  style: TextStyle(
                    fontSize: 13,
                    color: JobTrackColors.navyMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(child: Divider(color: JobTrackColors.border, thickness: 1)),
            ],
          ),

          const SizedBox(height: 20),

          // Social login - round icon buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SocialIconButton(
                icon: Icons.g_mobiledata_rounded,
                color: const Color(0xFFDB4437),
                onPressed: loading ? null : () {},
              ),
              const SizedBox(width: 16),
              _SocialIconButton(
                icon: Icons.link_rounded,
                color: const Color(0xFF0A66C2),
                onPressed: loading ? null : () {},
              ),
              const SizedBox(width: 16),
              _SocialIconButton(
                icon: Icons.facebook_rounded,
                color: const Color(0xFF1877F2),
                onPressed: loading ? null : () {},
              ),
            ],
          ),

          const SizedBox(height: 24),

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

/// Tombol sosial berbentuk bulat sederhana.
class _SocialIconButton extends StatelessWidget {
  const _SocialIconButton({
    required this.icon,
    required this.color,
    this.onPressed,
  });

  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: JobTrackColors.border, width: 1.2),
          shape: const CircleBorder(),
          padding: EdgeInsets.zero,
        ),
        child: Icon(icon, size: 24, color: color),
      ),
    );
  }
}