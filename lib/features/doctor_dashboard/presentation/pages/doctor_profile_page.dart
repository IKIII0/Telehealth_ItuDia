import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:Telehealth/core/routing/app_routes.dart';
import 'package:Telehealth/core/widgets/app_dialogs.dart';
import 'package:Telehealth/core/widgets/doctor_nav_bar.dart';
import 'package:Telehealth/core/widgets/role_badge.dart';
import 'package:Telehealth/data/models/doctor_profile.dart';
import 'package:Telehealth/data/repositories/auth_repository.dart';
import 'package:Telehealth/data/repositories/doctor_profile_repository.dart';

/// Halaman profil dokter.
///
/// Menyajikan informasi kredensial, STR, jadwal praktik, preferensi konsultasi,
/// dan data simulasi dokter dengan kemampuan ubah data langsung.
class DoctorProfilePage extends StatefulWidget {
  const DoctorProfilePage({super.key, this.showNavBar = false});

  final bool showNavBar;

  @override
  State<DoctorProfilePage> createState() => _DoctorProfilePageState();
}

class _DoctorProfilePageState extends State<DoctorProfilePage> {
  // ── Info profil dokter (diperbarui melalui dialog edit) ────────────────────
  late String _name;
  late String _email;
  late String _phone;
  late String _specialization;
  late String _strNumber;
  late String _hospital;
  late int _experienceYears;
  late String _bio;
  late Map<String, String> _schedule;
  late bool _verified;

  // ── Preferensi dokter ───────────────────────────────────────────────────────
  bool _notifNewPatient = true;
  bool _notifChatMessage = true;
  bool _acceptingConsultations = true;
  bool _autoSummarize = true;

  @override
  void initState() {
    super.initState();
    _loadDoctorData();
  }

  void _loadDoctorData() {
    _applyLocalProfile();
    _loadRemoteProfile();
  }

  /// Muat profil & preferensi dari Supabase bila tersedia.
  Future<void> _loadRemoteProfile() async {
    final repo = DoctorProfileRepository.instance;
    if (!repo.isRemote) return;

    try {
      final remote = await repo.fetchMine();
      final settings = await repo.fetchSettings();
      if (!mounted) return;
      setState(() {
        if (remote != null) {
          if (remote.specialization.isNotEmpty) {
            _specialization = remote.specialization;
          }
          if (remote.strNumber.isNotEmpty) _strNumber = remote.strNumber;
          if (remote.hospital.isNotEmpty) _hospital = remote.hospital;
          if (remote.experienceYears > 0) {
            _experienceYears = remote.experienceYears;
          }
          if (remote.bio.isNotEmpty) _bio = remote.bio;
          if (remote.practiceSchedule.isNotEmpty) {
            _schedule = Map.from(remote.practiceSchedule);
          }
          _verified = remote.verified;
        }
        if (settings != null) {
          _acceptingConsultations = settings.acceptingConsultations;
          _notifNewPatient = settings.notifyNewRequest;
          _notifChatMessage = settings.notifyChatMessage;
          _autoSummarize = settings.autoSummarize;
        }
      });
    } catch (error) {
      debugPrint('[DoctorProfilePage] gagal memuat profil dokter: $error');
    }
  }

