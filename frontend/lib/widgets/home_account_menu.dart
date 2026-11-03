import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../theme/jobtrack_theme.dart';

class HomeAccountMenu extends StatelessWidget {
  const HomeAccountMenu({
    super.key,
    required this.user,
    required this.onLogout,
  });

  final UserModel? user;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      key: const Key('home-account-menu'),
      tooltip: 'Menu akun',
      onSelected: (value) {
        if (value == 'logout') onLogout();
      },
      icon: const Icon(Icons.account_circle_outlined),
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user?.username ?? 'Pengguna',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: JobTrackColors.navy,
                ),
              ),
              if (user?.email.isNotEmpty ?? false)
                Text(
                  user!.email,
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
}
