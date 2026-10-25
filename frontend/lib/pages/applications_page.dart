import 'package:flutter/material.dart';

import '../theme/jobtrack_theme.dart';

/// Halaman placeholder untuk tab "Lamaran".
///
/// Backend belum menyediakan endpoint lamaran/status, jadi halaman ini
/// sengaja tidak menampilkan data apa pun. Jangan menganggap angka/statistik
/// di sini sebagai data asli.
class ApplicationsPage extends StatelessWidget {
  const ApplicationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _FeaturePlaceholder(
      icon: Icons.assignment_outlined,
      title: 'Lamaran',
      message:
          'Fitur lamaran dan status lamaran belum tersedia. '
          'Backend untuk fitur ini belum diimplementasikan.',
    );
  }
}

class _FeaturePlaceholder extends StatelessWidget {
  const _FeaturePlaceholder({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: JobTrackColors.navyMuted),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: JobTrackColors.navy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14.5,
                height: 1.5,
                color: JobTrackColors.navyMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