  void _applyLocalProfile() {
    final user = AuthRepository.instance.currentUser;
    final profile = user?.doctorProfile ?? DoctorProfile.simulatedDefault();

    _name = user?.name ?? 'dr. Rifki Al Sauqy, Sp.JP';
    _email = user?.email ?? 'dokter@gmail.com';
    _phone = profile.phone.isNotEmpty ? profile.phone : '+62 812 9000 1122';
    _specialization = profile.specialization.isNotEmpty
        ? profile.specialization
        : 'Spesialis Jantung & Pembuluh Darah';
    _strNumber = profile.strNumber.isNotEmpty
        ? profile.strNumber
        : 'STR-2024-16284';
    _hospital = profile.hospital.isNotEmpty
        ? profile.hospital
        : 'RS Jantung Harapan Kita';
    _experienceYears = profile.experienceYears > 0
        ? profile.experienceYears
        : 12;
    _bio = profile.bio.isNotEmpty
        ? profile.bio
        : 'Spesialis jantung berpengalaman dalam penanganan penyakit '
              'jantung koroner, aritmia, dan gagal jantung. Melayani '
              'konsultasi Telehealth dan edukasi pencegahan kardiovaskular.';
    _schedule = profile.practiceSchedule.isNotEmpty
        ? Map.from(profile.practiceSchedule)
        : {
            'Senin - Jumat': '09:00 - 15:00',
            'Sabtu': '09:00 - 12:00',
            'Minggu': 'Libur / On Call',
          };
    _verified = profile.verified;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      bottomNavigationBar: widget.showNavBar
          ? const DoctorNavBar(currentIndex: 2)
          : null,
      appBar: AppBar(
        title: const Text('Profil'),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        actions: [
          const RoleBadge.doctor(),
          IconButton(
            key: const Key('appbar_edit_doctor_button'),
            icon: const Icon(Icons.edit),
            tooltip: 'Ubah Data Dokter',
            onPressed: _openEditProfileDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(scheme),
            const SizedBox(height: 20),
            _buildCredentialsCard(scheme),
            const SizedBox(height: 20),
            _buildPracticeScheduleCard(scheme),
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

  // ── Header Profil Dokter ────────────────────────────────────────────────────
  Widget _buildHeader(ColorScheme scheme) {
    final user = AuthRepository.instance.currentUser;
    final initials = user?.initials ?? 'DR';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 36),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            scheme.primary,
            Color.lerp(scheme.primary, Colors.black, 0.28)!,
          ],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Stack(
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
                  child: Text(
                    initials,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const CircleAvatar(
                    radius: 12,
                    backgroundColor: Color(0xFF2E7D32),
                    child: Icon(Icons.check, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            _name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            _specialization,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _email,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Colors.white60),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.medical_services, size: 14, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'Dokter Spesialis',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.greenAccent.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _verified ? Icons.verified : Icons.hourglass_top,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _verified
                          ? 'Kredensial Terverifikasi'
                          : 'Menunggu Verifikasi',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
    Widget? trailing,
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
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
          ),
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
                  _cardTitle(scheme, title, icon, trailing),
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

  Widget _cardTitle(
    ColorScheme scheme,
    String title,
    IconData? icon, [
    Widget? trailing,
  ]) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 22, color: scheme.primary),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ),
        ?trailing,
      ],
    );
  }

