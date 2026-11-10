import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:Telehealth/core/routing/app_routes.dart';
import 'package:Telehealth/core/widgets/app_dialogs.dart';
import 'package:Telehealth/core/widgets/doctor_nav_bar.dart';
import 'package:Telehealth/data/models/doctor_profile.dart';
import 'package:Telehealth/data/repositories/auth_repository.dart';

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
        title: const Text('Profil Dokter'),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        actions: [
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
            const SizedBox(height: 16),

            _buildCredentialsCard(scheme),
            const SizedBox(height: 12),
            _buildPracticeScheduleCard(scheme),
            const SizedBox(height: 12),
            _buildPreferenceCard(scheme),
            const SizedBox(height: 12),
            _buildMenuCard(scheme),
            const SizedBox(height: 32),
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
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            scheme.primary,
            Color.lerp(scheme.primary, Colors.black, 0.28)!,
          ],
        ),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 54,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: 50,
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
          const SizedBox(height: 14),
          Text(
            _name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            _specialization,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _email,
            style: const TextStyle(fontSize: 13, color: Colors.white60),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 5,
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
                  horizontal: 12,
                  vertical: 5,
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

  // ── Informasi Kredensial & Praktik Medis ─────────────────────────────────────
  Widget _buildCredentialsCard(ColorScheme scheme) {
    final rows = [
      {
        'icon': Icons.local_hospital_outlined,
        'label': 'Rumah Sakit Praktik',
        'value': _hospital,
      },
      {
        'icon': Icons.workspace_premium_outlined,
        'label': 'Spesialisasi',
        'value': _specialization,
      },
      {
        'icon': Icons.badge_outlined,
        'label': 'Nomor STR (Surat Tanda Registrasi)',
        'value': _strNumber,
      },
      {
        'icon': Icons.history_edu_outlined,
        'label': 'Pengalaman Praktik Klinis',
        'value': '$_experienceYears tahun',
      },
      {
        'icon': Icons.phone_outlined,
        'label': 'Nomor Telepon Praktik',
        'value': _phone,
      },
      {
        'icon': Icons.verified_user_outlined,
        'label': 'Status Verifikasi Kredensial',
        'value': _verified ? 'Terverifikasi (Aktif)' : 'Dalam Proses Tinjau',
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Informasi Kredensial Dokter',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    key: const Key('edit_doctor_profile_button'),
                    onPressed: _openEditProfileDialog,
                    icon: const Icon(Icons.edit_note, size: 18),
                    label: const Text('Ubah Data'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              ...rows.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        r['icon'] as IconData,
                        size: 20,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
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
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.notes_rounded, size: 20, color: scheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bio & Keahlian Medis',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _bio,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF37474F),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Jadwal Praktik Dokter ───────────────────────────────────────────────────
  Widget _buildPracticeScheduleCard(ColorScheme scheme) {
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Jadwal Praktik & Konsultasi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _openEditScheduleDialog,
                    icon: const Icon(Icons.schedule, size: 18),
                    label: const Text('Atur Jadwal'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              ..._schedule.entries.map(
                (entry) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.3,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_month,
                        size: 18,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        entry.key,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Preferensi Dokter ───────────────────────────────────────────────────────
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
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                'Preferensi Praktik & Pasien',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            SwitchListTile(
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
            const Divider(height: 1, indent: 16),
            SwitchListTile(
              secondary: Icon(Icons.chat_bubble_outline, color: scheme.primary),
              title: const Text('Notifikasi Pesan Chat'),
              subtitle: const Text('Ingatkan saat pasien membalas chat'),
              value: _notifChatMessage,
              onChanged: (v) => _updatePreference(
                () => _notifChatMessage = v,
                'Preferensi pesan chat disimpan',
              ),
            ),
            const Divider(height: 1, indent: 16),
            SwitchListTile(
              secondary: Icon(
                Icons.online_prediction_rounded,
                color: scheme.primary,
              ),
              title: const Text('Status Menerima Pasien'),
              subtitle: const Text(
                'Tampilkan status online pada antrean pasien',
              ),
              value: _acceptingConsultations,
              onChanged: (v) => _updatePreference(
                () => _acceptingConsultations = v,
                'Status ketersediaan praktik disimpan',
              ),
            ),
            const Divider(height: 1, indent: 16),
            SwitchListTile(
              secondary: Icon(
                Icons.auto_stories_outlined,
                color: scheme.primary,
              ),
              title: const Text('Auto-Ringkasan Sesi'),
              subtitle: const Text(
                'Buat rangkuman medis otomatis setelah sesi',
              ),
              value: _autoSummarize,
              onChanged: (v) => _updatePreference(
                () => _autoSummarize = v,
                'Preferensi rangkuman medis disimpan',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Menu & Pengaturan Akun Dokter ───────────────────────────────────────────
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

      showAppSnack(context, 'Data profil dokter berhasil diperbarui');
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

  void _updatePreference(VoidCallback apply, String message) {
    setState(apply);
    showAppSnack(context, message);
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
      title: const Text('Ubah Profil Dokter'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const Key('edit_doctor_name_field'),
                controller: _nameCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
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
              const SizedBox(height: 10),
              TextFormField(
                controller: _specCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Spesialisasi Medis',
                  prefixIcon: Icon(Icons.workspace_premium_outlined),
                ),
                validator: (v) => v?.trim().isEmpty == true
                    ? 'Spesialisasi wajib diisi'
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _hospitalCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Rumah Sakit / Faskes Praktik',
                  prefixIcon: Icon(Icons.local_hospital_outlined),
                ),
                validator: (v) => v?.trim().isEmpty == true
                    ? 'Rumah sakit wajib diisi'
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _strCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Nomor STR',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (v) =>
                    v?.trim().isEmpty == true ? 'Nomor STR wajib diisi' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _expCtrl,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Pengalaman (Tahun)',
                  prefixIcon: Icon(Icons.history_edu_outlined),
                ),
                validator: (v) {
                  final val = int.tryParse(v?.trim() ?? '');
                  if (val == null || val < 0) return 'Masukkan angka valid';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Nomor Telepon Praktik',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (v) {
                  final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                  if (digits.length < 9) return 'Nomor minimal 9 digit';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _bioCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
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
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          key: const Key('save_doctor_profile_button'),
          onPressed: _submit,
          child: const Text('Simpan Perubahan'),
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
      title: const Text('Atur Jadwal Praktik Dokter'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _weekdayCtrl,
            decoration: const InputDecoration(
              labelText: 'Senin - Jumat',
              hintText: 'Contoh: 09:00 - 15:00',
              prefixIcon: Icon(Icons.access_time),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _weekendCtrl,
            decoration: const InputDecoration(
              labelText: 'Sabtu',
              hintText: 'Contoh: 09:00 - 12:00',
              prefixIcon: Icon(Icons.access_time),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop({
              'Senin - Jumat': _weekdayCtrl.text.trim(),
              'Sabtu': _weekendCtrl.text.trim(),
              'Minggu': widget.initialSchedule['Minggu'] ?? 'Libur / On Call',
            });
          },
          child: const Text('Simpan Jadwal'),
        ),
      ],
    );
  }
}
