import 'package:flutter/material.dart';

import 'package:Telehealth/core/widgets/app_dialogs.dart';
import 'package:Telehealth/data/models/consultation_session.dart';
import 'package:Telehealth/data/repositories/consultation_repository.dart';
import '../widgets/consultation_history_tab.dart';
import '../widgets/doctor_notes_tab.dart';
import '../widgets/medical_records_tab.dart';
import '../widgets/medication_history_tab.dart';

/// Halaman utama sesi konsultasi dokter–pasien.
///
/// Dibuka dokter saat menekan "Mulai Sesi" atau "Detail" pada jadwal terkonfirmasi.
/// Menyajikan 4 tab:
///   1. Riwayat Medis       – vital signs & grafik tren
///   2. Riwayat Obat        – obat aktif & historis pasien
///   3. Riwayat Konsultasi  – kunjungan ke dokter lain
///   4. Catatan Dokter      – diagnosis, catatan & resep
class ConsultationSessionPage extends StatefulWidget {
  const ConsultationSessionPage({super.key, required this.sessionId});

  final String sessionId;

  @override
  State<ConsultationSessionPage> createState() =>
      _ConsultationSessionPageState();
}

class _ConsultationSessionPageState extends State<ConsultationSessionPage>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  ConsultationSession? _session;
  bool _loading = true;
  String? _error;

  /// Durasi sesi (diperbarui setiap detik bila status ongoing).
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadSession();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSession() async {
    try {
      final session = await ConsultationRepository.instance
          .getSession(widget.sessionId);
      if (!mounted) return;
      if (session == null) {
        setState(() {
          _error = 'Sesi konsultasi tidak ditemukan.';
          _loading = false;
        });
        return;
      }
      setState(() {
        _session = session;
        _loading = false;
        if (session.status == ConsultationStatus.ongoing) {
          _elapsed = DateTime.now().difference(session.startedAt);
        }
      });
      if (session.status == ConsultationStatus.ongoing) {
        _startTimer();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat sesi: $e';
        _loading = false;
      });
    }
  }

  void _startTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      final s = _session;
      if (s == null || s.status != ConsultationStatus.ongoing) return false;
      setState(() {
        _elapsed = DateTime.now().difference(s.startedAt);
      });
      return true;
    });
  }

  String get _elapsedLabel {
    final m = _elapsed.inMinutes;
    final s = _elapsed.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ── Selesaikan sesi ────────────────────────────────────────────────────────
  Future<void> _endSession() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Akhiri Sesi Konsultasi',
      message:
          'Pastikan catatan diagnosis dan resep sudah disimpan sebelum mengakhiri sesi.',
      confirmLabel: 'Akhiri Sesi',
      destructive: false,
    );
    if (!confirmed || !mounted) return;

    final s = _session!;
    final updated = await ConsultationRepository.instance.saveSessionNotes(
      sessionId: s.sessionId,
      diagnosisSummary: s.diagnosisSummary,
      doctorNotes: s.doctorNotes,
      prescribedMedications: s.prescribedMedications,
      complete: true,
    );

    if (!mounted) return;
    setState(() => _session = updated);
    showAppSnack(context, 'Sesi konsultasi selesai. Rekam tersimpan.');
    Navigator.of(context).pop();
  }

  // ── Callback dari DoctorNotesTab ───────────────────────────────────────────
  Future<void> _onNotesSaved({
    required String diagnosis,
    required String notes,
    required List<String> medications,
  }) async {
    final updated = await ConsultationRepository.instance.saveSessionNotes(
      sessionId: widget.sessionId,
      diagnosisSummary: diagnosis,
      doctorNotes: notes,
      prescribedMedications: medications,
    );
    if (!mounted) return;
    setState(() => _session = updated);
    showAppSnack(context, 'Catatan konsultasi berhasil disimpan');
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Memuat Sesi...'),
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
          backgroundColor: scheme.error,
          foregroundColor: scheme.onError,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 64, color: scheme.error),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Kembali'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final session = _session!;
    final isOngoing = session.status == ConsultationStatus.ongoing;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: _buildAppBar(scheme, session, isOngoing),
      body: Column(
        children: [
          // ── Banner Info Pasien ──
          _buildPatientBanner(scheme, session, isOngoing),
          // ── TabBar ──
          _buildTabBar(scheme),
          // ── TabBarView ──
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                MedicalRecordsTab(patientId: session.patientId),
                MedicationHistoryTab(patientId: session.patientId),
                ConsultationHistoryTab(patientId: session.patientId),
                DoctorNotesTab(
                  session: session,
                  onSaved: _onNotesSaved,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isOngoing ? _buildBottomBar(scheme) : null,
    );
  }

  AppBar _buildAppBar(
    ColorScheme scheme,
    ConsultationSession session,
    bool isOngoing,
  ) {
    return AppBar(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sesi Konsultasi',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(
            session.scheduledTime,
            style: const TextStyle(fontSize: 11, color: Colors.white70),
          ),
        ],
      ),
      actions: [
        if (isOngoing)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer, size: 14, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  _elapsedLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPatientBanner(
    ColorScheme scheme,
    ConsultationSession session,
    bool isOngoing,
  ) {
    final statusColor = session.status.color;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        border: Border(
          bottom: BorderSide(color: scheme.primary.withValues(alpha: 0.15)),
        ),
      ),
      child: Row(
        children: [
          // Avatar pasien
          CircleAvatar(
            radius: 26,
            backgroundColor: scheme.primaryContainer,
            child: Text(
              _initials(session.patientName),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.patientName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${session.patientAge} th • ${session.patientGender} • '
                  'Gol. Darah ${session.patientBloodType}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 4),
                // Alergi
                if (session.patientAllergies.isNotEmpty)
                  Wrap(
                    spacing: 4,
                    children: session.patientAllergies.map((a) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          '⚠ Alergi: $a',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          // Status badge
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isOngoing)
                      Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.only(right: 5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusColor,
                        ),
                      ),
                    Text(
                      session.status.label,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                session.consultationType,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(ColorScheme scheme) {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        indicatorColor: scheme.primary,
        labelColor: scheme.primary,
        unselectedLabelColor: Colors.grey.shade600,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        tabs: const [
          Tab(
            icon: Icon(Icons.monitor_heart_outlined, size: 18),
            text: 'Riwayat Medis',
          ),
          Tab(
            icon: Icon(Icons.medication_outlined, size: 18),
            text: 'Riwayat Obat',
          ),
          Tab(
            icon: Icon(Icons.history_edu_outlined, size: 18),
            text: 'Kunjungan',
          ),
          Tab(
            icon: Icon(Icons.edit_note_rounded, size: 18),
            text: 'Catatan Dokter',
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                _tabController.animateTo(3);
              },
              icon: const Icon(Icons.edit_note_rounded, size: 18),
              label: const Text('Tambah Catatan'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: _endSession,
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Selesai Sesi'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final cleaned = name
        .replaceAll('Ny.', '')
        .replaceAll('Tn.', '')
        .replaceAll('Sdr.', '')
        .trim();
    final parts = cleaned.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}