  Widget _infoRow(
    ColorScheme scheme,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: scheme.primary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                value,
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
    );
  }

  // ── Informasi Kredensial & Praktik Medis ─────────────────────────────────────
  Widget _buildCredentialsCard(ColorScheme scheme) {
    final rows = [
      (Icons.local_hospital_outlined, 'Rumah Sakit Praktik', _hospital),
      (Icons.workspace_premium_outlined, 'Spesialisasi', _specialization),
      (Icons.badge_outlined, 'Nomor STR (Surat Tanda Registrasi)', _strNumber),
      (
        Icons.history_edu_outlined,
        'Pengalaman Praktik Klinis',
        '$_experienceYears tahun',
      ),
      (Icons.phone_outlined, 'Nomor Telepon Praktik', _phone),
      (
        Icons.verified_user_outlined,
        'Status Verifikasi Kredensial',
        _verified ? 'Terverifikasi (Aktif)' : 'Dalam Proses Tinjau',
      ),
    ];

    return _sectionCard(
      scheme,
      title: 'Informasi Kredensial Dokter',
      icon: Icons.assignment_ind_outlined,
      trailing: TextButton.icon(
        key: const Key('edit_doctor_profile_button'),
        onPressed: _openEditProfileDialog,
        icon: const Icon(Icons.edit_note, size: 18),
        label: const Text('Ubah'),
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
      child: Column(
        children: [
          for (final r in rows) ...[
            _infoRow(scheme, r.$1, r.$2, r.$3),
            const Divider(height: 28),
          ],
          _infoRow(scheme, Icons.notes_rounded, 'Bio & Keahlian Medis', _bio),
        ],
      ),
    );
  }

  // ── Jadwal Praktik Dokter ───────────────────────────────────────────────────
  Widget _buildPracticeScheduleCard(ColorScheme scheme) {
    return _sectionCard(
      scheme,
      title: 'Jadwal Praktik & Konsultasi',
      icon: Icons.event_available_outlined,
      trailing: TextButton.icon(
        onPressed: _openEditScheduleDialog,
        icon: const Icon(Icons.schedule, size: 18),
        label: const Text('Atur'),
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
      child: Column(
        children: [
          for (final entry in _schedule.entries)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_month, size: 20, color: scheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: entry.value.toLowerCase().contains('libur')
                          ? Colors.grey.shade200
                          : scheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: entry.value.toLowerCase().contains('libur')
                            ? Colors.grey.shade700
                            : scheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Preferensi Dokter ───────────────────────────────────────────────────────
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
            child: _cardTitle(
              scheme,
              'Preferensi Praktik & Pasien',
              Icons.tune_rounded,
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: tilePadding,
            secondary: Icon(
              Icons.mark_chat_unread_outlined,
              color: scheme.primary,
            ),
            title: const Text('Notifikasi Permintaan Baru'),
            subtitle: const Text(
              'Terima pengingat instan pasien ingin konsultasi',
            ),
            value: _notifNewPatient,
            onChanged: (v) => _updatePreference(
              () => _notifNewPatient = v,
              'Preferensi permintaan konsultasi disimpan',
            ),
          ),
          _divider(),
          SwitchListTile(
            contentPadding: tilePadding,
            secondary: Icon(Icons.chat_bubble_outline, color: scheme.primary),
            title: const Text('Notifikasi Pesan Chat'),
            subtitle: const Text('Ingatkan saat pasien membalas chat'),
            value: _notifChatMessage,
            onChanged: (v) => _updatePreference(
              () => _notifChatMessage = v,
              'Preferensi pesan chat disimpan',
            ),
          ),
          _divider(),
          SwitchListTile(
            contentPadding: tilePadding,
            secondary: Icon(
              Icons.online_prediction_rounded,
              color: scheme.primary,
            ),
            title: const Text('Status Menerima Pasien'),
            subtitle: const Text('Tampilkan status online pada antrean pasien'),
            value: _acceptingConsultations,
            onChanged: (v) => _updatePreference(
              () => _acceptingConsultations = v,
              'Status ketersediaan praktik disimpan',
            ),
          ),
          _divider(),
          SwitchListTile(
            contentPadding: tilePadding,
            secondary: Icon(Icons.auto_stories_outlined, color: scheme.primary),
            title: const Text('Auto-Ringkasan Sesi'),
            subtitle: const Text('Buat rangkuman medis otomatis setelah sesi'),
            value: _autoSummarize,
            onChanged: (v) => _updatePreference(
              () => _autoSummarize = v,
              'Preferensi rangkuman medis disimpan',
            ),
          ),
        ],
      ),
    );
  }

  // ── Menu & Pengaturan Akun Dokter ───────────────────────────────────────────
  Widget _buildMenuCard(ColorScheme scheme) {
    return _sectionCard(
      scheme,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          _menuItem(
            scheme,
            Icons.edit_outlined,
            'Ubah Data Profil Dokter',
            onTap: _openEditProfileDialog,
          ),
          _divider(),
          _menuItem(
            scheme,
            Icons.calendar_month_outlined,
            'Atur Jadwal Praktik',
            onTap: _openEditScheduleDialog,
          ),
          _divider(),
          _menuItem(
            scheme,
            Icons.lock_outline,
            'Ganti Password Akun',
            onTap: () => showAppSnack(
              context,
              'Tautan ubah kata sandi dapat diakses lewat menu reset password.',
            ),
          ),
          _divider(),
          _menuItem(
            scheme,
            Icons.medical_information_outlined,
            'Pedoman Praktik Telehealth',
            onTap: () => _showTelehealthGuidelines(),
          ),
          _divider(),
          _menuItem(
            scheme,
            Icons.info_outline,
            'Tentang Telehealth',
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'Telehealth',
              applicationVersion: '1.0.0',
              applicationLegalese: '© 2026 Telehealth. Hak Cipta Dilindungi.',
            ),
          ),
          _divider(),
          _menuItem(
            scheme,
            Icons.logout,
            'Keluar akun',
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

  // ── Dialog Ubah Data Profil Dokter ──────────────────────────────────────────
  Future<void> _openEditProfileDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _EditDoctorProfileDialog(
        initialName: _name,
        initialPhone: _phone,
        initialSpecialization: _specialization,
        initialHospital: _hospital,
        initialStr: _strNumber,
        initialExperience: _experienceYears,
        initialBio: _bio,
      ),
    );

    if (result != null && mounted) {
      final updatedName = result['name'] as String;
      final updatedPhone = result['phone'] as String;
      final updatedSpec = result['specialization'] as String;
      final updatedHospital = result['hospital'] as String;
      final updatedStr = result['strNumber'] as String;
      final updatedExp = result['experienceYears'] as int;
      final updatedBio = result['bio'] as String;

      AuthRepository.instance.updateDoctorProfile(
        name: updatedName,
        phone: updatedPhone,
        specialization: updatedSpec,
        hospital: updatedHospital,
        strNumber: updatedStr,
        experienceYears: updatedExp,
        bio: updatedBio,
      );

      setState(() {
        _name = updatedName;
        _phone = updatedPhone;
        _specialization = updatedSpec;
        _hospital = updatedHospital;
        _strNumber = updatedStr;
        _experienceYears = updatedExp;
        _bio = updatedBio;
      });

      final saved = await _persistProfile();
      if (!mounted) return;
      showAppSnack(
        context,
        saved
            ? 'Data profil dokter berhasil diperbarui'
            : 'Profil tersimpan lokal, gagal sinkron database',
        success: saved,
      );
    }
  }

  // ── Dialog Atur Jadwal Praktik ──────────────────────────────────────────────
  Future<void> _openEditScheduleDialog() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => _EditDoctorScheduleDialog(initialSchedule: _schedule),
    );

    if (result != null && mounted) {
      AuthRepository.instance.updateDoctorProfile(practiceSchedule: result);

      setState(() {
        _schedule = result;
      });

      try {
        await DoctorProfileRepository.instance.saveSchedule(result);
      } catch (error) {
        if (mounted) {
          showAppSnack(
            context,
            'Jadwal tersimpan lokal, gagal sinkron database: $error',
            success: false,
          );
        }
        return;
      }

      if (!mounted) return;
      showAppSnack(context, 'Jadwal praktik dokter berhasil diperbarui');
    }
  }

  void _showTelehealthGuidelines() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pedoman Praktik Telehealth'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '1. Validasi Identitas Pasien',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Selalu pastikan identitas pasien sesuai sebelum memberikan '
                'anjuran atau resep elektronik.',
                style: TextStyle(fontSize: 13),
              ),
              SizedBox(height: 10),
              Text(
                '2. Kewaspadaan Tanda Bahaya (Red Flags)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Bila pasien menunjukkan kegawatdaruratan, arahkan segera ke IGD '
                'atau rumah sakit terdekat.',
                style: TextStyle(fontSize: 13),
              ),
              SizedBox(height: 10),
              Text(
                '3. Kerahasiaan Rekam Medis',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Data riwayat konsultasi pasien terlindungi oleh standar privasi '
                'dan kerahasiaan medis.',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Future<void> _updatePreference(VoidCallback apply, String message) async {
    setState(apply);
    final saved = await _saveSettings();
    if (!mounted) return;
    showAppSnack(
      context,
      saved ? message : 'Preferensi tersimpan lokal, gagal sinkron database',
      success: saved,
    );
  }

  Future<bool> _saveSettings() async {
    final repo = DoctorProfileRepository.instance;
    if (!repo.isRemote) return true;
    try {
      await repo.saveSettings(
        acceptingConsultations: _acceptingConsultations,
        notifyNewRequest: _notifNewPatient,
        notifyChatMessage: _notifChatMessage,
        autoSummarize: _autoSummarize,
        dailyQuota: 12,
      );
      return true;
    } catch (error) {
      debugPrint('[DoctorProfilePage] gagal menyimpan preferensi: $error');
      return false;
    }
  }

  /// Simpan profil dokter ke Supabase (bila terhubung).
  Future<bool> _persistProfile() async {
    final repo = DoctorProfileRepository.instance;
    if (!repo.isRemote) return true;
    try {
      await repo.saveProfile(
        name: _name,
        phone: _phone,
        specialization: _specialization,
        strNumber: _strNumber,
        hospital: _hospital,
        experienceYears: _experienceYears,
        bio: _bio,
        practiceSchedule: _schedule,
      );
      return true;
    } catch (error) {
      debugPrint('[DoctorProfilePage] gagal menyimpan profil: $error');
      return false;
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Keluar',
      message: 'Apakah Anda yakin ingin keluar?',
      confirmLabel: 'Keluar',
    );
    if (!confirmed || !mounted) return;
    showAppSnack(context, 'Berhasil keluar');
    await AuthRepository.instance.signOut();
    if (!mounted) return;
    context.goNamed(AppRoutes.loginName);
  }
}

