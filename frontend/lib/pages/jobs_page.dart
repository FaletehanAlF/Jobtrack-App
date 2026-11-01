import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/job_model.dart';
import '../theme/jobtrack_theme.dart';

class JobsPage extends StatelessWidget {
  const JobsPage({
    super.key,
    required this.jobs,
    required this.loading,
    required this.error,
    required this.onRefresh,
    this.currentUserId,
    this.onCreateJob,
    this.onEditJob,
    this.onDeleteJob,
  });

  final List<JobModel> jobs;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;

  /// ID pengguna yang sedang login, dipakai untuk menentukan lowongan mana
  /// yang boleh diubah atau dihapus oleh recruiter.
  final int? currentUserId;

  final Future<void> Function()? onCreateJob;
  final Future<void> Function(JobModel job)? onEditJob;
  final Future<void> Function(JobModel job)? onDeleteJob;

  bool _canManage(JobModel job) {
    return (onEditJob != null || onDeleteJob != null) &&
        currentUserId != null &&
        job.recruiterId == currentUserId;
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = onCreateJob != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth >= 900 ? 32.0 : 16.0;

        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              16,
              horizontalPadding,
              32,
            ),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (canCreate) ...[
                        _ManageHeader(onCreateJob: onCreateJob!),
                        const SizedBox(height: 14),
                      ],
                      if (loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 48),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (error != null)
                        _JobsError(message: error!, onRetry: onRefresh)
                      else if (jobs.isEmpty)
                        _JobsEmpty(canCreate: canCreate)
                      else
                        Column(
                          children: [
                            for (
                              var index = 0;
                              index < jobs.length;
                              index++
                            ) ...[
                              if (index > 0) const SizedBox(height: 12),
                              _JobCard(
                                job: jobs[index],
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          JobDetailPage(job: jobs[index]),
                                    ),
                                  );
                                },
                                onEdit: _canManage(jobs[index])
                                    ? () => onEditJob?.call(jobs[index])
                                    : null,
                                onDelete: _canManage(jobs[index])
                                    ? () => onDeleteJob?.call(jobs[index])
                                    : null,
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

class _ManageHeader extends StatelessWidget {
  const _ManageHeader({required this.onCreateJob});

  final Future<void> Function() onCreateJob;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Expanded(
          child: Text(
            'Kelola lowongan yang kamu buat di sini.',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: JobTrackColors.navyMuted,
            ),
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          key: const Key('jobs-create-button'),
          onPressed: onCreateJob,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Buat lowongan'),
          style: FilledButton.styleFrom(
            backgroundColor: JobTrackColors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: GoogleFonts.montserrat(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _JobsError extends StatelessWidget {
  const _JobsError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 48),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 48,
            color: JobTrackColors.navyMuted,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: JobTrackColors.navyMuted,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: JobTrackColors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }
}

class _JobsEmpty extends StatelessWidget {
  const _JobsEmpty({this.canCreate = false});

  final bool canCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      decoration: BoxDecoration(
        color: JobTrackColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: JobTrackColors.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.work_off_outlined,
            size: 44,
            color: JobTrackColors.navyMuted,
          ),
          const SizedBox(height: 12),
          Text(
            canCreate
                ? 'Belum ada lowongan. Buat lowongan pertamamu untuk mulai '
                      'menerima pelamar.'
                : 'Belum ada lowongan tersedia.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.5,
              color: JobTrackColors.navyMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.job,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  final JobModel job;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final canManage = onEdit != null || onDelete != null;

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
                          job.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: JobTrackColors.navy,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          job.company,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: JobTrackColors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (canManage) ...[
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      key: Key('job-${job.id}-menu'),
                      tooltip: 'Kelola lowongan',
                      icon: const Icon(
                        Icons.more_vert,
                        color: JobTrackColors.navyMuted,
                      ),
                      onSelected: (value) {
                        if (value == 'edit') onEdit?.call();
                        if (value == 'delete') onDelete?.call();
                      },
                      itemBuilder: (context) => [
                        if (onEdit != null)
                          const PopupMenuItem<String>(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.edit_outlined,
                                  size: 18,
                                  color: JobTrackColors.navy,
                                ),
                                SizedBox(width: 10),
                                Text('Ubah'),
                              ],
                            ),
                          ),
                        if (onDelete != null)
                          const PopupMenuItem<String>(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: JobTrackColors.danger,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Hapus',
                                  style: TextStyle(
                                    color: JobTrackColors.danger,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: JobTrackColors.navyMuted,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      job.location,
                      style: const TextStyle(
                        fontSize: 13,
                        color: JobTrackColors.navyMuted,
                      ),
                    ),
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

class JobDetailPage extends StatelessWidget {
  const JobDetailPage({super.key, required this.job});

  final JobModel job;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JobTrackColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Detail Lowongan'),
        foregroundColor: JobTrackColors.navy,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: JobTrackColors.navy,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    job.company,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: JobTrackColors.blue,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _DetailRow(
                    icon: Icons.location_on_outlined,
                    text: job.location,
                  ),
                  _DetailRow(
                    icon: Icons.calendar_today_outlined,
                    text: _formatDate(job.createdAt),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Deskripsi',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: JobTrackColors.navy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    job.description,
                    style: const TextStyle(
                      fontSize: 14.5,
                      height: 1.6,
                      color: JobTrackColors.navy,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: JobTrackColors.navyMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: JobTrackColors.navyMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
