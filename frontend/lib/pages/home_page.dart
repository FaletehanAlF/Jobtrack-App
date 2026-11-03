import 'package:flutter/material.dart';

import '../controllers/recruiter_applicants_controller.dart';
import '../models/application_model.dart';
import '../models/job_model.dart';
import '../models/recruiter_model.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/application_service.dart';
import '../services/auth_service.dart';
import '../services/job_service.dart';
import '../services/recruiter_service.dart';
import '../theme/jobtrack_theme.dart';
import '../widgets/home_account_menu.dart';
import '../widgets/jobtrack_brand.dart';
import 'applications_page.dart';
import 'home_navigation.dart';
import 'home_tab.dart';
import 'job_form_page.dart';
import 'jobs_page.dart';
import 'login_page.dart';
import 'profile_page.dart';
import 'recruiter_applicants_page.dart';
import 'recruiter_dashboard_page.dart';
import 'saved_jobs_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.user,
    this.jobService,
    this.applicationService,
    this.authService,
    this.recruiterService,
  });

  final UserModel? user;

  final JobService? jobService;

  final ApplicationService? applicationService;

  final AuthService? authService;

  final RecruiterService? recruiterService;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final AuthService _authService = widget.authService ?? AuthService();
  late final RecruiterService _recruiterService =
      widget.recruiterService ?? RecruiterService();
  late final RecruiterApplicantsController _applicants =
      RecruiterApplicantsController(service: _recruiterService);

  UserModel? _user;
  bool _loadingUser = true;
  bool _loggingOut = false;
  int _currentIndex = 0;

  List<JobModel> _jobs = const [];
  bool _loadingJobs = true;
  String? _jobsError;

  List<ApplicationModel> _applications = const [];
  bool _loadingApplications = true;
  String? _applicationsError;

  RecruiterDashboardData? _recruiterDashboard;
  bool _loadingRecruiterDashboard = true;
  String? _recruiterDashboardError;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _applicants.addListener(_onControllerChanged);
    _loadUser();
    _loadJobs();
  }

  @override
  void dispose() {
    _applicants
      ..removeListener(_onControllerChanged)
      ..dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadJobs() async {
    final jobService = widget.jobService ?? JobService();

    if (mounted) {
      setState(() {
        _loadingJobs = true;
        _jobsError = null;
      });
    }

    try {
      final jobs = await jobService.fetchJobs();
      if (!mounted) return;
      setState(() {
        _jobs = jobs;
        _loadingJobs = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _jobsError = error.toString();
        _loadingJobs = false;
      });
    }
  }

  Future<void> _loadUser() async {
    var user = _user;

    if (user == null) {
      try {
        user = await _authService.getCurrentUser();
        if (!mounted) return;

        if (user == null) {
          _goToLogin();
          return;
        }
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _loadingUser = false;
          _loadingApplications = false;
        });
        _applicants.reset();
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      _user = user;
      _loadingUser = false;
    });

    if (user.role == 'jobseeker') {
      await _loadApplications();
    } else if (user.role == 'recruiter') {
      await _loadRecruiterDashboard();
      await _loadRecruiterApplicants();
    }

    if (mounted && user.role != 'jobseeker' && user.role != 'recruiter') {
      setState(() {
        _applications = const [];
        _loadingApplications = false;
        _applicationsError = null;
      });
      _applicants.reset();
    }
  }

  Future<void> _loadApplications() async {
    if (_user?.role != 'jobseeker') {
      if (!mounted) return;
      setState(() {
        _applications = const [];
        _loadingApplications = false;
        _applicationsError = null;
      });
      return;
    }

    final applicationService =
        widget.applicationService ?? ApplicationService();

    if (mounted) {
      setState(() {
        _loadingApplications = true;
        _applicationsError = null;
      });
    }

    try {
      final applications = await applicationService.fetchApplications();
      if (!mounted) return;
      setState(() {
        _applications = applications;
        _loadingApplications = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _applicationsError = error.toString();
        _loadingApplications = false;
      });
    }
  }

  Future<void> _loadRecruiterApplicants() async {
    if (_user?.role != 'recruiter') {
      _applicants.reset();
      return;
    }

    await _applicants.load();
  }

  Future<void> _loadMoreApplicants() async {
    try {
      await _applicants.loadMore();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat pelamar berikutnya: $error')),
      );
    }
  }

  Future<void> _loadRecruiterDashboard() async {
    if (_user?.role != 'recruiter') {
      if (!mounted) return;
      setState(() {
        _recruiterDashboard = null;
        _loadingRecruiterDashboard = false;
        _recruiterDashboardError = null;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _loadingRecruiterDashboard = true;
        _recruiterDashboardError = null;
      });
    }

    try {
      final dashboard = await _recruiterService.fetchDashboard();
      if (!mounted) return;
      setState(() {
        _recruiterDashboard = dashboard;
        _loadingRecruiterDashboard = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _recruiterDashboardError = error.toString();
        _loadingRecruiterDashboard = false;
      });
    }
  }

  Future<void> _setApplicantJobFilter(int? jobId) async {
    await _applicants.setJobFilter(jobId);
  }

  Future<void> _setApplicantStatusFilter(String? status) async {
    await _applicants.setStatusFilter(status);
  }

  Future<void> _updateApplicationStatus(
    RecruiterApplicantModel applicant,
    String status,
  ) async {
    if (_applicants.updatingId != null) return;

    try {
      final updated = await _applicants.updateStatus(applicant, status);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Status lamaran ${updated.applicantUsername} diubah menjadi '
            '"${updated.statusLabel}".',
          ),
        ),
      );

      await _loadRecruiterDashboard();
    } catch (error) {
      if (!mounted) return;

      final message = error is ApiException ? error.message : error.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengubah status: $message')),
      );
    }
  }

  Future<void> _openApplicantsForJob(RecruiterJobStats job) async {
    _applicants.applyFilters(jobId: job.id);
    setState(() => _currentIndex = 2);
    await _loadRecruiterApplicants();
  }

  Future<void> _refreshDashboard() async {
    await Future.wait([
      _loadJobs(),
      if (_user?.role == 'jobseeker') _loadApplications(),
      if (_user?.role == 'recruiter') ...[
        _loadRecruiterDashboard(),
        _loadRecruiterApplicants(),
      ],
    ]);
  }

  void _selectTab(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
  }

  void _openJob(JobModel job) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            JobDetailPage(job: job, onApplied: () => _loadApplications()),
      ),
    );
  }

  Future<void> _openJobForm({JobModel? job}) async {
    final saved = await Navigator.of(context).push<JobModel>(
      MaterialPageRoute(
        builder: (_) => JobFormPage(job: job, jobService: widget.jobService),
      ),
    );

    if (!mounted || saved == null) return;

    await _refreshDashboard();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          job == null
              ? 'Lowongan "${saved.title}" berhasil dibuat.'
              : 'Lowongan "${saved.title}" berhasil diperbarui.',
        ),
      ),
    );
  }

  Future<void> _deleteJob(JobModel job) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus lowongan?'),
        content: Text(
          'Lowongan "${job.title}" beserta lamaran yang masuk akan dihapus '
          'permanen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            key: const Key('confirm-delete-job-button'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: JobTrackColors.danger),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await (widget.jobService ?? JobService()).deleteJob(job.id);
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiException ? error.message : error.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghapus lowongan: $message')),
      );
      return;
    }

    if (!mounted) return;
    await _refreshDashboard();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Lowongan "${job.title}" berhasil dihapus.')),
    );
  }

  Future<void> _openApplication(ApplicationModel application) async {
    JobModel? matchingJob;

    for (final job in _jobs) {
      if (job.id == application.jobId) {
        matchingJob = job;
        break;
      }
    }

    var job = matchingJob;

    if (job == null) {
      try {
        job = await (widget.jobService ?? JobService()).fetchJob(
          application.jobId,
        );
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
        return;
      }
    }

    if (!mounted) return;
    _openJob(job);
  }

  void _goToLogin() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  Future<void> _confirmLogout() async {
    if (_loggingOut) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text(
          'Kamu perlu masuk kembali untuk mengakses JobTrack.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            key: const Key('confirm-logout-button'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: JobTrackColors.danger),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await _logout();
  }

  Future<void> _logout() async {
    if (_loggingOut) return;

    setState(() => _loggingOut = true);

    try {
      await _authService.logout();
    } catch (error) {
      if (!mounted) return;
      setState(() => _loggingOut = false);
      final message = error is ApiException ? error.message : error.toString();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal keluar: $message')));
      return;
    }

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingUser && _user == null) {
      return const Scaffold(
        backgroundColor: JobTrackColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isJobseeker = _user?.role == 'jobseeker';
    final isRecruiter = _user?.role == 'recruiter';

    final pages = isRecruiter
        ? <Widget>[
            RecruiterDashboardPage(
              data: _recruiterDashboard,
              loading: _loadingRecruiterDashboard,
              error: _recruiterDashboardError,
              onRefresh: _refreshDashboard,
              onOpenApplicants: _openApplicantsForJob,
              userName: _user?.username,
            ),
            JobsPage(
              jobs: _jobs,
              loading: _loadingJobs,
              error: _jobsError,
              onRefresh: _refreshDashboard,
              currentUserId: _user?.id,
              onCreateJob: () => _openJobForm(),
              onEditJob: (job) => _openJobForm(job: job),
              onDeleteJob: _deleteJob,
            ),
            RecruiterApplicantsPage(
              applicants: _applicants.applicants,
              loading: _applicants.loading,
              error: _applicants.error,
              onRefresh: _refreshDashboard,
              applicationService: widget.applicationService,
              jobs: _recruiterDashboard?.jobs ?? const [],
              selectedJobId: _applicants.jobFilter,
              onJobFilterChanged: _setApplicantJobFilter,
              selectedStatus: _applicants.statusFilter,
              onStatusFilterChanged: _setApplicantStatusFilter,
              onUpdateStatus: _updateApplicationStatus,
              updatingApplicationId: _applicants.updatingId,
              total: _applicants.total,
              hasMore: _applicants.hasMore,
              onLoadMore: _loadMoreApplicants,
              loadingMore: _applicants.loadingMore,
            ),
            ProfilePage(user: _user, onLogout: _confirmLogout),
          ]
        : <Widget>[
            HomeTab(
              user: _user,
              jobs: _jobs,
              loadingJobs: _loadingJobs,
              jobsError: _jobsError,
              applications: isJobseeker ? _applications : const [],
              loadingApplications: isJobseeker && _loadingApplications,
              applicationsError: isJobseeker ? _applicationsError : null,
              onRefresh: _refreshDashboard,
              onShowJobs: () => _selectTab(1),
              onShowApplications: () => _selectTab(2),
              onOpenJob: _openJob,
              onOpenApplication: _openApplication,
            ),
            JobsPage(
              jobs: _jobs,
              loading: _loadingJobs,
              error: _jobsError,
              onRefresh: _loadJobs,
            ),
            ApplicationsPage(
              applications: isJobseeker ? _applications : const [],
              loading: isJobseeker && _loadingApplications,
              error: isJobseeker ? _applicationsError : null,
              canView: isJobseeker,
              onRefresh: _loadApplications,
              onOpenApplication: _openApplication,
              onShowJobs: () => _selectTab(1),
              applicationService: widget.applicationService,
            ),
            const SavedJobsPage(),
            ProfilePage(user: _user, onLogout: _confirmLogout),
          ];

    final titles = isRecruiter
        ? HomeNavigation.recruiterTitles
        : HomeNavigation.jobseekerTitles;
    final bottomItems = isRecruiter
        ? HomeNavigation.recruiterBottomItems
        : HomeNavigation.jobseekerBottomItems;
    final railDestinations = isRecruiter
        ? HomeNavigation.recruiterRailDestinations
        : HomeNavigation.jobseekerRailDestinations;
    final maxIndex = pages.length - 1;
    final currentIndex = _currentIndex > maxIndex ? maxIndex : _currentIndex;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final isExtended = constraints.maxWidth >= 1200;
        final content = IndexedStack(index: currentIndex, children: pages);

        final scaffold = Scaffold(
      backgroundColor: JobTrackColors.background,
      appBar: AppBar(
        backgroundColor: JobTrackColors.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        foregroundColor: JobTrackColors.navy,
        centerTitle: false,
        titleSpacing: 16,
        shape: const Border(
          bottom: BorderSide(color: JobTrackColors.border),
        ),
        title: currentIndex == 0
            ? (isWide ? null : const JobTrackBrand(logoSize: 30))
            : Text(
                titles[currentIndex],
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: JobTrackColors.navy,
                ),
              ),
        actions: [
          HomeAccountMenu(user: _user, onLogout: _confirmLogout),
          const SizedBox(width: 8),
        ],
      ),
      body: content,
      bottomNavigationBar: isWide
          ? null
          : BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: currentIndex,
              onTap: _selectTab,
              selectedItemColor: JobTrackColors.blue,
              unselectedItemColor: JobTrackColors.navyMuted,
              backgroundColor: JobTrackColors.surface,
              showUnselectedLabels: true,
              items: bottomItems,
            ),
    );

        return ColoredBox(
      color: JobTrackColors.surface,
      child: SafeArea(
        top: isWide,
        left: isWide,
        right: isWide,
        bottom: false,
        child: Row(
          children: [
            if (isWide) ...[
              SizedBox(
                width: isExtended ? 220 : 76,
                child: Material(
                  color: JobTrackColors.surface,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          isExtended ? 16 : 0,
                          12,
                          isExtended ? 16 : 0,
                          24,
                        ),
                        child: SizedBox(
                          height: 36,
                          child: isExtended
                              ? const Align(
                                  alignment: Alignment.centerLeft,
                                  child: JobTrackBrand(logoSize: 30),
                                )
                              : const Center(
                                  child: JobTrackBrand(
                                    logoSize: 34,
                                    showText: false,
                                  ),
                                ),
                        ),
                      ),
                      Expanded(
                        child: NavigationRail(
                          extended: isExtended,
                          labelType: isExtended
                              ? NavigationRailLabelType.none
                              : NavigationRailLabelType.all,
                          minWidth: 76,
                          minExtendedWidth: 220,
                          backgroundColor: JobTrackColors.surface,
                          indicatorColor: JobTrackColors.blueSoft,
                          selectedIconTheme: const IconThemeData(
                            color: JobTrackColors.blue,
                          ),
                          unselectedIconTheme: const IconThemeData(
                            color: JobTrackColors.navyMuted,
                          ),
                          selectedLabelTextStyle: const TextStyle(
                            color: JobTrackColors.blue,
                            fontWeight: FontWeight.w700,
                          ),
                          unselectedLabelTextStyle: const TextStyle(
                            color: JobTrackColors.navyMuted,
                            fontWeight: FontWeight.w600,
                          ),
                          selectedIndex: currentIndex,
                          onDestinationSelected: _selectTab,
                          destinations: railDestinations,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const VerticalDivider(
                width: 1,
                thickness: 1,
                color: JobTrackColors.border,
              ),
            ],
            Expanded(
              key: const ValueKey('home-main-area'),
              child: scaffold,
            ),
          ],
        ),
      ),
    );
      },
    );
  }
}