/// Dialog stateful untuk ubah data dokter agar controller dikelola dengan aman.
InputDecoration _dialogDecoration({
  required String labelText,
  String? hintText,
  bool alignLabelWithHint = false,
  required Icon prefixIcon,
}) {
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    alignLabelWithHint: alignLabelWithHint,
    prefixIcon: prefixIcon,
    border: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
    ),
  );
}

ButtonStyle _dialogButtonShape(
  ButtonStyle Function({EdgeInsetsGeometry? padding, OutlinedBorder? shape})
  factory,
) {
  return factory(
    padding: const EdgeInsets.symmetric(vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );
}

Widget _dialogTitle(BuildContext context, String text, IconData icon) {
  final scheme = Theme.of(context).colorScheme;
  return Row(
    children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 22, color: scheme.primary),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    ],
  );
}

class _EditDoctorProfileDialog extends StatefulWidget {
  const _EditDoctorProfileDialog({
    required this.initialName,
    required this.initialPhone,
    required this.initialSpecialization,
    required this.initialHospital,
    required this.initialStr,
    required this.initialExperience,
    required this.initialBio,
  });

  final String initialName;
  final String initialPhone;
  final String initialSpecialization;
  final String initialHospital;
  final String initialStr;
  final int initialExperience;
  final String initialBio;

