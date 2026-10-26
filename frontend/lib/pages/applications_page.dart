import 'package:flutter/material.dart';

import '../models/application_model.dart';
import '../services/application_service.dart';
import '../theme/jobtrack_theme.dart';
import '../widgets/application_widgets.dart';
import '../widgets/excel_export_button.dart';

/// Halaman riwayat lamaran milik pengguna yang sedang login.
///
/// Data berasal dari `GET /api/applications`. Backend hanya mengembalikan
/// lamaran dengan `applicant_id` yang diambil dari token JWT, sehingga halaman
/// ini tidak dapat dipakai untuk melihat lamaran pengguna lain. Tombol ekspor
/// meminta file .xlsx dari endpoint backend dengan filter kepemilikan yang sama.
class ApplicationsPage extends StatelessWidget {
  const ApplicationsPage({
    super.key,
    required this.applications,
    required this.loading,
    required this.error,
    required this.canView,
    required this.onRefresh,
    required this.onOpenApplication,
    required this.onShowJobs,
    this.applicationService,
    this.downloadHandler,
  });

  final List<ApplicationModel> applications;
  final bool loading;
  final String? error;
  final bool canView;
  final Future<void> Function() onRefresh;
  final ValueChanged<ApplicationModel> onOpenApplication;
  final VoidCallback onShowJobs;
  final ApplicationService? applicationService;
  final ReportDownloadHandler? downloadHandler;

  @override
  Widget build(BuildContext context) {
    if (!canView) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.assignment_outlined,
                size: 48,
                color: JobTrackColors.navyMuted,
              ),
              SizedBox(height: 16),
              Text(
                'Khusus pencari kerja',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: JobTrackColors.navy,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Riwayat lamaran hanya tersedia untuk akun dengan role jobseeker.',
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

    final stats = ApplicationStats.fromApplications(applications);

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
                                  'Riwayat lamaran',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: JobTrackColors.navy,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  applications.isEmpty
                                      ? 'Belum ada lamaran yang tercatat.'
                                      : '${stats.total} lamaran tercatat untuk akun ini.',
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    color: JobTrackColors.navyMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Muat ulang lamaran',
                            onPressed: loading ? null : onRefresh,
                            icon: const Icon(Icons.refresh),
                            color: JobTrackColors.navyMuted,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ExcelExportButton(
                        buttonKey: const Key('jobseeker-export-button'),
                        enabled:
                            !loading &&
                            error == null &&
                            applications.isNotEmpty,
                        onExport: () =>
                            (applicationService ?? ApplicationService())
                                .exportApplications(),
                        downloadHandler: downloadHandler,
                        successMessage: 'Laporan lamaran berhasil diunduh.',
                        disabledMessage: loading
                            ? 'Tunggu data lamaran selesai dimuat.'
                            : 'Belum ada lamaran untuk diekspor.',
                      ),
                      if (!loading &&
                          error == null &&
                          applications.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _CountPill(
                              label: 'Total',
                              value: stats.total,
                              color: JobTrackColors.navyMuted,
                              background: const Color(0xFFF1F5F9),
                            ),
                            _CountPill(
                              label: 'Dikirim',
                              value: stats.submitted,
                              color: JobTrackColors.blue,
                              background: JobTrackColors.blueSoft,
                            ),
                            _CountPill(
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
                        const _PageLoading()
                      else if (error != null)
                        _PageError(message: error!, onRetry: onRefresh)
                      else if (applications.isEmpty)
                        _EmptyApplications(onShowJobs: onShowJobs)
                      else
                        Column(
                          children: [
                            for (
                              var index = 0;
                              index < applications.length;
                              index++
                            ) ...[
                              if (index > 0) const SizedBox(height: 10),
                              ApplicationCard(
                                application: applications[index],
                                onTap: () =>
                                    onOpenApplication(applications[index]),
                              ),
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

class _CountPill extends StatelessWidget {
  const _CountPill({
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

class _PageLoading extends StatelessWidget {
  const _PageLoading();

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
            'Memuat riwayat lamaran...',
            style: TextStyle(fontSize: 13, color: JobTrackColors.navyMuted),
          ),
        ],
      ),
    );
  }
}

class _PageError extends StatelessWidget {
  const _PageError({required this.message, required this.onRetry});

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

class _EmptyApplications extends StatelessWidget {
  const _EmptyApplications({required this.onShowJobs});

  final VoidCallback onShowJobs;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: JobTrackColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: JobTrackColors.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.assignment_outlined,
            size: 46,
            color: JobTrackColors.navyMuted,
          ),
          const SizedBox(height: 12),
          const Text(
            'Belum ada lamaran',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: JobTrackColors.navy,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Lamaran yang kamu kirim akan muncul di sini beserta statusnya.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: JobTrackColors.navyMuted,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            key: const Key('applications-empty-cta'),
            onPressed: onShowJobs,
            style: ElevatedButton.styleFrom(
              backgroundColor: JobTrackColors.blue,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Jelajahi lowongan'),
          ),
        ],
      ),
    );
  }
}
