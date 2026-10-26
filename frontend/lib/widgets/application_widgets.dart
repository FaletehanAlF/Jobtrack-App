import 'package:flutter/material.dart';

import '../models/application_model.dart';
import '../theme/jobtrack_theme.dart';

/// Chip status lamaran. Hanya status yang didukung backend yang punya
/// tampilan khusus; status tak dikenal tetap ditampilkan sebagai teks.
class ApplicationStatusChip extends StatelessWidget {
  const ApplicationStatusChip({super.key, required this.status, this.label});

  final String status;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final isRejected = status == ApplicationStatus.rejected;
    final isSubmitted = status == ApplicationStatus.submitted;
    final color = isRejected
        ? JobTrackColors.danger
        : isSubmitted
        ? JobTrackColors.blue
        : JobTrackColors.navyMuted;
    final background = isRejected
        ? JobTrackColors.dangerSoft
        : isSubmitted
        ? JobTrackColors.blueSoft
        : const Color(0xFFF1F5F9);
    final icon = isRejected
        ? Icons.cancel_outlined
        : isSubmitted
        ? Icons.send_outlined
        : Icons.help_outline;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label ?? applicationStatusLabel(status),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu satu lamaran, dipakai di dashboard dan halaman riwayat.
class ApplicationCard extends StatelessWidget {
  const ApplicationCard({super.key, required this.application, this.onTap});

  final ApplicationModel application;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: JobTrackColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: JobTrackColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          application.job.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: JobTrackColors.navy,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          application.job.company,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: JobTrackColors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  ApplicationStatusChip(
                    status: application.status,
                    label: application.statusLabel,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  _MetaItem(
                    icon: Icons.location_on_outlined,
                    text: application.job.location.isEmpty
                        ? 'Lokasi tidak dicantumkan'
                        : application.job.location,
                  ),
                  _MetaItem(
                    icon: Icons.calendar_today_outlined,
                    text: _formatDate(application.createdAt),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime? date) {
    if (date == null) return 'Tanggal tidak tersedia';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}

/// Satu baris ikon + teks kecil di dalam kartu lamaran.
class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: JobTrackColors.navyMuted),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 12, color: JobTrackColors.navyMuted),
        ),
      ],
    );
  }
}
