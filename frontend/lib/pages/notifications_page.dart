import 'package:flutter/material.dart';

import '../models/notification_model.dart';
import '../theme/jobtrack_theme.dart';

/// Halaman daftar notifikasi untuk jobseeker dan recruiter.
///
/// Data berasal dari `GET /api/notifications`, yang sudah dibatasi
/// `recipient_id` dari token di backend. Halaman ini tidak memfilter
/// berdasarkan identitas pengguna — backend yang menentukan.
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({
    super.key,
    required this.notifications,
    required this.unread,
    required this.loading,
    required this.error,
    required this.onRefresh,
    required this.onMarkRead,
    required this.onMarkAllRead,
    required this.onOpenNotification,
    this.markingAllRead = false,
    this.updatingId,
    this.hasMore = false,
    this.loadingMore = false,
    this.onLoadMore,
  });

  final List<NotificationModel> notifications;

  /// Jumlah belum dibaca dari backend (bukan dihitung dari halaman ini).
  final int unread;

  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;
  final Future<void> Function(NotificationModel) onMarkRead;
  final Future<void> Function() onMarkAllRead;

  /// Membuka entitas terkait (lowongan/pelamar/lamaran) bila tersedia.
  final ValueChanged<NotificationModel> onOpenNotification;

  final bool markingAllRead;
  final int? updatingId;
  final bool hasMore;
  final bool loadingMore;
  final Future<void> Function()? onLoadMore;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth >= 900 ? 32.0 : 16.0;

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
                  constraints: const BoxConstraints(maxWidth: 820),
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
                                const Text(
                                  'Notifikasi',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: JobTrackColors.navy,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  unread > 0
                                      ? '$unread notifikasi belum dibaca'
                                      : 'Semua notifikasi sudah dibaca',
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    color: JobTrackColors.navyMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Muat ulang notifikasi',
                            onPressed: loading ? null : onRefresh,
                            icon: const Icon(Icons.refresh),
                            color: JobTrackColors.navyMuted,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Tombol tandai semua hanya aktif bila benar-benar ada
                      // yang belum dibaca, agar tidak ada aksi kosong.
                      OutlinedButton.icon(
                        key: const Key('notifications-mark-all'),
                        onPressed: unread == 0 || markingAllRead
                            ? null
                            : onMarkAllRead,
                        icon: markingAllRead
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.done_all, size: 18),
                        label: Text(
                          markingAllRead
                              ? 'Menandai...'
                              : 'Tandai semua sudah dibaca',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: JobTrackColors.blue,
                          side: const BorderSide(
                            color: JobTrackColors.border,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (loading)
                        const _NotificationsLoading()
                      else if (error != null)
                        _NotificationsError(message: error!, onRetry: onRefresh)
                      else if (notifications.isEmpty)
                        const _NotificationsEmpty()
                      else
                        Column(
                          children: [
                            for (
                              var index = 0;
                              index < notifications.length;
                              index++
                            ) ...[
                              if (index > 0) const SizedBox(height: 10),
                              _NotificationCard(
                                notification: notifications[index],
                                onOpen: () =>
                                    onOpenNotification(notifications[index]),
                                onMarkRead: () =>
                                    onMarkRead(notifications[index]),
                                updating: updatingId == notifications[index].id,
                              ),
                            ],
                            if (hasMore && onLoadMore != null) ...[
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                key: const Key('notifications-load-more'),
                                onPressed: loadingMore ? null : onLoadMore,
                                icon: loadingMore
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.expand_more, size: 18),
                                label: Text(
                                  loadingMore ? 'Memuat...' : 'Muat lebih banyak',
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: JobTrackColors.blue,
                                  side: const BorderSide(
                                    color: JobTrackColors.border,
                                  ),
                                ),
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

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.onOpen,
    required this.onMarkRead,
    required this.updating,
  });

  final NotificationModel notification;
  final VoidCallback onOpen;
  final VoidCallback onMarkRead;
  final bool updating;

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;
    final isRejected = notification.isApplicationRejected;

    return Material(
      color: unread ? JobTrackColors.blueSoft : JobTrackColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: Key('notification-${notification.id}'),
        borderRadius: BorderRadius.circular(14),
        onTap: updating ? null : onOpen,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: unread ? JobTrackColors.blue : JobTrackColors.border,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isRejected
                      ? JobTrackColors.dangerSoft
                      : JobTrackColors.blueSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(
                  isRejected
                      ? Icons.cancel_outlined
                      : Icons.work_outline,
                  size: 20,
                  color: isRejected
                      ? JobTrackColors.danger
                      : JobTrackColors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.message,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        fontWeight: unread ? FontWeight.w600 : FontWeight.w500,
                        color: JobTrackColors.navy,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          _formatDateTime(notification.createdAt),
                          style: const TextStyle(
                            fontSize: 12,
                            color: JobTrackColors.navyMuted,
                          ),
                        ),
                        if (unread) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: JobTrackColors.blue,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (unread)
                IconButton(
                  key: Key('notification-${notification.id}-read'),
                  tooltip: 'Tandai sudah dibaca',
                  onPressed: updating ? null : onMarkRead,
                  icon: updating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline, size: 20),
                  color: JobTrackColors.blue,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tanggal dan jam singkat, mis. "27/10/2026 14:05".
  static String _formatDateTime(DateTime? date) {
    if (date == null) return 'Waktu tidak tersedia';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/${date.year} $hour:$minute';
  }
}

class _NotificationsLoading extends StatelessWidget {
  const _NotificationsLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36),
      decoration: BoxDecoration(
        color: JobTrackColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: JobTrackColors.border),
      ),
      child: const Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text(
            'Memuat notifikasi...',
            style: TextStyle(fontSize: 13, color: JobTrackColors.navyMuted),
          ),
        ],
      ),
    );
  }
}

class _NotificationsError extends StatelessWidget {
  const _NotificationsError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('notifications-error'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: JobTrackColors.dangerSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: JobTrackColors.dangerBorder),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 36,
            color: JobTrackColors.danger,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: JobTrackColors.danger,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: JobTrackColors.danger,
              side: const BorderSide(color: JobTrackColors.dangerBorder),
            ),
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }
}

class _NotificationsEmpty extends StatelessWidget {
  const _NotificationsEmpty();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('notifications-empty'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: JobTrackColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: JobTrackColors.border),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.notifications_none,
            size: 46,
            color: JobTrackColors.navyMuted,
          ),
          SizedBox(height: 12),
          Text(
            'Belum ada notifikasi',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: JobTrackColors.navy,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Pemberitahuan tentang lamaran dan lowongan akan muncul di sini.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: JobTrackColors.navyMuted,
            ),
          ),
        ],
      ),
    );
  }
}
