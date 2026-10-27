import 'package:flutter/material.dart';

import '../models/recruiter_model.dart';
import '../theme/jobtrack_theme.dart';

/// Dashboard recruiter: ringkasan angka dan daftar lowongan miliknya.
///
/// Semua data berasal dari `GET /api/recruiter/dashboard`, yang sudah
/// dibatasi `jobs.recruiter_id` dari token di backend. Halaman ini tidak
/// menghitung ulang statistik dari data mentah: angka datang dari COUNT
/// di database.
class RecruiterDashboardPage extends StatelessWidget {
  const RecruiterDashboardPage({
    super.key,
    required this.data,
    required this.loading,
    required this.error,
    required this.onRefresh,
    required this.onOpenApplicants,
    this.userName,
  });

  final RecruiterDashboardData? data;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;

  /// Membuka daftar pelamar, terfilter pada satu lowongan.
  final ValueChanged<RecruiterJobStats> onOpenApplicants;

  final String? userName;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final horizontalPadding = isWide ? 32.0 : 16.0;

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
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Greeting(userName: userName),
                      const SizedBox(height: 20),
                      if (loading && data == null)
                        const _PanelLoading(label: 'Memuat dashboard...')
                      else if (error != null && data == null)
                        _InlineError(message: error!, onRetry: onRefresh)
                      else if (data != null) ...[
                        _StatsOverview(
                          stats: data!.stats,
                          loading: loading,
                          error: error,
                          onRetry: onRefresh,
                        ),
                        const SizedBox(height: 24),
                        _JobsPanel(
                          jobs: data!.jobs,
                          onRefresh: onRefresh,
                          onOpenApplicants: onOpenApplicants,
                        ),
                      ],
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

class _Greeting extends StatelessWidget {
  const _Greeting({this.userName});

  final String? userName;

  @override
  Widget build(BuildContext context) {
    final name = userName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name == null || name.isEmpty ? 'Dashboard Recruiter' : 'Halo, $name!',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: JobTrackColors.navy,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Ringkasan lowongan dan pelamar dari lowongan milikmu.',
          style: TextStyle(fontSize: 14.5, color: JobTrackColors.navyMuted),
        ),
      ],
    );
  }
}

