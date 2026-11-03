import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/cv_file.dart';
import '../models/job_model.dart';
import '../services/application_service.dart';
import '../theme/jobtrack_theme.dart';
import '../utils/cv_file_picker.dart';

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

class JobDetailPage extends StatefulWidget {
  const JobDetailPage({
    super.key,
    required this.job,
    this.onApplied,
  });

  final JobModel job;
  final Future<void> Function()? onApplied;

  @override
  State<JobDetailPage> createState() => _JobDetailPageState();
}

class _JobDetailPageState extends State<JobDetailPage> {
  PickedCvFile? _cv;
  bool _submitting = false;
  String? _submitError;

  Future<void> _submitApplication() async {
    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      await ApplicationService().createApplication(
        jobId: widget.job.id,
        cv: _cv,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _cv == null
                ? 'Lamaran untuk "${widget.job.title}" berhasil dikirim.'
                : 'Lamaran dengan CV berhasil dikirim.',
          ),
        ),
      );

      if (widget.onApplied != null) {
        await widget.onApplied!();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _pickCv() async {
    final file = await pickCvFile();
    if (file == null) return;

    if (file.name.isNotEmpty && !file.name.toLowerCase().endsWith('.pdf')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hanya file PDF yang diterima.')),
      );
      return;
    }

    if (file.size > 5 * 1024 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ukuran CV maksimal 5 MB.')),
      );
      return;
    }

    setState(() => _cv = file);
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: JobTrackColors.background,
      appBar: AppBar(
        backgroundColor: JobTrackColors.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        foregroundColor: JobTrackColors.navy,
        title: Text(
          'Detail Lowongan',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: JobTrackColors.navy,
          ),
        ),
        shape: const Border(bottom: BorderSide(color: JobTrackColors.border)),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth >= 900 ? 32.0 : 16.0;

            return ListView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                20,
                horizontalPadding,
                32,
              ),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _DetailCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                job.title,
                                style: textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: JobTrackColors.navy,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                job.company,
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: JobTrackColors.blue,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _MetaChip(
                                    key: const Key('job-detail-location'),
                                    icon: Icons.location_on_outlined,
                                    label: job.location.isEmpty
                                        ? 'Lokasi tidak dicantumkan'
                                        : job.location,
                                  ),
                                  _MetaChip(
                                    key: const Key('job-detail-created-at'),
                                    icon: Icons.calendar_today_outlined,
                                    label:
                                        'Dibuat ${_formatDate(job.createdAt)}',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _DetailCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.description_outlined,
                                    size: 18,
                                    color: JobTrackColors.blue,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Deskripsi',
                                    style: textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: JobTrackColors.navy,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                job.description.isEmpty
                                    ? 'Deskripsi belum diisi.'
                                    : job.description,
                                style: textTheme.bodyMedium?.copyWith(
                                  fontSize: 14.5,
                                  height: 1.7,
                                  color: JobTrackColors.navy,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _DetailCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Ajukan Lamaran',
                                    style: textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: JobTrackColors.navy,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'CV bersifat opsional (maksimal 5 MB, hanya PDF).',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: JobTrackColors.navyMuted,
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (_cv != null)
                                Container(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: JobTrackColors.blueSoft,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.check_circle_outline,
                                        size: 16,
                                        color: JobTrackColors.blue,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          _cv!.name,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: JobTrackColors.navy,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        iconSize: 16,
                                        icon: const Icon(Icons.close),
                                        onPressed: () => setState(() => _cv = null),
                                      ),
                                    ],
                                  ),
                                ),
                              if (_submitError != null && _submitError!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    _submitError!,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: JobTrackColors.danger,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.start,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: _submitting ? null : _pickCv,
                                    icon: const Icon(
                                      Icons.attach_file,
                                      size: 16,
                                    ),
                                    label: const Text('Pilih CV'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: JobTrackColors.navy,
                                      side: const BorderSide(
                                        color: JobTrackColors.border,
                                      ),
                                    ),
                                  ),
                                  FilledButton(
                                    onPressed: _submitting ? null : _submitApplication,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: JobTrackColors.blue,
                                    ),
                                    child: _submitting
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text('Kirim Lamaran'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: JobTrackColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: JobTrackColors.border),
      ),
      child: child,
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: JobTrackColors.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: JobTrackColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: JobTrackColors.navyMuted),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: JobTrackColors.navyMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
