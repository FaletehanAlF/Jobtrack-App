import 'package:flutter/material.dart';

import '../theme/jobtrack_theme.dart';

/// Tombol lonceng di AppBar dengan badge jumlah notifikasi belum dibaca.
class NotificationBell extends StatelessWidget {
  const NotificationBell({
    super.key,
    required this.unreadCount,
    required this.onTap,
  });

  final int unreadCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final showBadge = unreadCount > 0;
    final label = unreadCount > 99 ? '99+' : '$unreadCount';

    return IconButton(
      key: const Key('notification-bell'),
      tooltip: showBadge ? 'Notifikasi ($unreadCount belum dibaca)' : 'Notifikasi',
      onPressed: onTap,
      icon: Badge(
        isLabelVisible: showBadge,
        label: Text(label),
        backgroundColor: JobTrackColors.danger,
        textColor: Colors.white,
        child: Icon(
          showBadge ? Icons.notifications : Icons.notifications_outlined,
        ),
      ),
    );
  }
}
