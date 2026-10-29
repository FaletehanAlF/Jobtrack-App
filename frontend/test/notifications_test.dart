// Tes UI notifikasi: daftar, badge belum dibaca, aksi tandai dibaca,
// loading/error/empty state, dan navigasi terkait.
//
// Otorisasi sebenarnya diuji di backend (src/tests/notification.test.ts).
// Di sini NotificationService palsu, jadi tes ini TIDAK membuktikan keamanan.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/models/application_model.dart';
import 'package:frontend/models/job_model.dart';
import 'package:frontend/models/notification_model.dart';
import 'package:frontend/models/recruiter_model.dart';
import 'package:frontend/models/user_model.dart';
import 'package:frontend/pages/home_page.dart';
import 'package:frontend/pages/notifications_page.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/application_service.dart';
import 'package:frontend/services/job_service.dart';
import 'package:frontend/services/notification_service.dart';
import 'package:frontend/services/recruiter_service.dart';

class _FakeJobService extends JobService {
  @override
  Future<List<JobModel>> fetchJobs() async => const [];
}

class _FakeApplicationService extends ApplicationService {
  @override
  Future<List<ApplicationModel>> fetchApplications() async => const [];
}

class _FakeRecruiterService extends RecruiterService {
  @override
  Future<RecruiterDashboardData> fetchDashboard() async =>
      const RecruiterDashboardData(
        stats: RecruiterDashboardStats.empty,
        jobs: [],
      );

  @override
  Future<RecruiterApplicantsPageData> fetchApplicants({
    int? jobId,
    String? status,
    int limit = 50,
    int offset = 0,
  }) async => RecruiterApplicantsPageData(
    applicants: const [],
    total: 0,
    limit: limit,
    offset: offset,
  );
}

/// NotificationService palsu yang mencatat pemanggilan.
class _FakeNotificationService extends NotificationService {
  _FakeNotificationService({
    this.notifications = const [],
    this.unread = 0,
    this.listError,
    this.markError,
  });

  List<NotificationModel> notifications;
  int unread;
  Object? listError;
  Object? markError;

  int listCalls = 0;
  int unreadCountCalls = 0;
  final List<int> markedIds = [];
  int markAllCalls = 0;

