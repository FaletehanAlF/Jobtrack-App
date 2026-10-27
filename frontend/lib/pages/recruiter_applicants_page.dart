import 'package:flutter/material.dart';

import '../models/application_model.dart';
import '../models/recruiter_model.dart';
import '../services/application_service.dart';
import '../theme/jobtrack_theme.dart';
import '../widgets/application_widgets.dart';
import '../widgets/excel_export_button.dart';

/// Manajemen pelamar untuk recruiter.
///
/// Data berasal dari `GET /api/recruiter/applicants`, yang sudah dibatasi
/// `jobs.recruiter_id` dari token di backend. Filter di halaman ini hanya
/// mempersempit hasil yang memang sudah dibatasi kepemilikan — bukan
/// mekanisme keamanan.
class RecruiterApplicantsPage extends StatelessWidget {
  const RecruiterApplicantsPage({
    super.key,
    required this.applicants,
    required this.loading,
    required this.error,
    required this.onRefresh,
    this.applicationService,
    this.downloadHandler,
    this.jobs = const [],
    this.selectedJobId,
    this.onJobFilterChanged,
    this.selectedStatus,
    this.onStatusFilterChanged,
    this.onUpdateStatus,
    this.updatingApplicationId,
    this.total,
    this.hasMore = false,
    this.onLoadMore,
    this.loadingMore = false,
    this.initialJobId,
  });

  final List<RecruiterApplicantModel> applicants;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;
  final ApplicationService? applicationService;
  final ReportDownloadHandler? downloadHandler;

  /// Lowongan milik recruiter, untuk pilihan filter.
  final List<RecruiterJobStats> jobs;

  /// Filter yang sedang aktif. Null berarti tanpa filter.
  final int? selectedJobId;
  final ValueChanged<int?>? onJobFilterChanged;

  /// Hanya 'submitted' dan 'rejected' yang didukung database.
  final String? selectedStatus;
  final ValueChanged<String?>? onStatusFilterChanged;

  /// Mengubah status satu lamaran. Null berarti tombol tidak ditampilkan.
  final Future<void> Function(RecruiterApplicantModel, String)? onUpdateStatus;

  /// Id lamaran yang sedang diperbarui, untuk menonaktifkan tombolnya saja.
  final int? updatingApplicationId;

  /// Jumlah total baris yang cocok di server (bukan hanya halaman ini).
  final int? total;

  final bool hasMore;
  final Future<void> Function()? onLoadMore;
  final bool loadingMore;

  /// Lowongan yang sedang dibuka dari dashboard; dipakai untuk judul.
  final int? initialJobId;

  bool get _hasFilters => selectedJobId != null || selectedStatus != null;

