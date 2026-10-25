import 'package:flutter/material.dart';

import '../theme/jobtrack_theme.dart';

/// Halaman placeholder untuk tab "Tersimpan".
///
/// Backend belum menyediakan endpoint bookmark/saved jobs.
class SavedJobsPage extends StatelessWidget {
  const SavedJobsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SavedPlaceholder();
  }
}

class _SavedPlaceholder extends StatelessWidget {
  const _SavedPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_border, size: 48, color: JobTrackColors.navyMuted),
            SizedBox(height: 16),
            Text(
              'Tersimpan',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: JobTrackColors.navy,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Fitur lowongan tersimpan belum tersedia. '
              'Backend untuk fitur ini belum diimplementasikan.',
              textAlign: TextAlign.center,
              style: TextStyle(
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
