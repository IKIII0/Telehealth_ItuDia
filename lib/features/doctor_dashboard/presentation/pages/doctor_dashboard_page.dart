import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:Telehealth/core/routing/app_routes.dart';
import 'package:Telehealth/core/widgets/app_dialogs.dart';
import 'package:Telehealth/core/widgets/doctor_nav_bar.dart';
import 'package:Telehealth/data/models/doctor_profile.dart';
import 'package:Telehealth/data/repositories/auth_repository.dart';

/// Model dummy permintaan konsultasi dari pasien.
class _ConsultationRequest {
  _ConsultationRequest({
    required this.id,
    required this.patientName,
    required this.age,
    required this.gender,
    required this.complaint,
    required this.requestedTime,
    required this.method,
    required this.priority,
    this.status = _RequestStatus.pending,
  });

  final String id;
  final String patientName;
  final int age;
  final String gender;
  final String complaint;
  final String requestedTime;
  final String method;
  final String priority;
  _RequestStatus status;
}

enum _RequestStatus { pending, accepted, rejected }

/// Model dummy jadwal konsultasi dokter yang sudah terkonfirmasi.
class _DoctorAppointment {
  const _DoctorAppointment({
    required this.id,
    required this.patientName,
    required this.time,
    required this.date,
    required this.consultationType,
    required this.statusLabel,
    required this.isActiveNow,
  });

  final String id;
  final String patientName;
  final String time;
  final String date;
  final String consultationType;
  final String statusLabel;
  final bool isActiveNow;
}

/// Halaman utama (dashboard) untuk dokter.
///
/// Menyajikan jadwal kerja dokter, statistik praktik, antrean pasien yang
/// meminta sesi konsultasi, dan jadwal sesi terkonfirmasi.
class DoctorDashboardPage extends StatefulWidget {
  const DoctorDashboardPage({super.key, this.showNavBar = false});

  final bool showNavBar;

  @override
  State<DoctorDashboardPage> createState() => _DoctorDashboardPageState();
}

class _DoctorDashboardPageState extends State<DoctorDashboardPage> {
  bool _isOnline = true;

  // ── Data dummy permintaan sesi konsultasi dari pasien ───────────────────────
  final List<_ConsultationRequest> _requests = [
    _ConsultationRequest(
      id: 'req-1',
      patientName: 'Budi Santoso',
      age: 48,
      gender: 'Laki-laki',
      complaint:
          'Nyeri dada sebelah kiri tembus ke punggung setelah menaiki tangga dan napas terasa berat.',
      requestedTime: 'Hari ini, 10:30 WIB',
      method: 'Chat Online',
      priority: 'Prioritas Tinggi',
    ),
    _ConsultationRequest(
      id: 'req-2',
      patientName: 'Siti Aminah',
      age: 35,
      gender: 'Perempuan',
      complaint:
          'Evaluasi hasil rekam EKG dan tekanan darah mingguan setelah 2 minggu mengonsumsi obat antihipertensi.',
      requestedTime: 'Hari ini, 11:15 WIB',
      method: 'Video Call',
      priority: 'Rutin',
    ),
    _ConsultationRequest(
      id: 'req-3',
      patientName: 'Rudi Hermawan',
      age: 52,
      gender: 'Laki-laki',
      complaint:
          'Detak jantung berdebar cepat (palpitasi) mendadak di malam hari disertai rasa cemas.',
      requestedTime: 'Hari ini, 13:00 WIB',
      method: 'Chat Online',
      priority: 'Prioritas Sedang',
    ),
    _ConsultationRequest(
      id: 'req-4',
      patientName: 'Dewi Lestari',
      age: 29,
      gender: 'Perempuan',
      complaint:
          'Pemeriksaan rujukan lanjutan nyeri ulu hati dan riwayat aritmia ringan.',
      requestedTime: 'Hari ini, 14:15 WIB',
      method: 'Chat Online',
      priority: 'Rutin',
    ),
  ];

