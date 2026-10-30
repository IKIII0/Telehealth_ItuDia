import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:Telehealth/core/widgets/patient_nav_bar.dart';

/// Shell Scaffold untuk navigasi pasien dengan Bottom Navigation Bar yang di-anchor.
///
/// Shell ini membungkus tab utama pasien (Dashboard, Cek Gejala, Chat, Profil)
/// agar [PatientNavBar] tetap statis (tidak bergerak atau beranimasi) saat berpindah
/// antar halaman tab.
class PatientShellScaffold extends StatelessWidget {
  const PatientShellScaffold({
    super.key,
    required this.navigationShell,
  });

  /// Shell navigasi dari GoRouter yang mengelola branch aktif.
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      resizeToAvoidBottomInset: false,
      bottomNavigationBar: PatientNavBar(
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
