import 'package:flutter/material.dart';

import 'package:Telehealth/core/widgets/app_dialogs.dart';
import 'package:Telehealth/core/widgets/async_state.dart';
import 'package:Telehealth/core/widgets/role_badge.dart';
import 'package:Telehealth/data/models/app_notification.dart';
import 'package:Telehealth/data/repositories/notification_repository.dart';

/// Halaman daftar notifikasi pasien.
class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  bool _loading = true;
  String? _error;
  List<AppNotification> _notifications = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final notifications = await NotificationRepository.instance.fetchAll();
      if (!mounted) return;
      setState(() {
        _notifications = notifications;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _refresh() async {
    try {
      final notifications = await NotificationRepository.instance.fetchAll();
      if (!mounted) return;
      setState(() => _notifications = notifications);
    } catch (_) {
      if (!mounted) return;
      showAppSnack(context, 'Gagal memuat notifikasi', success: false);
    }
  }

  Future<void> _markRead(AppNotification notification) async {
    if (notification.isRead) return;
    await NotificationRepository.instance.markRead(notification.id);
    await _refresh();
  }

  Future<void> _markAllRead() async {
    await NotificationRepository.instance.markAllRead();
    await _refresh();
    if (!mounted) return;
    showAppSnack(context, 'Semua notifikasi ditandai sudah dibaca');
  }

  bool get _hasUnread => _notifications.any((n) => !n.isRead);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Notifikasi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          const RoleBadge.patient(),
          if (_hasUnread)
            TextButton(
              onPressed: _markAllRead,
              child: const Text(
                'Tandai dibaca',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
        ],
      ),
      body: _buildBody(scheme),
    );
  }

  Widget _buildBody(ColorScheme scheme) {
    if (_loading) {
      return const LoadingView(message: 'Memuat notifikasi...');
    }
    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _load);
    }
    if (_notifications.isEmpty) {
      return const EmptyView(
        icon: Icons.notifications_none_rounded,
        title: 'Belum ada notifikasi',
        message: 'Pengingat obat dan pesan dokter akan muncul di sini.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _notifications.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) =>
            _buildTile(_notifications[index], scheme),
      ),
    );
  }

  Widget _buildTile(AppNotification notification, ColorScheme scheme) {
    final meta = _metaFor(notification.category, scheme);

    return Material(
      color: notification.isRead ? Colors.white : const Color(0xFFEFF6FF),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _markRead(notification),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: meta.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(meta.icon, size: 18, color: meta.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: notification.isRead
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 7,
                            height: 7,
                            margin: const EdgeInsets.only(left: 6),
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      notification.message,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.time,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _CategoryMeta _metaFor(NotificationCategory category, ColorScheme scheme) {
    switch (category) {
      case NotificationCategory.medication:
        return _CategoryMeta(Icons.medication_rounded, scheme.primary);
      case NotificationCategory.consultation:
        return _CategoryMeta(Icons.medical_services_rounded, scheme.primary);
      case NotificationCategory.chat:
        return _CategoryMeta(Icons.chat_bubble_rounded, scheme.primary);
      case NotificationCategory.system:
        return _CategoryMeta(Icons.info_outline_rounded, Colors.grey.shade600);
    }
  }
}

class _CategoryMeta {
  const _CategoryMeta(this.icon, this.color);

  final IconData icon;
  final Color color;
}
