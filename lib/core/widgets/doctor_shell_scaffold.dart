import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:Telehealth/core/widgets/doctor_nav_bar.dart';

/// Shell Scaffold untuk navigasi dokter dengan Bottom Navigation Bar persisten.
///
/// Shell ini membungkus tab dokter (Dashboard, Konsultasi, Profil Dokter) agar
/// [DoctorNavBar] tetap statis saat berpindah antar branch.
class DoctorShellScaffold extends StatelessWidget {
  const DoctorShellScaffold({super.key, required this.navigationShell});

  /// Shell navigasi dari GoRouter yang mengelola branch aktif.
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      resizeToAvoidBottomInset: false,
      bottomNavigationBar: DoctorNavBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
      ),
    );
  }
}