  @override
  State<_EditDoctorProfileDialog> createState() =>
      _EditDoctorProfileDialogState();
}

class _EditDoctorProfileDialogState extends State<_EditDoctorProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _specCtrl;
  late final TextEditingController _hospitalCtrl;
  late final TextEditingController _strCtrl;
  late final TextEditingController _expCtrl;
  late final TextEditingController _bioCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _phoneCtrl = TextEditingController(text: widget.initialPhone);
    _specCtrl = TextEditingController(text: widget.initialSpecialization);
    _hospitalCtrl = TextEditingController(text: widget.initialHospital);
    _strCtrl = TextEditingController(text: widget.initialStr);
    _expCtrl = TextEditingController(text: widget.initialExperience.toString());
    _bioCtrl = TextEditingController(text: widget.initialBio);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _specCtrl.dispose();
    _hospitalCtrl.dispose();
    _strCtrl.dispose();
    _expCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).pop({
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'specialization': _specCtrl.text.trim(),
        'hospital': _hospitalCtrl.text.trim(),
        'strNumber': _strCtrl.text.trim(),
        'experienceYears': int.parse(_expCtrl.text.trim()),
        'bio': _bioCtrl.text.trim(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(28, 28, 28, 8),
      contentPadding: const EdgeInsets.fromLTRB(28, 12, 28, 8),
      actionsPadding: const EdgeInsets.fromLTRB(28, 12, 28, 24),
      title: _dialogTitle(context, 'Ubah Profil Dokter', Icons.edit_outlined),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const Key('edit_doctor_name_field'),
                controller: _nameCtrl,
                textInputAction: TextInputAction.next,
                decoration: _dialogDecoration(
                  labelText: 'Nama Lengkap & Gelar',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return 'Nama dokter wajib diisi';
                  if (value.length < 3) return 'Nama minimal 3 karakter';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _specCtrl,
                textInputAction: TextInputAction.next,
                decoration: _dialogDecoration(
                  labelText: 'Spesialisasi Medis',
                  prefixIcon: Icon(Icons.workspace_premium_outlined),
                ),
                validator: (v) => v?.trim().isEmpty == true
                    ? 'Spesialisasi wajib diisi'
                    : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _hospitalCtrl,
                textInputAction: TextInputAction.next,
                decoration: _dialogDecoration(
                  labelText: 'Rumah Sakit / Faskes Praktik',
                  prefixIcon: Icon(Icons.local_hospital_outlined),
                ),
                validator: (v) => v?.trim().isEmpty == true
                    ? 'Rumah sakit wajib diisi'
                    : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _strCtrl,
                textInputAction: TextInputAction.next,
                decoration: _dialogDecoration(
                  labelText: 'Nomor STR',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (v) =>
                    v?.trim().isEmpty == true ? 'Nomor STR wajib diisi' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _expCtrl,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: _dialogDecoration(
                  labelText: 'Pengalaman (Tahun)',
                  prefixIcon: Icon(Icons.history_edu_outlined),
                ),
                validator: (v) {
                  final val = int.tryParse(v?.trim() ?? '');
                  if (val == null || val < 0) return 'Masukkan angka valid';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: _dialogDecoration(
                  labelText: 'Nomor Telepon Praktik',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (v) {
                  final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                  if (digits.length < 9) return 'Nomor minimal 9 digit';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _bioCtrl,
                maxLines: 3,
                decoration: _dialogDecoration(
                  labelText: 'Bio & Ringkasan Keahlian',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
                validator: (v) =>
                    v?.trim().isEmpty == true ? 'Bio wajib diisi' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: _dialogButtonShape(OutlinedButton.styleFrom),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Batal'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                key: const Key('save_doctor_profile_button'),
                style: _dialogButtonShape(FilledButton.styleFrom),
                onPressed: _submit,
                child: const Text('Simpan'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Dialog stateful untuk atur jadwal praktik.
class _EditDoctorScheduleDialog extends StatefulWidget {
  const _EditDoctorScheduleDialog({required this.initialSchedule});

  final Map<String, String> initialSchedule;

  @override
  State<_EditDoctorScheduleDialog> createState() =>
      _EditDoctorScheduleDialogState();
}

class _EditDoctorScheduleDialogState extends State<_EditDoctorScheduleDialog> {
  late final TextEditingController _weekdayCtrl;
  late final TextEditingController _weekendCtrl;

  @override
  void initState() {
    super.initState();
    _weekdayCtrl = TextEditingController(
      text: widget.initialSchedule['Senin - Jumat'] ?? '09:00 - 15:00',
    );
    _weekendCtrl = TextEditingController(
      text: widget.initialSchedule['Sabtu'] ?? '09:00 - 12:00',
    );
  }

  @override
  void dispose() {
    _weekdayCtrl.dispose();
    _weekendCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(28, 28, 28, 8),
      contentPadding: const EdgeInsets.fromLTRB(28, 12, 28, 8),
      actionsPadding: const EdgeInsets.fromLTRB(28, 12, 28, 24),
      title: _dialogTitle(
        context,
        'Atur Jadwal Praktik Dokter',
        Icons.schedule,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          TextField(
            controller: _weekdayCtrl,
            decoration: _dialogDecoration(
              labelText: 'Senin - Jumat',
              hintText: 'Contoh: 09:00 - 15:00',
              prefixIcon: Icon(Icons.access_time),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _weekendCtrl,
            decoration: _dialogDecoration(
              labelText: 'Sabtu',
              hintText: 'Contoh: 09:00 - 12:00',
              prefixIcon: Icon(Icons.access_time),
            ),
          ),
        ],
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: _dialogButtonShape(OutlinedButton.styleFrom),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Batal'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                style: _dialogButtonShape(FilledButton.styleFrom),
                onPressed: () {
                  Navigator.of(context).pop({
                    'Senin - Jumat': _weekdayCtrl.text.trim(),
                    'Sabtu': _weekendCtrl.text.trim(),
                    'Minggu':
                        widget.initialSchedule['Minggu'] ?? 'Libur / On Call',
                  });
                },
                child: const Text('Simpan'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
