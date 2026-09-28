import 'dart:async';

import 'package:flutter/material.dart';

import 'package:telehealth_app/core/widgets/app_dialogs.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // ── Info pengguna (dapat diubah lewat dialog edit) ──────────────────────────
  String _name = 'John Doe';
  String _email = 'john.doe@example.com';
  String _phone = '+62 812 3456 7890';
  static const String _birthDate = '15 Januari 1995';
  static const String _gender = 'Laki-laki';
  static const String _address = 'Jl. Sudirman No. 123, Jakarta Pusat';
  static const String _bloodType = 'A+';

  // ── Preferensi ──────────────────────────────────────────────────────────────
  bool _notifEnabled = true;
  bool _chatReminder = true;
  bool _promoEmail = false;

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
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
            const SizedBox(height: 16),
            _buildInfoCard(scheme),
            const SizedBox(height: 8),
            _buildPreferenceCard(scheme),
            const SizedBox(height: 8),
            _buildMenuCard(scheme),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader(ColorScheme scheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            scheme.primary,
            Color.lerp(scheme.primary, Colors.black, 0.25)!,
          ],
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 56,
            backgroundColor: Colors.white,
            child: CircleAvatar(
              radius: 52,
              backgroundColor: scheme.primaryContainer,
              child: Icon(Icons.person, size: 60, color: scheme.primary),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _email,
            style: const TextStyle(fontSize: 14, color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Pasien',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Info card ───────────────────────────────────────────────────────────────
  Widget _buildInfoCard(ColorScheme scheme) {
    final rows = [
      {'icon': Icons.phone, 'label': 'Telepon', 'value': _phone},
      {'icon': Icons.cake, 'label': 'Tanggal Lahir', 'value': _birthDate},
      {'icon': Icons.wc, 'label': 'Jenis Kelamin', 'value': _gender},
      {'icon': Icons.location_on, 'label': 'Alamat', 'value': _address},
      {
        'icon': Icons.water_drop,
        'label': 'Golongan Darah',
        'value': _bloodType,
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Informasi Pribadi',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Divider(height: 24),
              ...rows.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        r['icon'] as IconData,
                        size: 20,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r['label'] as String,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            r['value'] as String,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Preference card ─────────────────────────────────────────────────────────
  Widget _buildPreferenceCard(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(
                'Preferensi',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            SwitchListTile(
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
            const Divider(height: 1, indent: 16),
            SwitchListTile(
              secondary: Icon(Icons.chat_outlined, color: scheme.primary),
              title: const Text('Pengingat Chat Dokter'),
              subtitle: const Text('Ingatkan saya saat dokter membalas'),
              value: _chatReminder,
              onChanged: (v) => _updatePreference(
                () => _chatReminder = v,
                'Preferensi pengingat chat disimpan',
              ),
            ),
            const Divider(height: 1, indent: 16),
            SwitchListTile(
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
      ),
    );
  }

  // ── Menu card ───────────────────────────────────────────────────────────────
  Widget _buildMenuCard(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Column(
          children: [
            _menuItem(
              scheme,
              Icons.edit,
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

  Widget _divider() => const Divider(height: 1, indent: 56);

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
    unawaited(
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false),
    );
  }
}
