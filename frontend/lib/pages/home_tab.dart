import 'package:flutter/material.dart';

import '../models/application_model.dart';
import '../models/job_model.dart';
import '../models/user_model.dart';
import '../theme/jobtrack_theme.dart';
import '../widgets/application_widgets.dart';

/// Tab "Beranda": dashboard ringkasan lamaran, lowongan terbaru, dan
/// riwayat lamaran terbaru milik pengguna.
///
/// Semua data berasal dari backend: lowongan dari `GET /api/jobs` dan
/// lamaran dari `GET /api/applications`. Shell [HomePage] memuat keduanya
/// satu kali lalu meneruskannya ke sini.
class HomeTab extends StatefulWidget {
  const HomeTab({
    super.key,
    this.user,
    required this.jobs,
    required this.loadingJobs,
    required this.jobsError,
    required this.applications,
    required this.loadingApplications,
    required this.applicationsError,
    required this.onRefresh,
    required this.onShowJobs,
    required this.onShowApplications,
    required this.onOpenJob,
    required this.onOpenApplication,
  });

  final UserModel? user;
  final List<JobModel> jobs;
  final bool loadingJobs;
  final String? jobsError;
  final List<ApplicationModel> applications;
  final bool loadingApplications;
  final String? applicationsError;
  final Future<void> Function() onRefresh;
  final VoidCallback onShowJobs;
  final VoidCallback onShowApplications;
  final ValueChanged<JobModel> onOpenJob;
  final ValueChanged<ApplicationModel> onOpenApplication;

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
        final haystack = '${job.title} ${job.company} ${job.location}'
            .toLowerCase();
        return haystack.contains(_query);
      });
    }

    return result.toList();
  }

  bool get _hasFilters => _query.isNotEmpty || _selectedLocation != null;

  @override
  Widget build(BuildContext context) {
    final stats = ApplicationStats.fromApplications(widget.applications);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        return RefreshIndicator(
          onRefresh: widget.onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              isWide ? 32 : 16,
              20,
              isWide ? 32 : 16,
              32,
            ),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Greeting(user: widget.user),
                      const SizedBox(height: 20),
                      _ApplicationsOverview(
                        stats: stats,
                        loading: widget.loadingApplications,
                        error: widget.applicationsError,
                        onRetry: widget.onRefresh,
                      ),
                      const SizedBox(height: 24),
                      if (isWide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: _JobsPanel(
                                title: _hasFilters
                                    ? 'Hasil pencarian'
                                    : 'Lowongan terbaru',
                                searchController: _searchController,
                                locations: _locations,
                                selectedLocation: _selectedLocation,
                                onLocationSelected: (value) =>
                                    setState(() => _selectedLocation = value),
                                jobs: _filteredJobs,
                                loading: widget.loadingJobs,
                                error: widget.jobsError,
                                hasFilters: _hasFilters,
                                onRetry: widget.onRefresh,
                                onShowJobs: widget.onShowJobs,
                                onOpenJob: widget.onOpenJob,
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 2,
                              child: _RecentApplicationsPanel(
                                applications: widget.applications,
                                loading: widget.loadingApplications,
                                error: widget.applicationsError,
                                onRetry: widget.onRefresh,
                                onShowApplications: widget.onShowApplications,
                                onShowJobs: widget.onShowJobs,
                                onOpenApplication: widget.onOpenApplication,
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _JobsPanel(
                          title: _hasFilters
                              ? 'Hasil pencarian'
                              : 'Lowongan terbaru',
                          searchController: _searchController,
                          locations: _locations,
                          selectedLocation: _selectedLocation,
                          onLocationSelected: (value) =>
                              setState(() => _selectedLocation = value),
                          jobs: _filteredJobs,
                          loading: widget.loadingJobs,
                          error: widget.jobsError,
                          hasFilters: _hasFilters,
                          onRetry: widget.onRefresh,
                          onShowJobs: widget.onShowJobs,
                          onOpenJob: widget.onOpenJob,
                        ),
                        const SizedBox(height: 24),
                        _RecentApplicationsPanel(
                          applications: widget.applications,
                          loading: widget.loadingApplications,
                          error: widget.applicationsError,
                          onRetry: widget.onRefresh,
                          onShowApplications: widget.onShowApplications,
                          onShowJobs: widget.onShowJobs,
                          onOpenApplication: widget.onOpenApplication,
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
          'Pantau lamaran dan temukan peluang karier berikutnya.',
          style: TextStyle(fontSize: 14.5, color: JobTrackColors.navyMuted),
        ),
      ],
    );
  }
}

/// Tiga angka utama: total lamaran, status Dikirim, dan status Ditolak.
class _ApplicationsOverview extends StatelessWidget {
  const _ApplicationsOverview({
    required this.stats,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final ApplicationStats stats;
  final bool loading;
  final String? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ringkasan lamaran',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: JobTrackColors.navy,
          ),
        ),
        const SizedBox(height: 3),
        const Text(
          'Berdasarkan seluruh riwayat lamaran akun ini.',
          style: TextStyle(fontSize: 12.5, color: JobTrackColors.navyMuted),
        ),
        const SizedBox(height: 12),
        if (loading)
          const _PanelLoading(label: 'Memuat ringkasan lamaran...')
        else if (error != null)
          _InlineError(message: error!, onRetry: onRetry)
        else
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  value: stats.total,
                  label: 'Total lamaran',
                  icon: Icons.assignment_outlined,
                  color: JobTrackColors.navy,
                  background: const Color(0xFFF1F5F9),
                  valueKey: const Key('dashboard-stat-total'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  value: stats.submitted,
                  label: 'Dikirim',
                  icon: Icons.send_outlined,
                  color: JobTrackColors.blue,
                  background: JobTrackColors.blueSoft,
                  valueKey: const Key('dashboard-stat-submitted'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  value: stats.rejected,
                  label: 'Ditolak',
                  icon: Icons.cancel_outlined,
                  color: JobTrackColors.danger,
                  background: JobTrackColors.dangerSoft,
                  valueKey: const Key('dashboard-stat-rejected'),
                ),
              ),
            ],
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

