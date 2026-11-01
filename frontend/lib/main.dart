import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'models/user_model.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'pages/onboarding_screen.dart';
import 'pages/register_page.dart';
import 'services/auth_service.dart';
import 'theme/jobtrack_theme.dart';

void main() {
  runApp(const JobTrackApp());
}

class JobTrackApp extends StatelessWidget {
  const JobTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: JobTrackColors.background,
      colorScheme: ColorScheme.fromSeed(seedColor: JobTrackColors.blue),
    );

    return MaterialApp(
      title: 'JobTrack',
      debugShowCheckedModeBanner: false,
      theme: baseTheme.copyWith(
        textTheme: GoogleFonts.montserratTextTheme(baseTheme.textTheme),
        primaryTextTheme: GoogleFonts.montserratTextTheme(
          baseTheme.primaryTextTheme,
        ),
      ),
      home: const _SessionGate(),
    );
  }

  static void _openLogin(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  static void _openRegister(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterPage()),
    );
  }
}

class _SessionGate extends StatefulWidget {
  const _SessionGate();

  @override
  State<_SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<_SessionGate> {
  final _authService = AuthService();

  int _attempt = 0;

  bool _checking = true;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final attempt = ++_attempt;

    try {
      final user = await _authService.getCurrentUser().timeout(
        const Duration(seconds: 10),
      );

      if (!mounted || attempt != _attempt) return;

      if (user != null) {
        _openHome(user);
      } else {
        _openOnboarding();
      }
    } catch (error) {
      if (!mounted || attempt != _attempt) return;

      setState(() {
        _checking = false;
        _errorMessage = error.toString();
      });
    }
  }

  void _retry() {
    if (_checking) return;

    setState(() {
      _checking = true;
      _errorMessage = null;
    });

    _checkSession();
  }

  void _openHome(UserModel user) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => HomePage(user: user)),
      (route) => false,
    );
  }

  void _openOnboarding() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (routeContext) => OnboardingScreen(
          onLogin: () => JobTrackApp._openLogin(routeContext),
          onSignUp: () => JobTrackApp._openRegister(routeContext),
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: JobTrackColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: JobTrackColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    size: 56,
                    color: JobTrackColors.navyMuted,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Gagal memeriksa sesi',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: JobTrackColors.navy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage ?? 'Terjadi kesalahan yang tidak diketahui.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.55,
                      color: JobTrackColors.navyMuted,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _retry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: JobTrackColors.blue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Coba Lagi'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
