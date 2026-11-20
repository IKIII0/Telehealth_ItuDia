import 'package:flutter/material.dart';

import 'package:Telehealth/data/repositories/notification_repository.dart';

/// Ikon lonceng notifikasi dengan penanda merah.
///
/// Penanda hanya muncul bila masih ada notifikasi yang belum dibaca, dan
/// otomatis hilang setelah notifikasi dibuka/ditandai dibaca.
class NotificationBell extends StatelessWidget {
  const NotificationBell({
    super.key,
    required this.onTap,
    this.color = Colors.white,
    this.size = 28,
  });

  final VoidCallback onTap;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: NotificationRepository.instance,
      builder: (context, _) {
        final hasUnread = NotificationRepository.instance.unreadCount > 0;
        return Stack(
          children: [
            IconButton(
              tooltip: 'Notifikasi',
              icon: Icon(
                Icons.notifications_outlined,
                size: size,
                color: color,
              ),
              onPressed: onTap,
            ),
            if (hasUnread)
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE53935),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
