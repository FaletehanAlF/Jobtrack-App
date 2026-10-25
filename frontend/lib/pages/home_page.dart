import 'package:flutter/material.dart';

import 'applications_page.dart';
import 'login_page.dart';
import 'onboarding_screen.dart';
import 'home_tab.dart';
import 'jobs_page.dart';
import 'profile_page.dart';
import 'saved_jobs_page.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../theme/jobtrack_theme.dart';

/// Shell utama setelah login.
///
/// Menyediakan Bottom Navigation Bar untuk pencari kerja:
/// Beranda, Lowongan, Lamaran, Tersimpan, Profil.
class HomePage extends StatefulWidget {
  const HomePage({super.key, this.user});

  final UserModel? user;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _authService = AuthService();

  UserModel? _user;
  bool _loadingUser = true;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _loadUser();
  }

  Future<void> _loadUser() async {
    if (_user != null) {
      if (mounted) setState(() => _loadingUser = false);
      return;
    }

    try {
      final user = await _authService.getCurrentUser();
      if (!mounted) return;
      if (user == null) {
        _goToLogin();
        return;
      }
      setState(() {
        _user = user;
        _loadingUser = false;
      });
    } catch (_) {
      // Server tidak terjangkau: tetap tampilkan shell dengan data yang ada.
      if (mounted) setState(() => _loadingUser = false);
    }
  }

  void _goToLogin() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  Future<void> _logout() async {
    await _authService.logout();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      (route) => false,
    );
  }

  // Import ditunda ke atas; LoginPage/OnboardingScreen diimport di sini
  // agar tidak menambah import siklik yang tidak perlu.
  static const _titles = <String>[
    'JobTrack',
    'Lowongan',
    'Lamaran',
    'Tersimpan',
    'Profil',
  ];

  @override
  Widget build(BuildContext context) {
    if (_loadingUser && _user == null) {
      return const Scaffold(
        backgroundColor: JobTrackColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final pages = <Widget>[
      HomeTab(user: _user),
      const JobsPage(),
      const ApplicationsPage(),
      const SavedJobsPage(),
      ProfilePage(user: _user, onLogout: _logout),
    ];

    return Scaffold(
      backgroundColor: JobTrackColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: JobTrackColors.navy,
        title: Text(
          _titles[_currentIndex],
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: JobTrackColors.navy,
          ),
        ),
      ),
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: JobTrackColors.blue,
        unselectedItemColor: JobTrackColors.navyMuted,
        backgroundColor: JobTrackColors.surface,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Beranda',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.work_outline),
            activeIcon: Icon(Icons.work),
            label: 'Lowongan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            activeIcon: Icon(Icons.assignment),
            label: 'Lamaran',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark_border),
            activeIcon: Icon(Icons.bookmark),
            label: 'Tersimpan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