  // ── Data dummy jadwal konsultasi terkonfirmasi hari ini ──────────────────────
  final List<_DoctorAppointment> _confirmedAppointments = [
    const _DoctorAppointment(
      id: 'apt-d1',
      patientName: 'Ny. Ratna Dewi (42 th)',
      time: '09:30 WIB',
      date: 'Hari ini',
      consultationType: 'Chat Dokter',
      statusLabel: 'Sedang Berlangsung',
      isActiveNow: true,
    ),
    const _DoctorAppointment(
      id: 'apt-d2',
      patientName: 'Tn. Hendra Wijaya (50 th)',
      time: '14:00 WIB',
      date: 'Hari ini',
      consultationType: 'Video Call',
      statusLabel: 'Mendatang',
      isActiveNow: false,
    ),
    const _DoctorAppointment(
      id: 'apt-d3',
      patientName: 'Sdr. Kevin Pratama (27 th)',
      time: '15:30 WIB',
      date: 'Hari ini',
      consultationType: 'Chat Dokter',
      statusLabel: 'Mendatang',
      isActiveNow: false,
    ),
  ];

  void _acceptRequest(_ConsultationRequest request) {
    setState(() {
      request.status = _RequestStatus.accepted;
    });
    showAppSnack(
      context,
      'Permintaan konsultasi dari ${request.patientName} diterima. Sesi telah dijadwalkan.',
    );
  }

  void _rejectRequest(_ConsultationRequest request) {
    setState(() {
      request.status = _RequestStatus.rejected;
    });
    showAppSnack(
      context,
      'Permintaan konsultasi dari ${request.patientName} ditolak.',
      success: false,
    );
  }

