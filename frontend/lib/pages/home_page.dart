import 'package:flutter/material.dart';

import 'applications_page.dart';
import 'login_page.dart';
import 'home_tab.dart';
import 'jobs_page.dart';
import 'profile_page.dart';
import 'recruiter_applicants_page.dart';
import 'recruiter_dashboard_page.dart';
import 'saved_jobs_page.dart';
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

/// Shell utama setelah login.
///
/// Jobseeker mendapat navigasi Dashboard, Lowongan, Lamaran, Tersimpan, dan
/// Profil. Recruiter mendapat Dashboard pelamar, Lowongan, dan Profil. Di
/// layar desktop, navigasi bawah diganti [NavigationRail] agar ruang vertikal
/// dashboard lebih lega.
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

  /// Bisa diisi saat pengujian agar test tidak benar-benar ke backend.
  final JobService? jobService;

  /// Bisa diisi saat pengujian agar test tidak benar-benar ke backend.
  final ApplicationService? applicationService;

  /// Bisa diisi saat pengujian agar pemeriksaan sesi tidak ke backend.
  final AuthService? authService;

  /// Bisa diisi saat pengujian agar dashboard recruiter tidak ke backend.
  final RecruiterService? recruiterService;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final AuthService _authService = widget.authService ?? AuthService();

  UserModel? _user;
  bool _loadingUser = true;
  int _currentIndex = 0;

  List<JobModel> _jobs = const [];
  bool _loadingJobs = true;
  String? _jobsError;

  List<ApplicationModel> _applications = const [];
  bool _loadingApplications = true;
  String? _applicationsError;

  List<RecruiterApplicantModel> _recruiterApplicants = const [];
  bool _loadingRecruiterApplicants = true;
  String? _recruiterApplicantsError;

  /// Ringkasan dashboard recruiter (`GET /api/recruiter/dashboard`).
  RecruiterDashboardData? _recruiterDashboard;
  bool _loadingRecruiterDashboard = true;
  String? _recruiterDashboardError;

  /// Filter dan pagination daftar pelamar. Nilai null berarti tanpa filter.
  int? _applicantJobFilter;
  String? _applicantStatusFilter;
  int? _applicantsTotal;
  bool _hasMoreApplicants = false;
  bool _loadingMoreApplicants = false;

  /// Id lamaran yang sedang diubah statusnya.
  int? _updatingApplicationId;

  /// Ukuran satu halaman daftar pelamar.
  static const int _applicantsPageSize = 50;

  RecruiterService get _recruiterService =>
      widget.recruiterService ?? RecruiterService();

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _loadUser();
    _loadJobs();
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
        // Server tidak terjangkau: tetap tampilkan shell dengan data yang ada.
        if (!mounted) return;
        setState(() {
          _loadingUser = false;
          _loadingApplications = false;
          _loadingRecruiterApplicants = false;
        });
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      _user = user;
      _loadingUser = false;
    });

    // Endpoint lamaran jobseeker dan endpoint pelamar recruiter terpisah.
    // Masing-masing hanya dipanggil untuk role yang berhak agar tidak memicu
    // 403 yang tidak perlu.
    if (user.role == 'jobseeker') {
      await _loadApplications();
    } else if (user.role == 'recruiter') {
      // Dashboard dan daftar pelamar dimuat sekali di awal; masing-masing
      // endpoint sudah dibatasi kepemilikan oleh backend.
      await _loadRecruiterDashboard();
      await _loadRecruiterApplicants();
    } else if (mounted) {
      setState(() {
        _applications = const [];
        _loadingApplications = false;
        _applicationsError = null;
        _recruiterApplicants = const [];
        _loadingRecruiterApplicants = false;
        _recruiterApplicantsError = null;
      });
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
      if (!mounted) return;
      setState(() {
        _recruiterApplicants = const [];
        _loadingRecruiterApplicants = false;
        _recruiterApplicantsError = null;
        _applicantsTotal = null;
        _hasMoreApplicants = false;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _loadingRecruiterApplicants = true;
        _recruiterApplicantsError = null;
      });
    }

    try {
      final page = await _recruiterService.fetchApplicants(
        jobId: _applicantJobFilter,
        status: _applicantStatusFilter,
        limit: _applicantsPageSize,
        offset: 0,
      );
      if (!mounted) return;
      setState(() {
        _recruiterApplicants = page.applicants;
        _applicantsTotal = page.total;
        _hasMoreApplicants = page.hasMore;
        _loadingRecruiterApplicants = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _recruiterApplicantsError = error.toString();
        _loadingRecruiterApplicants = false;
      });
    }
  }

  /// Memuat halaman pelamar berikutnya tanpa menghapus data yang sudah ada.
  Future<void> _loadMoreApplicants() async {
    if (_loadingMoreApplicants || !_hasMoreApplicants) return;

    setState(() => _loadingMoreApplicants = true);

    try {
      final page = await _recruiterService.fetchApplicants(
        jobId: _applicantJobFilter,
        status: _applicantStatusFilter,
        limit: _applicantsPageSize,
        offset: _recruiterApplicants.length,
      );
      if (!mounted) return;
      setState(() {
        _recruiterApplicants = [..._recruiterApplicants, ...page.applicants];
        _applicantsTotal = page.total;
        _hasMoreApplicants = page.hasMore;
        _loadingMoreApplicants = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingMoreApplicants = false);
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

  /// Memilih filter lowongan, lalu memuat ulang daftar pelamar.
  Future<void> _setApplicantJobFilter(int? jobId) async {
    if (_applicantJobFilter == jobId) return;
    setState(() => _applicantJobFilter = jobId);
    await _loadRecruiterApplicants();
  }

  /// Memilih filter status, lalu memuat ulang daftar pelamar.
  Future<void> _setApplicantStatusFilter(String? status) async {
    if (_applicantStatusFilter == status) return;
    setState(() => _applicantStatusFilter = status);
    await _loadRecruiterApplicants();
  }

  /// Mengubah status satu lamaran lewat backend, lalu memperbarui daftar.
  Future<void> _updateApplicationStatus(
    RecruiterApplicantModel applicant,
    String status,
  ) async {
    if (_updatingApplicationId != null) return;

    setState(() => _updatingApplicationId = applicant.id);

    try {
      final updated = await _recruiterService.updateStatus(
        applicationId: applicant.id,
        status: status,
      );

      if (!mounted) return;

      setState(() {
        _recruiterApplicants = [
          for (final item in _recruiterApplicants)
            if (item.id == updated.id) updated else item,
        ];
        _updatingApplicationId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Status lamaran ${updated.applicantUsername} diubah menjadi '
            '"${updated.statusLabel}".',
          ),
        ),
      );

      // Statistik dashboard ikut berubah saat status berubah.
      await _loadRecruiterDashboard();
    } catch (error) {
      if (!mounted) return;
      setState(() => _updatingApplicationId = null);

      final message = error is ApiException ? error.message : error.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengubah status: $message')),
      );
    }
  }

  /// Membuka daftar pelamar terfilter untuk satu lowongan.
  Future<void> _openApplicantsForJob(RecruiterJobStats job) async {
    setState(() {
      _applicantJobFilter = job.id;
      _applicantStatusFilter = null;
      _currentIndex = 2; // Tab "Pelamar" pada navigasi recruiter.
    });
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
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => JobDetailPage(job: job)));
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

  Future<void> _logout() async {
    await _authService.logout();

    if (!mounted) return;

    // Setelah logout, riwayat dibersihkan dan pengguna diarahkan ke Login.
    // `(route) => false` membuang Home (dan semua rute di bawahnya), sehingga
    // tombol Back web/sistem tidak bisa membuka kembali Home yang terlindungi.
    // Halaman Login ini juga menjadi rute akar, jadi Back tidak menutup
    // aplikasi secara tiba-tiba.
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  static const _jobseekerTitles = <String>[
    'Dashboard',
    'Lowongan',
    'Lamaran',
    'Tersimpan',
    'Profil',
  ];

  static const _recruiterTitles = <String>[
    'Dashboard',
    'Lowongan',
    'Pelamar',
    'Profil',
  ];

  static const _jobseekerRailDestinations = <NavigationRailDestination>[
    NavigationRailDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: Text('Beranda'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.work_outline),
      selectedIcon: Icon(Icons.work),
      label: Text('Lowongan'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.assignment_outlined),
      selectedIcon: Icon(Icons.assignment),
      label: Text('Lamaran'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.bookmark_border),
      selectedIcon: Icon(Icons.bookmark),
      label: Text('Tersimpan'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: Text('Profil'),
    ),
  ];

  static const _recruiterRailDestinations = <NavigationRailDestination>[
    NavigationRailDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: Text('Dashboard'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.work_outline),
      selectedIcon: Icon(Icons.work),
      label: Text('Lowongan'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.people_outline),
      selectedIcon: Icon(Icons.people),
      label: Text('Pelamar'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: Text('Profil'),
    ),
  ];

  static const _jobseekerBottomItems = <BottomNavigationBarItem>[
    BottomNavigationBarItem(
      icon: Icon(Icons.home_outlined),
      activeIcon: Icon(Icons.home),
      label: 'Beranda',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.work_outline),
      activeIcon: Icon(Icons.work),
      label: 'Lowongan',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.assignment_outlined),
      activeIcon: Icon(Icons.assignment),
      label: 'Lamaran',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.bookmark_border),
      activeIcon: Icon(Icons.bookmark),
      label: 'Tersimpan',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.person_outline),
      activeIcon: Icon(Icons.person),
      label: 'Profil',
    ),
  ];

  static const _recruiterBottomItems = <BottomNavigationBarItem>[
    BottomNavigationBarItem(
      icon: Icon(Icons.dashboard_outlined),
      activeIcon: Icon(Icons.dashboard),
      label: 'Dashboard',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.work_outline),
      activeIcon: Icon(Icons.work),
      label: 'Lowongan',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.people_outline),
      activeIcon: Icon(Icons.people),
      label: 'Pelamar',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.person_outline),
      activeIcon: Icon(Icons.person),
      label: 'Profil',
    ),
  ];

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
              onRefresh: _loadJobs,
            ),
            RecruiterApplicantsPage(
              applicants: _recruiterApplicants,
              loading: _loadingRecruiterApplicants,
              error: _recruiterApplicantsError,
              onRefresh: _refreshDashboard,
              applicationService: widget.applicationService,
              jobs: _recruiterDashboard?.jobs ?? const [],
              selectedJobId: _applicantJobFilter,
              onJobFilterChanged: _setApplicantJobFilter,
              selectedStatus: _applicantStatusFilter,
              onStatusFilterChanged: _setApplicantStatusFilter,
              onUpdateStatus: _updateApplicationStatus,
              updatingApplicationId: _updatingApplicationId,
              total: _applicantsTotal,
              hasMore: _hasMoreApplicants,
              onLoadMore: _loadMoreApplicants,
              loadingMore: _loadingMoreApplicants,
            ),
            ProfilePage(user: _user, onLogout: _logout),
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
            ProfilePage(user: _user, onLogout: _logout),
          ];

    final titles = isRecruiter ? _recruiterTitles : _jobseekerTitles;
    final railDestinations = isRecruiter
        ? _recruiterRailDestinations
        : _jobseekerRailDestinations;
    final bottomItems = isRecruiter
        ? _recruiterBottomItems
        : _jobseekerBottomItems;
    final maxIndex = pages.length - 1;
    final currentIndex = _currentIndex > maxIndex ? maxIndex : _currentIndex;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final isExtended = constraints.maxWidth >= 1200;
        final content = IndexedStack(index: currentIndex, children: pages);

        return Scaffold(
          backgroundColor: JobTrackColors.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: JobTrackColors.navy,
            title: Text(
              titles[currentIndex],
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: JobTrackColors.navy,
              ),
            ),
          ),
          body: isWide
              ? Row(
                  children: [
                    NavigationRail(
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
                      leading: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: JobTrackColors.blueSoft,
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'JT',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: JobTrackColors.blue,
                            ),
                          ),
                        ),
                      ),
                      selectedIndex: currentIndex,
                      onDestinationSelected: _selectTab,
                      destinations: railDestinations,
                    ),
                    const VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: JobTrackColors.border,
                    ),
                    Expanded(child: content),
                  ],
                )
              : content,
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
      },
    );
  }
}
