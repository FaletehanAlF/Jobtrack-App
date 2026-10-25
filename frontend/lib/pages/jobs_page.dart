import 'package:flutter/material.dart';

import '../models/job_model.dart';
import '../services/job_service.dart';
import '../theme/jobtrack_theme.dart';

/// Halaman daftar lowongan.
class JobsPage extends StatefulWidget {
  const JobsPage({super.key});

  @override
  State<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> {
  final _jobService = JobService();

  bool _loading = true;
  String? _error;
  List<JobModel> _jobs = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final jobs = await _jobService.fetchJobs();
      if (!mounted) return;
      setState(() {
        _jobs = jobs;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined,
                  size: 48, color: JobTrackColors.navyMuted),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: JobTrackColors.navyMuted,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _load,
                style: ElevatedButton.styleFrom(
                  backgroundColor: JobTrackColors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    if (_jobs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'Belum ada lowongan tersedia.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14.5, color: JobTrackColors.navyMuted),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _jobs.length,
        separatorBuilder: (context, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final job = _jobs[index];
          return _JobCard(
            job: job,
            onTap: () => _openDetail(context, job),
          );
        },
      ),
    );
  }

  void _openDetail(BuildContext context, JobModel job) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => JobDetailPage(job: job)),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job, required this.onTap});

  final JobModel job;
  final VoidCallback onTap;

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
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 16, color: JobTrackColors.navyMuted),
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
          _DetailRow(icon: Icons.location_on_outlined, text: job.location),
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
    );
  }

  String _formatDate(DateTime date) {
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
