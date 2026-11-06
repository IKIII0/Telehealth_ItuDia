import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:Telehealth/core/widgets/app_logo.dart';
import 'package:Telehealth/data/models/hospital_admin.dart';
import 'package:Telehealth/data/repositories/auth_repository.dart';
import 'package:Telehealth/data/repositories/hospital_admin_repository.dart';
import 'package:Telehealth/features/hospital_admin/presentation/theme/admin_theme.dart';
import 'package:Telehealth/features/hospital_admin/presentation/widgets/admin_widgets.dart';

/// Layout Web Dashboard Admin Rumah Sakit.
///
/// Sidebar tetap tampil di layar lebar; pada layar sempit sidebar berubah
/// menjadi drawer. Navigasi memakai [StatefulNavigationShell] agar state
/// setiap halaman tidak hilang saat berpindah menu.
class HospitalAdminShellScaffold extends StatefulWidget {
  const HospitalAdminShellScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<HospitalAdminShellScaffold> createState() =>
      _HospitalAdminShellScaffoldState();
}

class _HospitalAdminShellScaffoldState
    extends State<HospitalAdminShellScaffold> {
  static const List<String> _sectionTitles = [
    'Ringkasan Dashboard',
    'Verifikasi Obat',
    'Pemantauan Pasien',
  ];

  HospitalAdminProfile? _profile;
  int _pendingCount = 0;
  bool _loadingChrome = true;

  @override
  void initState() {
    super.initState();
    _loadChrome();
  }

  Future<void> _loadChrome() async {
    final repository = HospitalAdminRepository.instance;
    try {
      final results = await Future.wait<Object>([
        repository.profile(),
        repository.fetchSummary(),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0] as HospitalAdminProfile;
        _pendingCount =
            (results[1] as HospitalAdminSummary).pendingPrescriptions;
        _loadingChrome = false;
      });
    } catch (_) {
      if (!mounted) return;
      final user = AuthRepository.instance.currentUser;
      setState(() {
        _profile = HospitalAdminProfile(
          adminName: user?.name ?? 'Admin Rumah Sakit',
          email: user?.email ?? '',
        );
        _loadingChrome = false;
      });
    }
  }

  Future<void> _signOut() async {
    await AuthRepository.instance.signOut();
  }

  void _goToBranch(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
    // Segarkan badge resep tertunda di sidebar.
    unawaited(_loadChrome());
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AdminTheme.light(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1080;

          return Scaffold(
            backgroundColor: AdminColors.background,
            drawer: isWide
                ? null
                : Drawer(
                    width: 286,
                    child: Builder(
                      builder: (drawerContext) =>
                          _buildSidebar(drawerContext, inDrawer: true),
                    ),
                  ),
            appBar: isWide
                ? null
                : AppBar(
                    titleSpacing: 16,
                    title: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AdminColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const AppLogo(
                            size: 20,
                            color: AdminColors.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text('Admin Rumah Sakit'),
                      ],
                    ),
                    actions: [
                      if (HospitalAdminRepository.instance.isDemoMode) ...[
                        const AdminDemoBadge(),
                        const SizedBox(width: 8),
                      ],
                      IconButton(
                        tooltip: 'Keluar',
                        icon: const Icon(Icons.logout_rounded),
                        onPressed: _signOut,
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
            body: SafeArea(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isWide)
                    SizedBox(
                      width: 272,
                      child: _buildSidebar(context, inDrawer: false),
                    ),
                  Expanded(
                    child: Column(
                      children: [
                        if (isWide) _buildTopBar(context),
                        Expanded(child: widget.navigationShell),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final index = widget.navigationShell.currentIndex.clamp(
      0,
      _sectionTitles.length - 1,
    );
    final now = DateTime.now();
    final dateLabel =
        '${adminFormatDate(now)} • '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      decoration: const BoxDecoration(
        color: AdminColors.surface,
        border: Border(bottom: BorderSide(color: AdminColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ADMIN RUMAH SAKIT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.9,
                    color: AdminColors.textMuted,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _sectionTitles[index],
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AdminColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (HospitalAdminRepository.instance.isDemoMode) ...[
            const AdminDemoBadge(),
            const SizedBox(width: 14),
          ],
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 15,
                color: AdminColors.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                dateLabel,
                style: const TextStyle(
                  fontSize: 12,
                  color: AdminColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(width: 18),
          _buildAccountChip(context),
        ],
      ),
    );
  }

  Widget _buildAccountChip(BuildContext context) {
    final user = AuthRepository.instance.currentUser;
    final name = _profile?.adminName.isNotEmpty == true
        ? _profile!.adminName
        : user?.name ?? 'Admin Rumah Sakit';
    final email = _profile?.email.isNotEmpty == true
        ? _profile!.email
        : user?.email ?? '';

    return Row(
      children: [
        AdminInitialsAvatar(name: name, size: 34),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AdminColors.textPrimary,
                ),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Text(
                email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AdminColors.textMuted,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Keluar',
          onPressed: _signOut,
          icon: const Icon(
            Icons.logout_rounded,
            size: 18,
            color: AdminColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildSidebar(BuildContext context, {required bool inDrawer}) {
    final currentIndex = widget.navigationShell.currentIndex;
    final profile = _profile;
    final user = AuthRepository.instance.currentUser;
    final adminName = profile?.adminName.isNotEmpty == true
        ? profile!.adminName
        : user?.name ?? 'Admin Rumah Sakit';
    final email = profile?.email.isNotEmpty == true
        ? profile!.email
        : user?.email ?? '';

    void navigate(int index) {
      if (inDrawer) Navigator.of(context).pop();
      _goToBranch(index);
    }

    return Container(
      color: AdminColors.sidebar,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const AppLogo(size: 22, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Telehealth',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Admin Rumah Sakit',
                          style: TextStyle(
                            fontSize: 10.5,
                            letterSpacing: 0.3,
                            color: AdminColors.sidebarMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.local_hospital_rounded,
                      size: 20,
                      color: AdminColors.sidebarText,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _loadingChrome
                                ? 'Memuat rumah sakit…'
                                : profile?.hospitalName ?? 'Rumah Sakit',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                              color: Colors.white,
                            ),
                          ),
                          if ((profile?.hospitalCity ?? '').isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              profile!.hospitalCity,
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: AdminColors.sidebarMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 26),
              child: Text(
                'MENU UTAMA',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: AdminColors.sidebarMuted,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _SidebarItem(
              icon: Icons.dashboard_outlined,
              selectedIcon: Icons.dashboard_rounded,
              label: 'Ringkasan Dashboard',
              selected: currentIndex == 0,
              onTap: () => navigate(0),
            ),
            _SidebarItem(
              icon: Icons.medication_outlined,
              selectedIcon: Icons.medication_rounded,
              label: 'Verifikasi Obat',
              selected: currentIndex == 1,
              badge: _pendingCount,
              onTap: () => navigate(1),
            ),
            _SidebarItem(
              icon: Icons.monitor_heart_outlined,
              selectedIcon: Icons.monitor_heart_rounded,
              label: 'Pemantauan Pasien',
              selected: currentIndex == 2,
              onTap: () => navigate(2),
            ),
            const Spacer(),
            Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 16),
              child: Row(
                children: [
                  AdminInitialsAvatar(
                    name: adminName,
                    size: 34,
                    color: AdminColors.sidebarText,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          adminName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AdminColors.sidebarMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Keluar',
                    onPressed: _signOut,
                    icon: const Icon(
                      Icons.logout_rounded,
                      size: 18,
                      color: AdminColors.sidebarMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : AdminColors.sidebarText;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: selected ? AdminColors.sidebarActive : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  selected ? selectedIcon : icon,
                  size: 19,
                  color: selected ? Colors.white : AdminColors.sidebarMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: foreground,
                    ),
                  ),
                ),
                if (badge != null && badge! > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AdminColors.warningSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$badge',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AdminColors.warning,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
