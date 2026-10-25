import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../theme/jobtrack_theme.dart';

/// Halaman profil read-only.
///
/// Menampilkan data yang tersedia dari `UserModel` dan menyediakan tombol
/// logout. Pengeditan profil belum didukung backend.
class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    this.user,
    required this.onLogout,
  });

  final UserModel? user;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final currentUser = user;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 8),
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: JobTrackColors.blueSoft,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              _initials(currentUser?.username),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: JobTrackColors.blue,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          currentUser?.username ?? 'Pengguna',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: JobTrackColors.navy,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          currentUser?.email ?? '',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: JobTrackColors.navyMuted,
          ),
        ),
        const SizedBox(height: 24),
        _ProfileRow(label: 'Role', value: _roleLabel(currentUser?.role)),
        _ProfileRow(
          label: 'Bergabung',
          value: currentUser == null
              ? '-'
              : _formatDate(currentUser.createdAt),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: OutlinedButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout, color: JobTrackColors.navy),
            label: const Text('Keluar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: JobTrackColors.navy,
              side: const BorderSide(color: JobTrackColors.borderStrong),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Pengeditan profil belum tersedia.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            color: JobTrackColors.navyMuted,
          ),
        ),
      ],
    );
  }

  String _initials(String? username) {
    if (username == null || username.trim().isEmpty) return 'JT';
    final trimmed = username.trim();
    return trimmed.substring(0, 1).toUpperCase();
  }

  String _roleLabel(String? role) {
    switch (role) {
      case 'recruiter':
        return 'Recruiter';
      case 'jobseeker':
        return 'Pencari kerja';
      default:
        return role ?? '-';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: JobTrackColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: JobTrackColors.border),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: JobTrackColors.navyMuted,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: JobTrackColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}
