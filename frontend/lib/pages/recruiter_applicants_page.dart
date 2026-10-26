import 'package:flutter/material.dart';

import '../models/application_model.dart';
import '../services/application_service.dart';
import '../theme/jobtrack_theme.dart';
import '../widgets/application_widgets.dart';
import '../widgets/excel_export_button.dart';

/// Dashboard recruiter: pelamar dari lowongan yang dimiliki recruiter login.
///
/// Data berasal dari `GET /api/applications/recruiter`. Backend memfilter
/// dengan `jobs.recruiter_id` dari JWT dan tidak mengirim email pelamar.
class RecruiterApplicantsPage extends StatelessWidget {
  const RecruiterApplicantsPage({
    super.key,
    required this.applicants,
    required this.loading,
    required this.error,
    required this.onRefresh,
    this.applicationService,
    this.downloadHandler,
  });

  final List<RecruiterApplicantModel> applicants;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;
  final ApplicationService? applicationService;
  final ReportDownloadHandler? downloadHandler;

  @override
  Widget build(BuildContext context) {
    final stats = ApplicationStats.fromStatuses(
      applicants.map((applicant) => applicant.status),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth >= 900 ? 32.0 : 16.0;

        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              20,
              horizontalPadding,
              32,
            ),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
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
                                const Text(
                                  'Pelamar',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: JobTrackColors.navy,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  applicants.isEmpty
                                      ? 'Belum ada pelamar pada lowongan milikmu.'
                                      : '${stats.total} pelamar dari lowongan milikmu.',
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    color: JobTrackColors.navyMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Muat ulang pelamar',
                            onPressed: loading ? null : onRefresh,
                            icon: const Icon(Icons.refresh),
                            color: JobTrackColors.navyMuted,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ExcelExportButton(
                        buttonKey: const Key('recruiter-export-button'),
                        enabled:
                            !loading && error == null && applicants.isNotEmpty,
                        onExport: () =>
                            (applicationService ?? ApplicationService())
                                .exportRecruiterApplicants(),
                        downloadHandler: downloadHandler,
                        successMessage: 'Laporan pelamar berhasil diunduh.',
                        disabledMessage: loading
                            ? 'Tunggu data pelamar selesai dimuat.'
                            : 'Belum ada pelamar untuk diekspor.',
                      ),
                      if (!loading &&
                          error == null &&
                          applicants.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _SummaryPill(
                              key: const Key('recruiter-stat-total'),
                              label: 'Total',
                              value: stats.total,
                              color: JobTrackColors.navyMuted,
                              background: const Color(0xFFF1F5F9),
                            ),
                            _SummaryPill(
                              key: const Key('recruiter-stat-submitted'),
                              label: 'Dikirim',
                              value: stats.submitted,
                              color: JobTrackColors.blue,
                              background: JobTrackColors.blueSoft,
                            ),
                            _SummaryPill(
                              key: const Key('recruiter-stat-rejected'),
                              label: 'Ditolak',
                              value: stats.rejected,
                              color: JobTrackColors.danger,
                              background: JobTrackColors.dangerSoft,
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 18),
                      if (loading)
                        const _RecruiterLoading()
                      else if (error != null)
                        _RecruiterError(message: error!, onRetry: onRefresh)
                      else if (applicants.isEmpty)
                        const _RecruiterEmpty()
                      else
                        Column(
                          children: [
                            for (
                              var index = 0;
                              index < applicants.length;
                              index++
                            ) ...[
                              if (index > 0) const SizedBox(height: 10),
                              _ApplicantCard(applicant: applicants[index]),
                            ],
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ApplicantCard extends StatelessWidget {
  const _ApplicantCard({required this.applicant});

  final RecruiterApplicantModel applicant;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: JobTrackColors.surface,
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
                      applicant.job.title,
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
                      applicant.job.company,
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
                status: applicant.status,
                label: applicant.statusLabel,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _MetaItem(
                icon: Icons.person_outline,
                text: applicant.applicantUsername.isEmpty
                    ? 'Nama pelamar tidak tersedia'
                    : applicant.applicantUsername,
              ),
              _MetaItem(
                icon: Icons.location_on_outlined,
                text: applicant.job.location.isEmpty
                    ? 'Lokasi tidak dicantumkan'
                    : applicant.job.location,
              ),
              _MetaItem(
                icon: Icons.calendar_today_outlined,
                text: _formatDate(applicant.createdAt),
              ),
            ],
          ),
        ],
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

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.background,
  });

  final String label;
  final int value;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _RecruiterLoading extends StatelessWidget {
  const _RecruiterLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36),
      decoration: BoxDecoration(
        color: JobTrackColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: JobTrackColors.border),
      ),
      child: const Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text(
            'Memuat pelamar...',
            style: TextStyle(fontSize: 13, color: JobTrackColors.navyMuted),
          ),
        ],
      ),
    );
  }
}

class _RecruiterError extends StatelessWidget {
  const _RecruiterError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: JobTrackColors.dangerSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: JobTrackColors.dangerBorder),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 36,
            color: JobTrackColors.danger,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: JobTrackColors.danger,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: JobTrackColors.danger,
              side: const BorderSide(color: JobTrackColors.dangerBorder),
            ),
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }
}

class _RecruiterEmpty extends StatelessWidget {
  const _RecruiterEmpty();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('recruiter-empty'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: JobTrackColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: JobTrackColors.border),
      ),
      child: const Column(
        children: [
          Icon(Icons.people_outline, size: 46, color: JobTrackColors.navyMuted),
          SizedBox(height: 12),
          Text(
            'Belum ada pelamar',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: JobTrackColors.navy,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Pelamar untuk lowongan yang kamu miliki akan muncul di sini.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: JobTrackColors.navyMuted,
            ),
          ),
        ],
      ),
    );
  }
}
