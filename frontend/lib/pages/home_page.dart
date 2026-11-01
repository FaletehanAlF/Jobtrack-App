import 'package:flutter/material.dart';

import 'applications_page.dart';
import 'job_form_page.dart';
import 'login_page.dart';
import 'home_tab.dart';
import 'jobs_page.dart';
import 'notifications_page.dart';
import 'profile_page.dart';
import 'recruiter_applicants_page.dart';
import 'recruiter_dashboard_page.dart';
import 'saved_jobs_page.dart';
import '../models/application_model.dart';
import '../models/job_model.dart';
import '../models/notification_model.dart';
import '../models/recruiter_model.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/application_service.dart';
import '../services/auth_service.dart';
import '../services/job_service.dart';
import '../services/notification_service.dart';
import '../services/recruiter_service.dart';
import '../theme/jobtrack_theme.dart';
import '../widgets/jobtrack_brand.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.user,
    this.jobService,
    this.applicationService,
    this.authService,
    this.recruiterService,
    this.notificationService,
  });

  final UserModel? user;

  final JobService? jobService;

  final ApplicationService? applicationService;

  final AuthService? authService;

  final RecruiterService? recruiterService;

  final NotificationService? notificationService;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final AuthService _authService = widget.authService ?? AuthService();

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

  List<RecruiterApplicantModel> _recruiterApplicants = const [];
  bool _loadingRecruiterApplicants = true;
  String? _recruiterApplicantsError;

  RecruiterDashboardData? _recruiterDashboard;
  bool _loadingRecruiterDashboard = true;
  String? _recruiterDashboardError;

  int? _applicantJobFilter;
  String? _applicantStatusFilter;
  int? _applicantsTotal;
  bool _hasMoreApplicants = false;
  bool _loadingMoreApplicants = false;

  int? _updatingApplicationId;

  static const int _applicantsPageSize = 50;

  List<NotificationModel> _notifications = const [];
  int _unreadNotifications = 0;
  bool _loadingNotifications = false;
  String? _notificationsError;
  bool _hasMoreNotifications = false;
  bool _loadingMoreNotifications = false;
  bool _markingAllRead = false;
  int? _updatingNotificationId;

  bool _notificationsOpened = false;

  static const int _notificationsPageSize = 50;

  NotificationService get _notificationService =>
      widget.notificationService ?? NotificationService();

  int get _notificationsTabIndex => _user?.role == 'recruiter' ? 4 : 5;

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
        if (!mounted) return;
        setState(() {
          _loadingUser = false;
          _loadingApplications = false;
          _loadingRecruiterApplicants = false;
          _loadingNotifications = false;
        });
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

    await _refreshUnreadCount();

    if (mounted && user.role != 'jobseeker' && user.role != 'recruiter') {
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

  Future<void> _setApplicantJobFilter(int? jobId) async {
    if (_applicantJobFilter == jobId) return;
    setState(() => _applicantJobFilter = jobId);
    await _loadRecruiterApplicants();
  }

  Future<void> _setApplicantStatusFilter(String? status) async {
    if (_applicantStatusFilter == status) return;
    setState(() => _applicantStatusFilter = status);
    await _loadRecruiterApplicants();
  }

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

  Future<void> _openApplicantsForJob(RecruiterJobStats job) async {
    setState(() {
      _applicantJobFilter = job.id;
      _applicantStatusFilter = null;
      _currentIndex = 2;
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
      if (_notificationsOpened) _loadNotifications() else _refreshUnreadCount(),
    ]);
  }

  Future<void> _loadNotifications() async {
    if (mounted) {
      setState(() {
        _notificationsOpened = true;
        _loadingNotifications = true;
        _notificationsError = null;
      });
    }

    try {
      final page = await _notificationService.fetchNotifications(
        limit: _notificationsPageSize,
        offset: 0,
      );
      if (!mounted) return;
      setState(() {
        _notifications = page.notifications;
        _unreadNotifications = page.unread;
        _hasMoreNotifications = page.hasMore;
        _loadingNotifications = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _notificationsError = error.toString();
        _loadingNotifications = false;
      });
    }
  }

  Future<void> _refreshUnreadCount() async {
    try {
      final unread = await _notificationService.fetchUnreadCount();
      if (!mounted) return;
      setState(() => _unreadNotifications = unread);
    } catch (_) {}
  }

  Future<void> _loadMoreNotifications() async {
    if (_loadingMoreNotifications || !_hasMoreNotifications) return;

    setState(() => _loadingMoreNotifications = true);

    try {
      final page = await _notificationService.fetchNotifications(
        limit: _notificationsPageSize,
        offset: _notifications.length,
      );
      if (!mounted) return;
      setState(() {
        _notifications = [..._notifications, ...page.notifications];
        _unreadNotifications = page.unread;
        _hasMoreNotifications = page.hasMore;
        _loadingMoreNotifications = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingMoreNotifications = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat notifikasi berikutnya: $error')),
      );
    }
  }

  Future<void> _markNotificationRead(NotificationModel notification) async {
    if (notification.isRead || _updatingNotificationId != null) return;

    setState(() => _updatingNotificationId = notification.id);

    try {
      final updated = await _notificationService.markRead(notification.id);
      if (!mounted) return;
      setState(() {
        _notifications = [
          for (final item in _notifications)
            if (item.id == updated.id) updated else item,
        ];
        _updatingNotificationId = null;
      });

      await _refreshUnreadCount();
    } catch (error) {
      if (!mounted) return;
      setState(() => _updatingNotificationId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menandai notifikasi: $error')),
      );
    }
  }

  Future<void> _markAllNotificationsRead() async {
    if (_markingAllRead || _unreadNotifications == 0) return;

    setState(() => _markingAllRead = true);

    try {
      await _notificationService.markAllRead();
      if (!mounted) return;
      setState(() {
        _notifications = _notifications
            .map((item) => item.isRead ? item : item.copyAsRead())
            .toList();
        _unreadNotifications = 0;
        _markingAllRead = false;
      });

      await _refreshUnreadCount();
    } catch (error) {
      if (!mounted) return;
      setState(() => _markingAllRead = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menandai semua notifikasi: $error')),
      );
    }
  }

  void _openNotification(NotificationModel notification) {
    if (!notification.isRead) {
      _markNotificationRead(notification);
    }

    final isRecruiter = _user?.role == 'recruiter';

    if (isRecruiter) {
      setState(() {
        _applicantJobFilter = notification.jobId;
        _applicantStatusFilter = null;
        _currentIndex = 2;
      });
      _loadRecruiterApplicants();
      return;
    }

    setState(() => _currentIndex = 2);
  }

  void _openNotificationsTab() {
    setState(() => _currentIndex = _notificationsTabIndex);
    _loadNotifications();
  }

  Widget _notificationsView() {
    if (!_notificationsOpened) return const SizedBox.shrink();

    return NotificationsPage(
      notifications: _notifications,
      unread: _unreadNotifications,
      loading: _loadingNotifications,
      error: _notificationsError,
      onRefresh: _loadNotifications,
      onMarkRead: _markNotificationRead,
      onMarkAllRead: _markAllNotificationsRead,
      onOpenNotification: _openNotification,
      markingAllRead: _markingAllRead,
      updatingId: _updatingNotificationId,
      hasMore: _hasMoreNotifications,
      loadingMore: _loadingMoreNotifications,
      onLoadMore: _loadMoreNotifications,
    );
  }

  Widget _notificationBell() {
    final unread = _unreadNotifications;

    return IconButton(
      key: const Key('home-notifications-button'),
      tooltip: unread > 0 ? '$unread notifikasi belum dibaca' : 'Notifikasi',
      onPressed: _openNotificationsTab,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_none),
          if (unread > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                key: const Key('home-notifications-badge'),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                constraints: const BoxConstraints(minWidth: 17),
                decoration: BoxDecoration(
                  color: JobTrackColors.danger,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: JobTrackColors.background,
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  unread > 99 ? '99+' : '$unread',
                  style: const TextStyle(
                    fontSize: 10,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _selectTab(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);

    if (index == _notificationsTabIndex) {
      _loadNotifications();
    }
  }

  void _openJob(JobModel job) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => JobDetailPage(job: job)));
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

  Widget _accountMenu() {
    return PopupMenuButton<String>(
      key: const Key('home-account-menu'),
      tooltip: 'Menu akun',
      onSelected: (value) {
        if (value == 'logout') _confirmLogout();
      },
      icon: const Icon(Icons.account_circle_outlined),
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _user?.username ?? 'Pengguna',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: JobTrackColors.navy,
                ),
              ),
              if (_user?.email.isNotEmpty ?? false)
                Text(
                  _user!.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: JobTrackColors.navyMuted,
                  ),
                ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, size: 20, color: JobTrackColors.navy),
              SizedBox(width: 10),
              Text('Keluar', style: TextStyle(color: JobTrackColors.navy)),
            ],
          ),
        ),
      ],
    );
  }

  static const _jobseekerTitles = <String>[
    'Dashboard',
    'Lowongan',
    'Lamaran',
    'Tersimpan',
    'Profil',
    'Notifikasi',
  ];

  static const _recruiterTitles = <String>[
    'Dashboard',
    'Lowongan',
    'Pelamar',
    'Profil',
    'Notifikasi',
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
    NavigationRailDestination(
      icon: Icon(Icons.notifications_none),
      selectedIcon: Icon(Icons.notifications),
      label: Text('Notifikasi'),
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
    NavigationRailDestination(
      icon: Icon(Icons.notifications_none),
      selectedIcon: Icon(Icons.notifications),
      label: Text('Notifikasi'),
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
    BottomNavigationBarItem(
      icon: Icon(Icons.notifications_none),
      activeIcon: Icon(Icons.notifications),
      label: 'Notifikasi',
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
    BottomNavigationBarItem(
      icon: Icon(Icons.notifications_none),
      activeIcon: Icon(Icons.notifications),
      label: 'Notifikasi',
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
              onRefresh: _refreshDashboard,
              currentUserId: _user?.id,
              onCreateJob: () => _openJobForm(),
              onEditJob: (job) => _openJobForm(job: job),
              onDeleteJob: _deleteJob,
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
            ProfilePage(user: _user, onLogout: _confirmLogout),
            _notificationsView(),
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
            _notificationsView(),
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
              if (currentIndex != _notificationsTabIndex) _notificationBell(),
              _accountMenu(),
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
                    leading: SizedBox(
                      height: 40,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isExtended ? 16 : 0,
                        ),
                        child: isExtended
                            ? const Align(
                                alignment: Alignment.centerLeft,
                                child: JobTrackBrand(logoSize: 32),
                              )
                            : const Center(
                                child: JobTrackBrand(
                                  logoSize: 36,
                                  showText: false,
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