  @override
  Future<NotificationPageData> fetchNotifications({
    int limit = 50,
    int offset = 0,
  }) async {
    listCalls += 1;
    final error = listError;
    if (error != null) throw error;

    return NotificationPageData(
      notifications: notifications,
      total: notifications.length,
      unread: unread,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<int> fetchUnreadCount() async {
    unreadCountCalls += 1;
    return unread;
  }

  @override
  Future<NotificationModel> markRead(int notificationId) async {
    markedIds.add(notificationId);
    final error = markError;
    if (error != null) throw error;

    final original = notifications.firstWhere((item) => item.id == notificationId);
    final updated = original.copyAsRead();
    notifications = [
      for (final item in notifications)
        if (item.id == notificationId) updated else item,
    ];
    unread = notifications.where((item) => !item.isRead).length;
    return updated;
  }

  @override
  Future<void> markAllRead() async {
    markAllCalls += 1;

    notifications = notifications.map((item) => item.copyAsRead()).toList();
    unread = 0;
  }
}

UserModel _user({String role = 'jobseeker'}) => UserModel(
  id: 7,
  username: 'tester',
  email: 'tester@example.com',
  role: role,
  createdAt: DateTime(2020),
);

NotificationModel _notification({
  required int id,
  String type = 'application_rejected',
  String message = 'Lamaranmu ditolak.',
  bool isRead = false,
  int? jobId = 3,
  int? applicationId = 9,
}) {
  return NotificationModel(
    id: id,
    type: type,
    message: message,
    jobId: jobId,
    applicationId: applicationId,
    createdAt: DateTime(2026, 10, 27, 14, 5),
    readAt: isRead ? DateTime(2026, 10, 27, 15) : null,
    isRead: isRead,
  );
}

void _setSurfaceSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pumpHome(
  WidgetTester tester,
  _FakeNotificationService service, {
  String role = 'jobseeker',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: HomePage(
        user: _user(role: role),
        jobService: _FakeJobService(),
        applicationService: _FakeApplicationService(),
        recruiterService: _FakeRecruiterService(),
        notificationService: service,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Badge menampilkan jumlah belum dibaca dari server', (
    WidgetTester tester,
  ) async {
    _setSurfaceSize(tester, const Size(1280, 1000));

    final service = _FakeNotificationService(
      notifications: [
        _notification(id: 1),
        _notification(id: 2, isRead: true),
        _notification(id: 3),
      ],
      unread: 2,
    );

    await _pumpHome(tester, service);

    expect(find.byKey(const Key('home-notifications-badge')), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    // Badge memakai endpoint ringan; daftar lengkap belum dimuat sebelum
    // tab Notifikasi dibuka.
    expect(service.unreadCountCalls, 1);
    expect(service.listCalls, 0);
  });

  testWidgets('Badge tidak muncul saat semua notifikasi sudah dibaca', (
    WidgetTester tester,
  ) async {
    _setSurfaceSize(tester, const Size(1280, 1000));

    final service = _FakeNotificationService(
      notifications: [_notification(id: 1, isRead: true)],
      unread: 0,
    );

    await _pumpHome(tester, service);

    expect(find.byKey(const Key('home-notifications-badge')), findsNothing);
  });

  testWidgets('Lonceng membuka tab Notifikasi berisi daftar', (
    WidgetTester tester,
  ) async {
    _setSurfaceSize(tester, const Size(1280, 1000));

    final service = _FakeNotificationService(
      notifications: [
        _notification(id: 1, message: 'Lamaranmu untuk "Backend" ditolak.'),
      ],
      unread: 1,
    );

    await _pumpHome(tester, service);

    await tester.tap(find.byKey(const Key('home-notifications-button')));
    await tester.pumpAndSettle();

    expect(find.byType(NotificationsPage), findsOneWidget);
    expect(find.text('Lamaranmu untuk "Backend" ditolak.'), findsOneWidget);
    // Waktu ditampilkan bersama notifikasi.
    expect(find.textContaining('27/10/2026'), findsOneWidget);
  });

  testWidgets('Menandai satu notifikasi dibaca memperbarui UI dan badge', (
    WidgetTester tester,
  ) async {
    _setSurfaceSize(tester, const Size(1280, 1000));

    final service = _FakeNotificationService(
      notifications: [_notification(id: 1), _notification(id: 2)],
      unread: 2,
    );

    await _pumpHome(tester, service);
    await tester.tap(find.byKey(const Key('home-notifications-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('notification-1-read')));
    await tester.pumpAndSettle();

    expect(service.markedIds, [1]);
    // Satu notifikasi tersisa belum dibaca: tombol bacanya masih ada.
    expect(find.byKey(const Key('notification-1-read')), findsNothing);
    expect(find.byKey(const Key('notification-2-read')), findsOneWidget);

    // Pindah ke tab lain lewat BottomNavigationBar. Di lebar 1280 navigasi
    // memakai NavigationRail yang labelnya tersembunyi (labelType.none),
    // jadi teks "Dashboard" tidak bisa dijadikan target ketukan.
    await tester.tap(find.byIcon(Icons.home_outlined).last);
    await tester.pumpAndSettle();

    // Badge di AppBar menunjukkan sisa 1 yang belum dibaca.
    expect(find.byKey(const Key('home-notifications-badge')), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('Tandai semua dibaca mengosongkan badge', (
    WidgetTester tester,
  ) async {
    _setSurfaceSize(tester, const Size(1280, 1000));

    final service = _FakeNotificationService(
      notifications: [_notification(id: 1), _notification(id: 2)],
      unread: 2,
    );

    await _pumpHome(tester, service);
    await tester.tap(find.byKey(const Key('home-notifications-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('notifications-mark-all')));
    await tester.pumpAndSettle();

    expect(service.markAllCalls, 1);
    expect(find.text('Semua notifikasi sudah dibaca'), findsOneWidget);
    expect(find.byKey(const Key('notification-1-read')), findsNothing);
  });

  testWidgets('Empty state tampil saat belum ada notifikasi', (
    WidgetTester tester,
  ) async {
    _setSurfaceSize(tester, const Size(1280, 1000));

    final service = _FakeNotificationService();

    await _pumpHome(tester, service);
    await tester.tap(find.byKey(const Key('home-notifications-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('notifications-empty')), findsOneWidget);
    expect(find.text('Belum ada notifikasi'), findsOneWidget);
  });

  testWidgets('Error menampilkan pesan dan tombol coba lagi', (
    WidgetTester tester,
  ) async {
    _setSurfaceSize(tester, const Size(1280, 1000));

    final service = _FakeNotificationService(
      listError: ApiException(0, 'Tidak dapat terhubung ke server.'),
    );

    await _pumpHome(tester, service);
    await tester.tap(find.byKey(const Key('home-notifications-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('notifications-error')), findsOneWidget);
    expect(find.textContaining('Tidak dapat terhubung'), findsOneWidget);

    final callsBefore = service.listCalls;
    await tester.tap(find.text('Coba Lagi').first);
    await tester.pumpAndSettle();
    expect(service.listCalls, greaterThan(callsBefore));
  });

  testWidgets('Gagal menandai dibaca menampilkan pesan, status tidak berubah', (
    WidgetTester tester,
  ) async {
    _setSurfaceSize(tester, const Size(1280, 1000));

    final service = _FakeNotificationService(
      notifications: [_notification(id: 1)],
      unread: 1,
      markError: ApiException(404, 'Notifikasi tidak ditemukan'),
    );

    await _pumpHome(tester, service);
    await tester.tap(find.byKey(const Key('home-notifications-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('notification-1-read')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Notifikasi tidak ditemukan'), findsOneWidget);
    // Server menolak, jadi UI tidak boleh mengaku sudah dibaca.
    expect(find.byKey(const Key('notification-1-read')), findsOneWidget);
  });

  testWidgets('Notifikasi recruiter membuka tab Pelamar', (
    WidgetTester tester,
  ) async {
    _setSurfaceSize(tester, const Size(1280, 1000));

    final service = _FakeNotificationService(
      notifications: [
        _notification(
          id: 1,
          type: 'application_received',
          message: 'budi melamar lowongan "Backend".',
          jobId: 3,
        ),
      ],
      unread: 1,
    );

    await _pumpHome(tester, service, role: 'recruiter');

    await tester.tap(find.byKey(const Key('home-notifications-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('notification-1')));
    await tester.pumpAndSettle();

    // Diarahkan ke daftar pelamar, bukan tab lain.
    expect(find.text('Pelamar'), findsWidgets);
    expect(service.markedIds, contains(1));
  });
}
