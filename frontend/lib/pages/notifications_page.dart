import 'package:flutter/material.dart';

import '../controllers/notification_controller.dart';
import '../models/notification_model.dart';
import '../theme/jobtrack_theme.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key, required this.controller});

  final NotificationController controller;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    // Selalu resync dari REST saat halaman dibuka.
    widget.controller.loadNotifications();
  }

  Future<void> _refresh() => widget.controller.loadNotifications();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JobTrackColors.background,
      appBar: AppBar(
        backgroundColor: JobTrackColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: JobTrackColors.navy,
        titleSpacing: 16,
        shape: const Border(
          bottom: BorderSide(color: JobTrackColors.border),
        ),
        title: const Text(
          'Notifikasi',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) {
              final hasUnread = widget.controller.unreadCount > 0;

              return TextButton(
                key: const Key('mark-all-read-button'),
                onPressed:
                    hasUnread ? () => widget.controller.markAllRead() : null,
                child: const Text('Tandai semua dibaca'),
              );
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final controller = widget.controller;

          if (controller.loading && controller.notifications.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (controller.error != null &&
              controller.notifications.isEmpty) {
            return _ErrorState(
              message: controller.error!,
              onRetry: controller.loadNotifications,
            );
          }

          if (controller.notifications.isEmpty) {
            return const _EmptyState();
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding:
                  const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: controller.notifications.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final notification = controller.notifications[index];

                return _NotificationTile(
                  notification: notification,
                  onTap: () => controller.markRead(notification),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  final NotificationModel notification;
  final VoidCallback onTap;

  IconData get _icon {
    switch (notification.type) {
      case 'application_received':
        return Icons.inbox_outlined;
      case 'application_rejected':
        return Icons.cancel_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;
    final accent = notification.type == 'application_rejected'
        ? JobTrackColors.danger
        : JobTrackColors.blue;

    return Material(
      color: unread ? JobTrackColors.blueSoft : JobTrackColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: Key('notification-item-${notification.id ?? notification.createdAt.microsecondsSinceEpoch}'),
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: unread
                  ? JobTrackColors.blue.withValues(alpha: 0.35)
                  : JobTrackColors.border,
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_icon, size: 20, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.message,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.45,
                        color: JobTrackColors.navy,
                        fontWeight:
                            unread ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 13,
                          color: JobTrackColors.navyMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          notification.relativeTime,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: JobTrackColors.navyMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (unread) ...[
                const SizedBox(width: 8),
                Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: JobTrackColors.blue,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_outlined,
              size: 48,
              color: JobTrackColors.navyMuted,
            ),
            SizedBox(height: 16),
            Text(
              'Belum ada notifikasi',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: JobTrackColors.navy,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Notifikasi tentang lamaran dan pelamar akan '
              'muncul di sini secara real-time.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.5,
                color: JobTrackColors.navyMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: JobTrackColors.navyMuted,
            ),
            const SizedBox(height: 16),
            const Text(
              'Gagal memuat notifikasi',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: JobTrackColors.navy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: JobTrackColors.navyMuted,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: JobTrackColors.blue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Coba Lagi'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