  void _goToProfile() {
    context.goNamed(AppRoutes.doctorProfileName);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = AuthRepository.instance.currentUser;
    final profile = user?.doctorProfile ?? DoctorProfile.simulatedDefault();

    final pendingRequests =
        _requests.where((r) => r.status == _RequestStatus.pending).toList();

    return Scaffold(
      bottomNavigationBar:
          widget.showNavBar ? const DoctorNavBar(currentIndex: 0) : null,
      appBar: AppBar(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Portal Dokter',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
            Text(
              user?.name ?? 'dr. Rifki Al Sauqy, Sp.JP',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          // Toggle Online Status
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: InkWell(
              onTap: () {
                setState(() => _isOnline = !_isOnline);
                showAppSnack(
                  context,
                  _isOnline
                      ? 'Status: Online & Siap Menerima Pasien'
                      : 'Status: Istirahat / Sibuk',
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _isOnline ? Colors.greenAccent : Colors.orangeAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isOnline ? 'Aktif' : 'Istirahat',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Notifikasi',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => showAppSnack(
              context,
              'Ada ${pendingRequests.length} permintaan konsultasi baru yang menunggu konfirmasi Anda.',
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _goToProfile,
              child: CircleAvatar(
                radius: 17,
                backgroundColor: Colors.white24,
                child: Text(
                  user?.initials ?? 'DR',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
          showAppSnack(context, 'Data dashboard diperbarui');
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Banner Dokter & Ringkasan Statistik ────────────────────
              _buildDoctorHeaderCard(scheme, user?.name, profile),
              const SizedBox(height: 16),

              // ── 2. Jadwal Kerja Dokter ────────────────────────────────────
              _buildSectionTitle(
                context,
                title: 'Jadwal Kerja & Praktik Dokter',
                subtitle: 'Jam operasional poli & telekonsultasi hari ini',
                actionLabel: 'Lihat Semua',
                onAction: () => _showWeeklyScheduleModal(context, profile),
              ),
              const SizedBox(height: 8),
              _buildWorkScheduleCard(scheme, profile),
              const SizedBox(height: 20),

              // ── 3. Daftar Pasien yang Meminta Sesi Konsultasi ─────────────
              _buildSectionTitle(
                context,
                title: 'Permintaan Konsultasi Pasien',
                subtitle: 'Menunggu konfirmasi sesi konsultasi',
                badgeCount: pendingRequests.length,
              ),
              const SizedBox(height: 8),
              _buildConsultationRequestsSection(scheme, pendingRequests),
              const SizedBox(height: 20),

              // ── 4. Sesi Konsultasi Terkonfirmasi / Hari Ini ───────────────
              _buildSectionTitle(
                context,
                title: 'Jadwal Sesi Pasien Hari Ini',
                subtitle: 'Konsultasi yang telah terkonfirmasi',
              ),
              const SizedBox(height: 8),
              _buildConfirmedScheduleList(scheme),
              const SizedBox(height: 20),

              // ── 5. Aksi Cepat Medis Dokter ────────────────────────────────
              _buildQuickActions(scheme),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header Banner Dokter & Ringkasan Statistik ──────────────────────────────
  Widget _buildDoctorHeaderCard(
    ColorScheme scheme,
    String? name,
    DoctorProfile profile,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary,
            Color.lerp(scheme.primary, Colors.black, 0.3)!,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white24,
                child: Icon(
                  Icons.medical_services_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selamat Bertugas,',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name ?? 'dr. Rifki Al Sauqy, Sp.JP',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${profile.specialization} • ${profile.hospital}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _goToProfile,
                tooltip: 'Buka Profil Dokter',
                icon: const Icon(Icons.arrow_forward_ios, size: 16),
                color: Colors.white70,
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 24),
          // Baris Statistik Cepat
          Row(
            children: [
              _buildStatCol(
                'Permintaan',
                '${_requests.where((r) => r.status == _RequestStatus.pending).length} Baru',
              ),
              _buildStatDivider(),
              _buildStatCol('Sesi Hari Ini', '${_confirmedAppointments.length} Pasien'),
              _buildStatDivider(),
              _buildStatCol('Selesai', '18 Sesi'),
              _buildStatDivider(),
              _buildStatCol('Rating', '4.9 ★'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCol(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 26,
      color: Colors.white24,
    );
  }

  // ── Section Title Helper ────────────────────────────────────────────────────
  Widget _buildSectionTitle(
    BuildContext context, {
    required String title,
    required String subtitle,
    int? badgeCount,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (badgeCount != null && badgeCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(width: 8),
          InkWell(
            onTap: onAction,
            child: Text(
              actionLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── Jadwal Kerja Dokter ─────────────────────────────────────────────────────
  Widget _buildWorkScheduleCard(ColorScheme scheme, DoctorProfile profile) {
    final scheduleToday = profile.practiceSchedule['Senin - Jumat'] ?? '09:00 - 15:00';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.access_time_filled,
                    color: scheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Shift Praktik Hari Ini',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Hari Ini: $scheduleToday WIB',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 12, color: Colors.green),
                      SizedBox(width: 4),
                      Text(
                        'Sedang Bertugas',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 22),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Poli Rawat Jalan & Konsultasi Telehealth • ${profile.hospital}',
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Kuota Pasien
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Kapasitas Antrean Konsultasi',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '8 dari 12 Pasien (Sisa 4)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: 8 / 12,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _showWeeklyScheduleModal(context, profile),
              icon: const Icon(Icons.calendar_today, size: 16),
              label: const Text('Lihat Seluruh Jadwal Praktik Mingguan'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 38),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Modal Jadwal Mingguan Dokter ────────────────────────────────────────────
  void _showWeeklyScheduleModal(BuildContext context, DoctorProfile profile) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Jadwal Praktik Dokter Mingguan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            const Divider(),
            ...profile.practiceSchedule.entries.map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.event_note, size: 20, color: Colors.blue),
                    const SizedBox(width: 12),
                    Text(
                      e.key,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: e.value.toLowerCase().contains('libur')
                            ? Colors.grey.shade100
                            : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        e.value,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: e.value.toLowerCase().contains('libur')
                              ? Colors.grey.shade700
                              : Colors.blue.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                _goToProfile();
              },
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Atur Jadwal di Halaman Profil'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Permintaan Sesi Konsultasi Pasien ────────────────────────────────────────
  Widget _buildConsultationRequestsSection(
    ColorScheme scheme,
    List<_ConsultationRequest> pendingRequests,
  ) {
    if (pendingRequests.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 40,
                  color: Colors.green.shade400,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Semua Permintaan Telah Ditangani',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'Belum ada permintaan konsultasi pasien baru saat ini.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: pendingRequests.map((req) {
        final isHighPriority = req.priority == 'Prioritas Tinggi';
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: isHighPriority
                  ? Colors.red.withValues(alpha: 0.35)
                  : Colors.transparent,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: scheme.primary.withValues(alpha: 0.12),
                      child: Icon(Icons.person, color: scheme.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  '${req.patientName} (${req.age} th)',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '• ${req.gender}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 12,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                req.requestedTime,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isHighPriority
                            ? Colors.red.shade50
                            : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isHighPriority
                              ? Colors.red.shade200
                              : Colors.blue.shade200,
                        ),
                      ),
                      child: Text(
                        req.priority,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isHighPriority
                              ? Colors.red.shade700
                              : Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.medical_information_outlined,
                        size: 16,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          req.complaint,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF263238),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              req.method == 'Video Call'
                                  ? Icons.videocam_outlined
                                  : Icons.chat_outlined,
                              size: 13,
                              color: Colors.grey.shade700,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                req.method,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => _rejectRequest(req),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: scheme.error,
                        side: BorderSide(
                          color: scheme.error.withValues(alpha: 0.5),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Tolak'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => _acceptRequest(req),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Terima Sesi'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Sesi Konsultasi Terkonfirmasi / Hari Ini ─────────────────────────────────
  Widget _buildConfirmedScheduleList(ColorScheme scheme) {
    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _confirmedAppointments.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final apt = _confirmedAppointments[i];
          final gradientEnd =
              Color.lerp(scheme.primary, Colors.black, 0.25)!;

          return Container(
            width: 260,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: apt.isActiveNow
                    ? [scheme.primary, gradientEnd]
                    : [
                        scheme.primary.withValues(alpha: 0.85),
                        Color.lerp(scheme.primary, Colors.black, 0.15)!,
                      ],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.white24,
                      child: Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        apt.patientName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      apt.consultationType == 'Video Call'
                          ? Icons.videocam
                          : Icons.chat,
                      color: Colors.white70,
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        apt.consultationType,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: apt.isActiveNow
                            ? Colors.green.withValues(alpha: 0.3)
                            : Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        apt.statusLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            color: Colors.white70,
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${apt.date}, ${apt.time}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => showAppSnack(
                        context,
                        'Membuka sesi konsultasi bersama ${apt.patientName}',
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          apt.isActiveNow ? 'Mulai Chat' : 'Detail',
                          style: TextStyle(
                            color: scheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Aksi Cepat Medis ────────────────────────────────────────────────────────
  Widget _buildQuickActions(ColorScheme scheme) {
    final actions = [
      {
        'icon': Icons.edit_document,
        'label': 'Resep Obat\nElektronik',
        'color': Colors.blue.shade700,
        'action': () => showAppSnack(context, 'Modul e-resep siap dibuat'),
      },
      {
        'icon': Icons.folder_shared_outlined,
        'label': 'Rekam Medis\nPasien',
        'color': Colors.teal.shade700,
        'action': () => showAppSnack(context, 'Arsip rekam medis pasien'),
      },
      {
        'icon': Icons.calendar_month,
        'label': 'Atur Jadwal\nPraktik',
        'color': Colors.indigo.shade700,
        'action': _goToProfile,
      },
      {
        'icon': Icons.manage_accounts_outlined,
        'label': 'Profil &\nKredensial',
        'color': Colors.deepPurple.shade700,
        'action': _goToProfile,
      },
    ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Aksi Cepat Dokter',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            Row(
              children: actions.map((act) {
                return Expanded(
                  child: InkWell(
                    onTap: act['action'] as VoidCallback,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 6,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor:
                                (act['color'] as Color).withValues(alpha: 0.1),
                            child: Icon(
                              act['icon'] as IconData,
                              color: act['color'] as Color,
                              size: 22,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            act['label'] as String,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
