import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:Telehealth/core/routing/app_routes.dart';
import 'package:Telehealth/data/repositories/auth_repository.dart';
import 'package:Telehealth/features/hospital_admin/presentation/theme/admin_theme.dart';

/// Navigation guard tingkat UI untuk Web Dashboard Admin Rumah Sakit.
///
/// Router sudah menolak path `/hospital-admin/*` untuk role lain, tetapi guard
/// ini memastikan layar admin tidak pernah dirender (mis. setelah hot reload
/// atau sesi berubah) tanpa role `hospital_admin`.
class HospitalAdminGuard extends StatelessWidget {
  const HospitalAdminGuard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final user = AuthRepository.instance.currentUser;
    if (user != null && user.role.isHospitalAdmin) {
      return child;
    }
    return AdminAccessDeniedPage(isSignedIn: user != null);
  }
}

/// Halaman penolakan akses dengan jalur kembali ke dashboard sesuai role.
class AdminAccessDeniedPage extends StatelessWidget {
  const AdminAccessDeniedPage({super.key, required this.isSignedIn});

  final bool isSignedIn;

  Future<void> _signOut(BuildContext context) async {
    await AuthRepository.instance.signOut();
    if (context.mounted) context.go(AppRoutes.loginPath);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AdminTheme.light(),
      child: Scaffold(
        backgroundColor: AdminColors.background,
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 460),
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AdminColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AdminColors.border),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0F0F2E3A),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AdminColors.dangerSoft,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.gpp_maybe_outlined,
                    size: 30,
                    color: AdminColors.danger,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Akses Ditolak',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AdminColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Web Dashboard ini hanya dapat dibuka oleh akun dengan role '
                  'Admin Rumah Sakit (hospital_admin). Hubungi super admin bila '
                  'Anda seharusnya memiliki akses.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: AdminColors.textMuted,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      final user = AuthRepository.instance.currentUser;
                      context.go(
                        user == null
                            ? AppRoutes.loginPath
                            : AppRoutes.homePathFor(user.role),
                      );
                    },
                    child: Text(
                      isSignedIn ? 'Kembali ke halaman saya' : 'Masuk',
                    ),
                  ),
                ),
                if (isSignedIn) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => _signOut(context),
                    child: const Text('Keluar dari akun ini'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