/// Panel lowongan terbaru beserta pencarian dan filter lokasi.
class _JobsPanel extends StatelessWidget {
  const _JobsPanel({
    required this.title,
    required this.searchController,
    required this.locations,
    required this.selectedLocation,
    required this.onLocationSelected,
    required this.jobs,
    required this.loading,
    required this.error,
    required this.hasFilters,
    required this.onRetry,
    required this.onShowJobs,
    required this.onOpenJob,
  });

  final String title;
  final TextEditingController searchController;
  final List<String> locations;
  final String? selectedLocation;
  final ValueChanged<String?> onLocationSelected;
  final List<JobModel> jobs;
  final bool loading;
  final String? error;
  final bool hasFilters;
  final Future<void> Function() onRetry;
  final VoidCallback onShowJobs;
  final ValueChanged<JobModel> onOpenJob;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: title,
          actionLabel: 'Lihat semua',
          actionKey: const Key('dashboard-open-jobs'),
          onAction: onShowJobs,
        ),
        const SizedBox(height: 12),
        _SearchBar(controller: searchController),
        if (locations.isNotEmpty) ...[
          const SizedBox(height: 12),
          _LocationFilter(
            locations: locations,
            selected: selectedLocation,
            onSelected: onLocationSelected,
          ),
        ],
        const SizedBox(height: 16),
        if (loading)
          const _PanelLoading(label: 'Memuat lowongan...')
        else if (error != null)
          _InlineError(message: error!, onRetry: onRetry)
        else if (jobs.isEmpty)
          _EmptyState(
            icon: Icons.work_off_outlined,
            message: hasFilters
                ? 'Tidak ada lowongan yang cocok dengan pencarian.'
                : 'Belum ada lowongan tersedia.',
            actionLabel: hasFilters ? null : 'Buka semua lowongan',
            actionKey: const Key('dashboard-empty-jobs-cta'),
            onAction: hasFilters ? null : onShowJobs,
          )
        else
          Column(
            children: [
              for (var index = 0; index < jobs.take(5).length; index++) ...[
                if (index > 0) const SizedBox(height: 12),
                _HomeJobCard(
                  job: jobs[index],
                  onTap: () => onOpenJob(jobs[index]),
                ),
              ],
            ],
          ),
      ],
    );
  }
}

/// Panel lima lamaran terbaru. Tombol "Lihat semua" membuka tab Lamaran.
class _RecentApplicationsPanel extends StatelessWidget {
  const _RecentApplicationsPanel({
    required this.applications,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onShowApplications,
    required this.onShowJobs,
    required this.onOpenApplication,
  });

  final List<ApplicationModel> applications;
  final bool loading;
  final String? error;
  final Future<void> Function() onRetry;
  final VoidCallback onShowApplications;
  final VoidCallback onShowJobs;
  final ValueChanged<ApplicationModel> onOpenApplication;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Lamaran terbaru',
          actionLabel: 'Lihat semua',
          actionKey: const Key('dashboard-open-applications'),
          onAction: onShowApplications,
        ),
        const SizedBox(height: 12),
        if (loading)
          const _PanelLoading(label: 'Memuat lamaran...')
        else if (error != null)
          _InlineError(message: error, onRetry: onRetry)
        else if (applications.isEmpty)
          _EmptyState(
            icon: Icons.assignment_outlined,
            message: 'Belum ada lamaran. Temukan lowongan yang cocok lalu kirim lamaran pertamamu.',
            actionLabel: 'Jelajahi lowongan',
            actionKey: const Key('dashboard-empty-applications-cta'),
            onAction: onShowJobs,
          )
        else
          Column(
            children: [
              for (
                var index = 0;
                index < applications.take(5).length;
                index++
              ) ...[
                if (index > 0) const SizedBox(height: 10),
                ApplicationCard(
                  application: applications[index],
                  onTap: () => onOpenApplication(applications[index]),
                ),
              ],
            ],
          ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.actionKey,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final Key actionKey;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: JobTrackColors.navy,
            ),
          ),
        ),
        TextButton(
          key: actionKey,
          onPressed: onAction,
          style: TextButton.styleFrom(
            foregroundColor: JobTrackColors.blue,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            minimumSize: const Size(0, 36),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            actionLabel,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
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
                color: selected == null
                    ? JobTrackColors.blue
                    : JobTrackColors.navyMuted,
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
  const _EmptyState({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.actionKey,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final Key? actionKey;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: BoxDecoration(
        color: JobTrackColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: JobTrackColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 30, color: JobTrackColors.navyMuted),
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
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 6),
            TextButton(
              key: actionKey,
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _HomeJobCard extends StatelessWidget {
  const _HomeJobCard({required this.job, required this.onTap});

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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
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
                    const SizedBox(height: 2),
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
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 15,
                          color: JobTrackColors.navyMuted,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            job.location.isEmpty
                                ? 'Lokasi tidak dicantumkan'
                                : job.location,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: JobTrackColors.navyMuted,
                            ),
                          ),
                        ),
                        if (job.createdAt != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            _formatDate(job.createdAt!),
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: JobTrackColors.navyMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: JobTrackColors.navyMuted),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}
