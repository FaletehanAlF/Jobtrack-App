import 'package:flutter/material.dart';

import '../models/job_model.dart';
import '../models/user_model.dart';
import '../pages/jobs_page.dart' show JobDetailPage;
import '../theme/jobtrack_theme.dart';

/// Tab "Beranda": sapaan, pencarian lowongan, ringkasan lamaran,
/// dan lowongan terbaru. Data lowongan diambil dari shell [HomePage].
class HomeTab extends StatefulWidget {
  const HomeTab({
    super.key,
    this.user,
    required this.jobs,
    required this.loading,
    required this.error,
    required this.onRefresh,
  });

  final UserModel? user;
  final List<JobModel> jobs;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final _searchController = TextEditingController();

  String _query = '';
  String? _selectedLocation;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() => _query = _searchController.text.trim().toLowerCase());
  }

  List<String> get _locations {
    final set = <String>{};
    for (final job in widget.jobs) {
      if (job.location.trim().isNotEmpty) set.add(job.location.trim());
    }
    final list = set.toList()..sort();
    return list;
  }

  List<JobModel> get _filteredJobs {
    Iterable<JobModel> result = widget.jobs;

    if (_selectedLocation != null) {
      result = result.where((job) => job.location.trim() == _selectedLocation);
    }

    if (_query.isNotEmpty) {
      result = result.where((job) {
        final haystack = '${job.title} ${job.company} ${job.location}'.toLowerCase();
        return haystack.contains(_query);
      });
    }

    return result.toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _Greeting(user: user),
          const SizedBox(height: 16),
          _SearchBar(controller: _searchController),
          if (_locations.isNotEmpty) ...[
            const SizedBox(height: 12),
            _LocationFilter(
              locations: _locations,
              selected: _selectedLocation,
              onSelected: (value) => setState(() => _selectedLocation = value),
            ),
          ],
          const SizedBox(height: 20),
          const _ApplicationSummary(),
          const SizedBox(height: 20),
          _JobsSection(
            title: _query.isEmpty && _selectedLocation == null
                ? 'Lowongan terbaru'
                : 'Hasil pencarian',
            loading: widget.loading,
            error: widget.error,
            jobs: _filteredJobs,
            onRetry: widget.onRefresh,
            emptyMessage: _query.isEmpty && _selectedLocation == null
                ? 'Belum ada lowongan tersedia.'
                : 'Tidak ada lowongan yang cocok dengan pencarian.',
          ),
        ],
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({this.user});

  final UserModel? user;

  @override
  Widget build(BuildContext context) {
    final name = user?.username;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name == null || name.isEmpty ? 'Halo!' : 'Halo, $name!',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: JobTrackColors.navy,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Temukan peluang karier yang sesuai untukmu.',
          style: TextStyle(
            fontSize: 14.5,
            color: JobTrackColors.navyMuted,
          ),
        ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Cari lowongan, perusahaan, atau lokasi',
        prefixIcon: const Icon(Icons.search, color: JobTrackColors.navyMuted),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Hapus pencarian',
                icon: const Icon(Icons.close, color: JobTrackColors.navyMuted),
                onPressed: controller.clear,
              ),
        filled: true,
        fillColor: JobTrackColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: JobTrackColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: JobTrackColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: JobTrackColors.blue, width: 1.6),
        ),
      ),
    );
  }
}

class _LocationFilter extends StatelessWidget {
  const _LocationFilter({
    required this.locations,
    required this.selected,
    required this.onSelected,
  });

  final List<String> locations;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('Semua'),
              selected: selected == null,
              onSelected: (_) => onSelected(null),
              selectedColor: JobTrackColors.blueSoft,
              labelStyle: TextStyle(
                color: selected == null ? JobTrackColors.blue : JobTrackColors.navyMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          for (final location in locations)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(location),
                selected: selected == location,
                onSelected: (_) =>
                    onSelected(selected == location ? null : location),
                selectedColor: JobTrackColors.blueSoft,
                labelStyle: TextStyle(
                  color: selected == location
                      ? JobTrackColors.blue
                      : JobTrackColors.navyMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ApplicationSummary extends StatelessWidget {
  const _ApplicationSummary();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: JobTrackColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: JobTrackColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: JobTrackColors.blueSoft,
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.assignment_outlined,
                color: JobTrackColors.blue, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status lamaran',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: JobTrackColors.navy,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Fitur lamaran belum tersedia. '
                  'Backend untuk fitur ini belum diimplementasikan.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: JobTrackColors.navyMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _JobsSection extends StatelessWidget {
  const _JobsSection({
    required this.title,
    required this.loading,
    required this.error,
    required this.jobs,
    required this.onRetry,
    required this.emptyMessage,
  });

  final String title;
  final bool loading;
  final String? error;
  final List<JobModel> jobs;
  final VoidCallback onRetry;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: JobTrackColors.navy,
          ),
        ),
        const SizedBox(height: 12),
        if (loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (error != null)
          _ErrorState(message: error!, onRetry: onRetry)
        else if (jobs.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: JobTrackColors.navyMuted,
                ),
              ),
            ),
          )
        else
          ...jobs.take(10).map((job) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _HomeJobCard(job: job),
              )),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_outlined,
              size: 40, color: JobTrackColors.navyMuted),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: JobTrackColors.navyMuted),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onRetry,
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }
}

class _HomeJobCard extends StatelessWidget {
  const _HomeJobCard({required this.job});

  final JobModel job;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: JobTrackColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => JobDetailPage(job: job)),
        ),
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
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: JobTrackColors.navy,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                job.company,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: JobTrackColors.blue,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 15, color: JobTrackColors.navyMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      job.location,
                      style: const TextStyle(
                        fontSize: 12.5,
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