  /// Nama lowongan yang sedang difilter, bila ada.
  String? get _selectedJobTitle {
    final jobId = selectedJobId;
    if (jobId == null) return null;

    for (final job in jobs) {
      if (job.id == jobId) return job.title;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final stats = ApplicationStats.fromStatuses(
      applicants.map((applicant) => applicant.status),
    );
    final totalCount = total ?? applicants.length;

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
                                  _subtitle(totalCount),
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
                      const SizedBox(height: 12),
                      _Filters(
                        jobs: jobs,
                        selectedJobId: selectedJobId,
                        onJobFilterChanged: onJobFilterChanged,
                        selectedStatus: selectedStatus,
                        onStatusFilterChanged: onStatusFilterChanged,
                        enabled: !loading,
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
                        _RecruiterEmpty(hasFilters: _hasFilters)
                      else
                        Column(
                          children: [
                            for (
                              var index = 0;
                              index < applicants.length;
                              index++
                            ) ...[
                              if (index > 0) const SizedBox(height: 10),
                              _ApplicantCard(
                                applicant: applicants[index],
                                onUpdateStatus: onUpdateStatus,
                                updating:
                                    updatingApplicationId ==
                                    applicants[index].id,
                              ),
                            ],
                            if (hasMore && onLoadMore != null) ...[
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                key: const Key('recruiter-load-more'),
                                onPressed: loadingMore ? null : onLoadMore,
                                icon: loadingMore
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.expand_more,
                                        size: 18,
                                      ),
                                label: Text(
                                  loadingMore
                                      ? 'Memuat...'
                                      : 'Muat lebih banyak',
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: JobTrackColors.blue,
                                  side: const BorderSide(
                                    color: JobTrackColors.border,
                                  ),
                                ),
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

  /// Ringkasan jumlah pelamar. Menyebut filter aktif agar angka tidak
  /// disalahartikan sebagai total keseluruhan.
  String _subtitle(int totalCount) {
    if (totalCount == 0) {
      return _hasFilters
          ? 'Tidak ada pelamar yang cocok dengan filter ini.'
          : 'Belum ada pelamar pada lowongan milikmu.';
    }

    final jobTitle = _selectedJobTitle;
    if (jobTitle != null) {
      return '$totalCount pelamar untuk "$jobTitle".';
    }

    if (_hasFilters) {
      return '$totalCount pelamar sesuai filter.';
    }

    return '$totalCount pelamar dari lowongan milikmu.';
  }
}

/// Baris filter: lowongan dan status.
class _Filters extends StatelessWidget {
  const _Filters({
    required this.jobs,
    required this.selectedJobId,
    required this.onJobFilterChanged,
    required this.selectedStatus,
    required this.onStatusFilterChanged,
    required this.enabled,
  });

  final List<RecruiterJobStats> jobs;
  final int? selectedJobId;
  final ValueChanged<int?>? onJobFilterChanged;
  final String? selectedStatus;
  final ValueChanged<String?>? onStatusFilterChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final jobFilterEnabled = enabled && onJobFilterChanged != null;
    final statusFilterEnabled = enabled && onStatusFilterChanged != null;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Dropdown hanya muncul bila daftar lowongan tersedia; tanpa itu
        // filternya tidak punya pilihan yang bermakna.
        if (jobs.isNotEmpty && onJobFilterChanged != null)
          SizedBox(
            width: 260,
            child: DropdownButtonFormField<int?>(
              key: const Key('recruiter-filter-job'),
              initialValue: selectedJobId,
              isExpanded: true,
              decoration: _filterDecoration('Lowongan'),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Semua lowongan'),
                ),
                for (final job in jobs)
                  DropdownMenuItem<int?>(
                    value: job.id,
                    child: Text(job.title, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: jobFilterEnabled ? onJobFilterChanged : null,
            ),
          ),
        if (onStatusFilterChanged != null)
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<String?>(
              key: const Key('recruiter-filter-status'),
              initialValue: selectedStatus,
              isExpanded: true,
              decoration: _filterDecoration('Status'),
              items: const [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Semua status'),
                ),
                // Hanya status yang ada di ENUM database.
                DropdownMenuItem<String?>(
                  value: ApplicationStatus.submitted,
                  child: Text('Dikirim'),
                ),
                DropdownMenuItem<String?>(
                  value: ApplicationStatus.rejected,
                  child: Text('Ditolak'),
                ),
              ],
              onChanged: statusFilterEnabled ? onStatusFilterChanged : null,
            ),
          ),
      ],
    );
  }

  static InputDecoration _filterDecoration(String label) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      filled: true,
      fillColor: JobTrackColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: JobTrackColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: JobTrackColors.border),
      ),
    );
  }
}

class _ApplicantCard extends StatelessWidget {
  const _ApplicantCard({
    required this.applicant,
    this.onUpdateStatus,
    this.updating = false,
  });

  final RecruiterApplicantModel applicant;
  final Future<void> Function(RecruiterApplicantModel, String)? onUpdateStatus;
  final bool updating;

  @override
  Widget build(BuildContext context) {
    final updateStatus = onUpdateStatus;

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
            crossAxisAlignment: WrapCrossAlignment.center,
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
          // Hanya status yang didukung database yang bisa dipilih. Tombol
          // untuk status yang sedang aktif tidak ditampilkan agar tidak ada
          // aksi yang tidak mengubah apa pun.
          if (updateStatus != null) ...[
            const SizedBox(height: 6),
            if (updating)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (!applicant.isRejected)
                    TextButton.icon(
                      key: Key('recruiter-${applicant.id}-reject'),
                      onPressed: () => updateStatus(
                        applicant,
                        ApplicationStatus.rejected,
                      ),
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      label: const Text('Tolak'),
                      style: TextButton.styleFrom(
                        foregroundColor: JobTrackColors.danger,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: const Size(0, 34),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  if (!applicant.isSubmitted)
                    TextButton.icon(
                      key: Key('recruiter-${applicant.id}-restore'),
                      onPressed: () => updateStatus(
                        applicant,
                        ApplicationStatus.submitted,
                      ),
                      icon: const Icon(Icons.undo_rounded, size: 16),
                      label: const Text('Kembalikan ke Dikirim'),
                      style: TextButton.styleFrom(
                        foregroundColor: JobTrackColors.blue,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: const Size(0, 34),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
          ],
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
  const _RecruiterEmpty({this.hasFilters = false});

  final bool hasFilters;

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
      child: Column(
        children: [
          Icon(
            hasFilters ? Icons.filter_alt_off_outlined : Icons.people_outline,
            size: 46,
            color: JobTrackColors.navyMuted,
          ),
          const SizedBox(height: 12),
          Text(
            hasFilters ? 'Tidak ada pelamar yang cocok' : 'Belum ada pelamar',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: JobTrackColors.navy,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasFilters
                ? 'Coba ubah filter lowongan atau status.'
                : 'Pelamar untuk lowongan yang kamu miliki akan muncul di sini.',
            textAlign: TextAlign.center,
            style: const TextStyle(
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
