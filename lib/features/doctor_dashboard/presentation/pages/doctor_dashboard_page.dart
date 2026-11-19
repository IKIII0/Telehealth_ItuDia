import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:Telehealth/core/routing/app_routes.dart';
import 'package:Telehealth/core/widgets/app_dialogs.dart';
import 'package:Telehealth/core/widgets/doctor_nav_bar.dart';
import 'package:Telehealth/data/models/consultation_session.dart';
import 'package:Telehealth/data/models/doctor_profile.dart';
import 'package:Telehealth/data/repositories/auth_repository.dart';
import 'package:Telehealth/data/repositories/consultation_repository.dart';

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

  // ── Sumber data dashboard ──────────────────────────────────────────────────
  final _repo = ConsultationRepository.instance;

  /// Permintaan yang tampil. Diisi dari Supabase bila terhubung, selain itu
  /// dari data simulasi di bawah.
  List<_ConsultationRequest> _requests = [];

  /// Sesi hari ini (terjadwal / berlangsung).
  List<_DoctorAppointment> _confirmedAppointments = [];

  int _completedTotal = 18;
  int _queueFilled = 8;
  int _dailyQuota = 12;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    try {
      final data = await _repo.getDashboardData();
      if (!mounted) return;
      setState(() {
        _completedTotal = data.completedTotal;
        _queueFilled = data.queueFilled;
        _dailyQuota = data.dailyQuota;
        _requests = data.isRemote
            ? data.requests.map(_requestFromSession).toList()
            : _demoRequests();
        _confirmedAppointments = data.isRemote
            ? data.todaySessions.map(_appointmentFromSession).toList()
            : _demoAppointments();
      });
    } catch (error) {
      if (!mounted) return;
      showAppSnack(
        context,
        'Gagal memuat data dashboard: $error',
        success: false,
      );
    }
  }

  _ConsultationRequest _requestFromSession(ConsultationSession session) {
    return _ConsultationRequest(
      id: session.sessionId,
      patientName: session.patientName,
      age: session.patientAge,
      gender: session.patientGender,
      complaint: session.complaint,
      requestedTime: session.scheduledTime,
      method: session.consultationType,
      priority: switch (session.priority) {
        'high' => 'Prioritas Tinggi',
        'medium' => 'Prioritas Sedang',
        _ => 'Rutin',
      },
    );
  }

  _DoctorAppointment _appointmentFromSession(ConsultationSession session) {
    final parts = session.scheduledTime.split(', ');
    return _DoctorAppointment(
      id: session.sessionId,
      patientName: session.patientAge > 0
          ? '${session.patientName} (${session.patientAge} th)'
          : session.patientName,
      time: parts.length > 1 ? parts.last : session.scheduledTime,
      date: parts.length > 1 ? parts.first : 'Hari ini',
      consultationType: session.consultationType,
      statusLabel: session.status == ConsultationStatus.ongoing
          ? 'Sedang Berlangsung'
          : 'Mendatang',
      isActiveNow: session.status == ConsultationStatus.ongoing,
    );
  }

  // ── Data simulasi (dipakai bila Supabase belum dikonfigurasi) ──────────────
  List<_ConsultationRequest> _demoRequests() => [
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

  List<_DoctorAppointment> _demoAppointments() => [
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

  Future<void> _acceptRequest(_ConsultationRequest request) async {
    if (_repo.isRemote) {
      try {
        await _repo.respondRequest(request.id, accept: true);
        await _loadDashboard();
      } catch (error) {
        if (!mounted) return;
        showAppSnack(
          context,
          'Gagal menerima permintaan: $error',
          success: false,
        );
        return;
      }
    } else {
      setState(() => request.status = _RequestStatus.accepted);
    }
    if (!mounted) return;
    showAppSnack(
      context,
      'Permintaan konsultasi dari ${request.patientName} diterima. Sesi telah dijadwalkan.',
    );
  }

  Future<void> _rejectRequest(_ConsultationRequest request) async {
    if (_repo.isRemote) {
      try {
        await _repo.respondRequest(request.id, accept: false);
        await _loadDashboard();
      } catch (error) {
        if (!mounted) return;
        showAppSnack(
          context,
          'Gagal menolak permintaan: $error',
          success: false,
        );
        return;
      }
    } else {
      setState(() => request.status = _RequestStatus.rejected);
    }
    if (!mounted) return;
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

    final pendingRequests = _requests
        .where((r) => r.status == _RequestStatus.pending)
        .toList();

    return Scaffold(
      bottomNavigationBar: widget.showNavBar
          ? const DoctorNavBar(currentIndex: 0)
          : null,
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
                  _isOnline ? 'Status: Aktif' : 'Status: Istirahat',
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
                      color: _isOnline
                          ? Colors.greenAccent
                          : Colors.orangeAccent,
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
              '${pendingRequests.length} permintaan konsultasi baru',
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
          await _loadDashboard();
          if (!mounted) return;
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
                title: 'Jadwal Praktik',
                actionLabel: 'Lihat Semua',
                onAction: () => _showWeeklyScheduleModal(context, profile),
              ),
              const SizedBox(height: 8),
              _buildWorkScheduleCard(scheme, profile),
              const SizedBox(height: 20),

              // ── 3. Daftar Pasien yang Meminta Sesi Konsultasi ─────────────
              _buildSectionTitle(
                context,
                title: 'Permintaan Konsultasi',
                badgeCount: pendingRequests.length,
              ),
              const SizedBox(height: 8),
              _buildConsultationRequestsSection(scheme, pendingRequests),
              const SizedBox(height: 20),

              // ── 4. Sesi Konsultasi Terkonfirmasi / Hari Ini ───────────────
              _buildSectionTitle(context, title: 'Sesi Hari Ini'),
              const SizedBox(height: 8),
              _buildConfirmedScheduleList(scheme),
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
    final pendingCount = _requests
        .where((r) => r.status == _RequestStatus.pending)
        .length;

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
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
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
              _buildStatCol('Permintaan', '$pendingCount'),
              _buildStatDivider(),
              _buildStatCol('Hari Ini', '${_confirmedAppointments.length}'),
              _buildStatDivider(),
              _buildStatCol('Selesai', '$_completedTotal'),
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
    return Container(width: 1, height: 26, color: Colors.white24);
  }

  // ── Section Title Helper ────────────────────────────────────────────────────
  Widget _buildSectionTitle(
    BuildContext context, {
    required String title,
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
    final scheduleToday =
        profile.practiceSchedule['Senin - Jumat'] ?? '09:00 - 15:00';
    final filled = _queueFilled;
    final quota = _dailyQuota > 0 ? _dailyQuota : 12;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(scheme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.access_time_rounded,
                  color: scheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Praktik Hari Ini',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$scheduleToday WIB',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Bertugas',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.local_hospital_outlined,
                size: 18,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  profile.hospital,
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Antrean',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                '$filled / $quota pasien',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: filled / quota,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => _showWeeklyScheduleModal(context, profile),
            icon: const Icon(Icons.calendar_today, size: 16),
            label: const Text('Jadwal Mingguan'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration(ColorScheme scheme, {Color? borderColor}) {
    return BoxDecoration(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: borderColor ?? scheme.outlineVariant.withValues(alpha: 0.6),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
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
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        decoration: _cardDecoration(scheme),
        child: Column(
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 44,
              color: Colors.green.shade400,
            ),
            const SizedBox(height: 12),
            const Text(
              'Tidak ada permintaan baru',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return Column(
      children: pendingRequests.map((req) {
        final isHighPriority = req.priority == 'Prioritas Tinggi';
        final isVideo = req.method == 'Video Call';
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: _cardDecoration(
            scheme,
            borderColor: isHighPriority
                ? Colors.red.withValues(alpha: 0.35)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: scheme.primaryContainer.withValues(
                      alpha: 0.6,
                    ),
                    child: Icon(Icons.person, color: scheme.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          req.patientName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${req.age} th • ${req.gender}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isHighPriority)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Prioritas',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  req.complaint,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF263238),
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    isVideo ? Icons.videocam_outlined : Icons.chat_outlined,
                    size: 18,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    req.method,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.access_time,
                    size: 18,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      req.requestedTime,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _rejectRequest(req),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        foregroundColor: scheme.error,
                        side: BorderSide(
                          color: scheme.error.withValues(alpha: 0.5),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Tolak'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _acceptRequest(req),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Terima'),
                    ),
                  ),
                ],
              ),
            ],
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
          final gradientEnd = Color.lerp(scheme.primary, Colors.black, 0.25)!;

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
                      child: Icon(Icons.person, color: Colors.white, size: 18),
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
                      onTap: () => context.pushNamed(
                        AppRoutes.doctorConsultationName,
                        pathParameters: {'sessionId': apt.id},
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
}
