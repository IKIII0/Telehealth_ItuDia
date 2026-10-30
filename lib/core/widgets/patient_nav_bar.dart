import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:Telehealth/core/routing/app_routes.dart';

/// Bottom Navigation Bar utama untuk navigasi pasien:
/// - Index 0: Home (Dashboard)
/// - Index 1: Cek Gejala
/// - Index 2: Chat Dokter
/// - Index 3: Profil
class PatientNavBar extends StatelessWidget {
  const PatientNavBar({
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
        context.goNamed(AppRoutes.patientDashboardName);
        break;
      case 1:
        context.goNamed(AppRoutes.patientSymptomCheckerName);
        break;
      case 2:
        context.goNamed(AppRoutes.patientChatName);
        break;
      case 3:
        context.goNamed(AppRoutes.patientProfileName);
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
            icon: const Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: scheme.primary),
            label: 'Home',
          ),
          NavigationDestination(
            icon: const Icon(Icons.medical_services_outlined),
            selectedIcon: Icon(
              Icons.medical_services_rounded,
              color: scheme.primary,
            ),
            label: 'Cek Gejala',
          ),
          NavigationDestination(
            icon: const Icon(Icons.chat_outlined),
            selectedIcon: Icon(Icons.chat_rounded, color: scheme.primary),
            label: 'Chat Dokter',
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded, color: scheme.primary),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
