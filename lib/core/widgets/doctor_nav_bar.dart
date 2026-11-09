import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:Telehealth/core/routing/app_routes.dart';

/// Bottom Navigation Bar utama untuk navigasi dokter:
/// - Index 0: Dashboard (Jadwal Kerja & Permintaan Konsultasi Pasien)
/// - Index 1: Profil Dokter (Kredensial, Simulasi, & Pengaturan Praktik)
class DoctorNavBar extends StatelessWidget {
  const DoctorNavBar({
    super.key,
    required this.currentIndex,
    this.onTap,
  });

  /// Indeks tab yang aktif saat ini.
  final int currentIndex;

  /// Callback opsional saat tab dipilih (misalnya dari StatefulNavigationShell).
  final ValueChanged<int>? onTap;

  void _onDestinationSelected(BuildContext context, int index) {
    if (index == currentIndex) return;

    if (onTap != null) {
      onTap!(index);
      return;
    }

    switch (index) {
      case 0:
        context.goNamed(AppRoutes.doctorDashboardName);
        break;
      case 1:
        context.goNamed(AppRoutes.doctorProfileName);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) =>
            _onDestinationSelected(context, index),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: 0.12),
        elevation: 0,
        height: 64,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded, color: scheme.primary),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded, color: scheme.primary),
            label: 'Profil Dokter',
          ),
        ],
      ),
    );
  }
}