/// Empat angka utama. Semuanya berasal dari COUNT di database.
class _StatsOverview extends StatelessWidget {
  const _StatsOverview({
    required this.stats,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final RecruiterDashboardStats stats;
  final bool loading;
  final String? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ringkasan',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: JobTrackColors.navy,
          ),
        ),
        const SizedBox(height: 3),
        const Text(
          'Dihitung dari lowongan yang kamu miliki.',
          style: TextStyle(fontSize: 12.5, color: JobTrackColors.navyMuted),
        ),
        const SizedBox(height: 12),
        // Error saat data lama masih ada ditampilkan inline, bukan
        // menggantikan angka yang sudah tampil.
        if (error != null) ...[
          _InlineError(message: error!, onRetry: onRetry),
          const SizedBox(height: 12),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            // Dua kolom di layar sempit, empat kolom bila cukup lebar.
            final columns = constraints.maxWidth >= 720 ? 4 : 2;
            final cards = <Widget>[
              _StatCard(
                value: stats.jobs,
                label: 'Lowongan',
                icon: Icons.work_outline,
                color: JobTrackColors.navy,
                background: const Color(0xFFF1F5F9),
                valueKey: const Key('recruiter-stat-jobs'),
              ),
              _StatCard(
                value: stats.applicants,
                label: 'Total pelamar',
                icon: Icons.people_outline,
                color: JobTrackColors.blue,
                background: JobTrackColors.blueSoft,
                valueKey: const Key('recruiter-stat-applicants'),
              ),
              _StatCard(
                value: stats.submitted,
                label: 'Dikirim',
                icon: Icons.send_outlined,
                color: JobTrackColors.blue,
                background: JobTrackColors.blueSoft,
                valueKey: const Key('recruiter-stat-submitted'),
              ),
              _StatCard(
                value: stats.rejected,
                label: 'Ditolak',
                icon: Icons.cancel_outlined,
                color: JobTrackColors.danger,
                background: JobTrackColors.dangerSoft,
                valueKey: const Key('recruiter-stat-rejected'),
              ),
            ];

            return Column(
              children: [
                for (var row = 0; row < (cards.length / columns).ceil(); row++)
                  Padding(
                    padding: EdgeInsets.only(bottom: row == 0 ? 12 : 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var column = 0; column < columns; column++) ...[
                          if (column > 0) const SizedBox(width: 12),
                          Expanded(
                            child: column + row * columns < cards.length
                                ? cards[column + row * columns]
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    required this.background,
    required this.valueKey,
  });

  final int value;
  final String label;
  final IconData icon;
  final Color color;
  final Color background;
  final Key valueKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: JobTrackColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: JobTrackColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            '$value',
            key: valueKey,
            style: const TextStyle(
              fontSize: 26,
              height: 1,
              fontWeight: FontWeight.w800,
              color: JobTrackColors.navy,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: JobTrackColors.navyMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Daftar lowongan milik recruiter beserta jumlah pelamarnya.
class _JobsPanel extends StatelessWidget {
  const _JobsPanel({
    required this.jobs,
    required this.onRefresh,
    required this.onOpenApplicants,
  });

  final List<RecruiterJobStats> jobs;
  final Future<void> Function() onRefresh;
  final ValueChanged<RecruiterJobStats> onOpenApplicants;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Lowongan saya',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: JobTrackColors.navy,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Muat ulang dashboard',
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              color: JobTrackColors.navyMuted,
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (jobs.isEmpty)
          const _EmptyState(
            icon: Icons.work_off_outlined,
            message:
                'Belum ada lowongan milikmu. Lowongan yang kamu buat akan '
                'muncul di sini beserta jumlah pelamarnya.',
          )
        else
          Column(
            children: [
              for (var index = 0; index < jobs.length; index++) ...[
                if (index > 0) const SizedBox(height: 10),
                _JobStatsCard(
                  job: jobs[index],
                  onOpen: () => onOpenApplicants(jobs[index]),
                ),
              ],
            ],
          ),
      ],
    );
  }
}

class _JobStatsCard extends StatelessWidget {
  const _JobStatsCard({required this.job, required this.onOpen});

  final RecruiterJobStats job;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: JobTrackColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onOpen,
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
                          job.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: JobTrackColors.navy,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          job.company,
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
                  _CountBadge(
                    key: Key('recruiter-job-${job.id}-applicants'),
                    count: job.applicantCount,
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
                    icon: Icons.location_on_outlined,
                    text: job.location.isEmpty
                        ? 'Lokasi tidak dicantumkan'
                        : job.location,
                  ),
                  _MetaItem(
                    icon: Icons.send_outlined,
                    text: '${job.submittedCount} dikirim',
                  ),
                  _MetaItem(
                    icon: Icons.cancel_outlined,
                    text: '${job.rejectedCount} ditolak',
                  ),
                  TextButton(
                    key: Key('recruiter-job-${job.id}-open'),
                    onPressed: onOpen,
                    style: TextButton.styleFrom(
                      foregroundColor: JobTrackColors.blue,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('Lihat pelamar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final isEmpty = count == 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: isEmpty ? const Color(0xFFF1F5F9) : JobTrackColors.blueSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count pelamar',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isEmpty ? JobTrackColors.navyMuted : JobTrackColors.blue,
        ),
      ),
    );
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

class _PanelLoading extends StatelessWidget {
  const _PanelLoading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: BoxDecoration(
        color: JobTrackColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: JobTrackColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: JobTrackColors.navyMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: JobTrackColors.dangerSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: JobTrackColors.dangerBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 20,
            color: JobTrackColors.danger,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: JobTrackColors.danger,
                  ),
                ),
                const SizedBox(height: 2),
                TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    foregroundColor: JobTrackColors.danger,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('recruiter-dashboard-empty'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
      decoration: BoxDecoration(
        color: JobTrackColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: JobTrackColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: JobTrackColors.navyMuted),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: JobTrackColors.navyMuted,
            ),
          ),
        ],
      ),
    );
  }
}
