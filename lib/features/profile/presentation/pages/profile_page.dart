import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:Telehealth/core/routing/app_routes.dart';
import 'package:Telehealth/core/widgets/app_dialogs.dart';
import 'package:Telehealth/core/widgets/patient_nav_bar.dart';
import 'package:Telehealth/data/repositories/auth_repository.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, this.showNavBar = false});

  final bool showNavBar;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // ── Info pengguna (dapat diubah lewat dialog edit) ──────────────────────────
  String _name = 'ItuDia';
  String _email = 'ItuDia@gmail.com';
  String _phone = '+62 812 3456 7890';
  static const String _birthDate = '15 Januari 1995';
  static const String _gender = '-';
  static const String _address = 'Jl. Sudirman No. 123, Jakarta Pusat';
  static const String _bloodType = '-';

  // ── Preferensi ──────────────────────────────────────────────────────────────
  bool _notifEnabled = true;
  bool _chatReminder = true;
  bool _promoEmail = false;

  @override
  void initState() {
    super.initState();
    final user = AuthRepository.instance.currentUser;
    if (user != null) {
      _name = user.name;
      _email = user.email;
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      bottomNavigationBar:
          widget.showNavBar ? const PatientNavBar(currentIndex: 3) : null,
      appBar: AppBar(
        title: const Text('Profil'),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit profil',
            onPressed: _openEditProfile,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(scheme),
            const SizedBox(height: 20),
            _buildInfoCard(scheme),
            const SizedBox(height: 20),
            _buildPreferenceCard(scheme),
            const SizedBox(height: 20),
            _buildMenuCard(scheme),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader(ColorScheme scheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 36),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            scheme.primary,
            Color.lerp(scheme.primary, Colors.black, 0.25)!,
          ],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 52,
              backgroundColor: scheme.primaryContainer,
              child: Icon(Icons.person, size: 58, color: scheme.primary),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _email,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Colors.white70),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              AuthRepository.instance.currentUser?.role.label ?? 'Pasien',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared card wrapper ─────────────────────────────────────────────────────
  Widget _sectionCard(
    ColorScheme scheme, {
    String? title,
    IconData? icon,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(20),
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Row(
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 22, color: scheme.primary),
                        const SizedBox(width: 10),
                      ],
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Info card ───────────────────────────────────────────────────────────────
  Widget _buildInfoCard(ColorScheme scheme) {
    final rows = [
      (Icons.phone_outlined, 'Telepon', _phone),
      (Icons.cake_outlined, 'Tanggal Lahir', _birthDate),
      (Icons.wc_outlined, 'Jenis Kelamin', _gender),
      (Icons.location_on_outlined, 'Alamat', _address),
      (Icons.water_drop_outlined, 'Golongan Darah', _bloodType),
    ];

    return _sectionCard(
      scheme,
      title: 'Informasi Pribadi',
      icon: Icons.badge_outlined,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 28),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(rows[i].$1, size: 20, color: scheme.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rows[i].$2,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        rows[i].$3,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Preference card ─────────────────────────────────────────────────────────
  Widget _buildPreferenceCard(ColorScheme scheme) {
    const tilePadding = EdgeInsets.symmetric(horizontal: 20, vertical: 6);
    return _sectionCard(
      scheme,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(Icons.tune_rounded, size: 22, color: scheme.primary),
                const SizedBox(width: 10),
                const Text(
                  'Preferensi',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: tilePadding,
            secondary: Icon(
              Icons.notifications_outlined,
              color: scheme.primary,
            ),
            title: const Text('Notifikasi'),
            subtitle: const Text('Terima pengingat jadwal & obat'),
            value: _notifEnabled,
            onChanged: (v) => _updatePreference(
              () => _notifEnabled = v,
              'Preferensi notifikasi disimpan',
            ),
          ),
          const Divider(height: 1, indent: 20, endIndent: 20),
          SwitchListTile(
            contentPadding: tilePadding,
            secondary: Icon(Icons.chat_outlined, color: scheme.primary),
            title: const Text('Pengingat Chat Dokter'),
            subtitle: const Text('Ingatkan saya saat dokter membalas'),
            value: _chatReminder,
            onChanged: (v) => _updatePreference(
              () => _chatReminder = v,
              'Preferensi pengingat chat disimpan',
            ),
          ),
          const Divider(height: 1, indent: 20, endIndent: 20),
          SwitchListTile(
            contentPadding: tilePadding,
            secondary: Icon(Icons.mail_outline, color: scheme.primary),
            title: const Text('Email Promosi'),
            subtitle: const Text('Kirim info & penawaran kesehatan'),
            value: _promoEmail,
            onChanged: (v) => _updatePreference(
              () => _promoEmail = v,
              'Preferensi email promosi disimpan',
            ),
          ),
        ],
      ),
    );
  }

  // ── Menu card ───────────────────────────────────────────────────────────────
  Widget _buildMenuCard(ColorScheme scheme) {
    return _sectionCard(
      scheme,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          _menuItem(
            scheme,
            Icons.edit_outlined,
            'Edit Profil',
            onTap: _openEditProfile,
          ),
          _divider(),
          _menuItem(
            scheme,
            Icons.lock_outline,
            'Ganti Password',
            onTap: () => showAppSnack(
              context,
              'Fitur ganti password akan segera hadir',
              success: false,
            ),
          ),
          _divider(),
          _menuItem(
            scheme,
            Icons.help_outline,
            'Bantuan',
            onTap: () => showAppSnack(
              context,
              'Fitur bantuan akan segera hadir',
              success: false,
            ),
          ),
          _divider(),
          _menuItem(
            scheme,
            Icons.info_outline,
            'Tentang Aplikasi',
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'Telehealth App',
              applicationVersion: '1.0.0',
              applicationLegalese: '© 2026 Telehealth App',
            ),
          ),
          _divider(),
          _menuItem(
            scheme,
            Icons.logout,
            'Keluar',
            color: scheme.error,
            onTap: _confirmLogout,
          ),
        ],
      ),
    );
  }

  Widget _menuItem(
    ColorScheme scheme,
    IconData icon,
    String label, {
    VoidCallback? onTap,
    Color? color,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: Icon(icon, color: color ?? scheme.primary),
      title: Text(
        label,
        style: TextStyle(
          color: color ?? const Color(0xFF424242),
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
      onTap: onTap,
    );
  }

  Widget _divider() => const Divider(height: 1, indent: 20, endIndent: 20);

  // ── Actions ─────────────────────────────────────────────────────────────────
  void _updatePreference(VoidCallback apply, String message) {
    setState(apply);
    showAppSnack(context, message);
  }

  Future<void> _openEditProfile() async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: _name);
    final emailCtrl = TextEditingController(text: _email);
    final phoneCtrl = TextEditingController(text: _phone);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Profil'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nama',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    if (value.isEmpty) return 'Nama wajib diisi';
                    if (value.length < 3) return 'Nama minimal 3 karakter';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    if (value.isEmpty) return 'Email wajib diisi';
                    final valid = RegExp(
                      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                    ).hasMatch(value);
                    if (!valid) return 'Format email tidak valid';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Nomor Telepon',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    if (value.isEmpty) return 'Nomor telepon wajib diisi';
                    final digits = value.replaceAll(RegExp(r'\D'), '');
                    if (digits.length < 9) {
                      return 'Nomor telepon minimal 9 digit';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(ctx).pop(true);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (saved == true && mounted) {
      setState(() {
        _name = nameCtrl.text.trim();
        _email = emailCtrl.text.trim();
        _phone = phoneCtrl.text.trim();
      });
      showAppSnack(context, 'Profil berhasil diperbarui');
    }

    nameCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Keluar',
      message: 'Apakah Anda yakin ingin keluar dari akun ini?',
      confirmLabel: 'Keluar',
    );
    if (!confirmed || !mounted) return;
    showAppSnack(context, 'Berhasil keluar');
    await AuthRepository.instance.signOut();
    if (!mounted) return;
    context.goNamed(AppRoutes.loginName);
  }
}
