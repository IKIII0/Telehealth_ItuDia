import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:Telehealth/core/routing/app_routes.dart';
import 'package:Telehealth/core/widgets/app_dialogs.dart';
import 'package:Telehealth/core/widgets/async_state.dart';
import 'package:Telehealth/core/widgets/notification_bell.dart';
import 'package:Telehealth/core/widgets/patient_nav_bar.dart';
import 'package:Telehealth/core/widgets/role_badge.dart';
import 'package:Telehealth/data/models/doctor.dart';
import 'package:Telehealth/data/models/conversation.dart';
import 'package:Telehealth/data/models/journal.dart';
import 'package:Telehealth/data/models/medication.dart';
import 'package:Telehealth/data/repositories/auth_repository.dart';
import 'package:Telehealth/data/repositories/conversation_repository.dart';
import 'package:Telehealth/data/repositories/doctor_repository.dart';
import 'package:Telehealth/data/repositories/journal_repository.dart';
import 'package:Telehealth/data/repositories/medication_repository.dart';

/// Helper model untuk mengurutkan jadwal konsumsi obat terdekat.
class _UpcomingScheduleItem {
  const _UpcomingScheduleItem({
    required this.medication,
    required this.schedule,
    required this.scheduleIndex,
  });

  final Medication medication;
  final MedicationSchedule schedule;
  final int scheduleIndex;
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, this.showNavBar = false});

  final bool showNavBar;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // ── Async state ─────────────────────────────────────────────────────────────
  bool _loading = true;
  String? _error;
  List<Doctor> _recommended = const [];
  List<Conversation> _activeConsultations = const [];
  List<JournalEntry> _journalEntries = const [];
  List<JournalCategory> _journalCategories = const [];
  List<Medication> _medications = const [];

  /// Kategori grafik rekam medis yang sedang dipilih ('cat1', 'cat2', atau 'cat3')
  String _selectedChartCategoryId = 'cat1';

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        DoctorRepository.instance.fetchAll(),
        JournalRepository.instance.fetchEntries(),
        JournalRepository.instance.fetchCategories(),
        MedicationRepository.instance.fetchAll(),
        ConversationRepository.instance.fetchAll(),
      ]);
      if (!mounted) return;
      final doctors = List<Doctor>.of(results[0] as List<Doctor>)
        ..sort((a, b) => b.rating.compareTo(a.rating));
      final consultations = (results[4] as List<Conversation>)
          .where((c) => c.type == 'dokter')
          .take(3)
          .toList();
      setState(() {
        _recommended = doctors.take(3).toList();
        _journalEntries = results[1] as List<JournalEntry>;
        _journalCategories = results[2] as List<JournalCategory>;
        _medications = results[3] as List<Medication>;
        _activeConsultations = consultations;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _go(String routeName) => context.pushNamed(routeName);

  Future<void> _toggleMedication(Medication med, int scheduleIndex) async {
    try {
      await MedicationRepository.instance.toggleTaken(med.id, scheduleIndex);
      final updatedMeds = await MedicationRepository.instance.fetchAll();
      if (!mounted) return;
      setState(() {
        _medications = updatedMeds;
      });
      showAppSnack(context, 'Status konsumsi ${med.name} berhasil diperbarui');
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Gagal memperbarui status obat', success: false);
      }
    }
  }

  // ── Helpers data rekam medis ────────────────────────────────────────────────
  JournalEntry? _latestEntry(String categoryId) {
    final matches = _journalEntries
        .where((e) => e.categoryId == categoryId)
        .toList();
    if (matches.isEmpty) return null;
    matches.sort((a, b) => b.date.compareTo(a.date));
    return matches.first;
  }

  List<JournalEntry> _chartEntries(String categoryId) {
    final list =
        _journalEntries.where((e) => e.categoryId == categoryId).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    if (list.length > 7) {
      return list.sublist(list.length - 7);
    }
    return list;
  }

  // ── Helpers data pengingat obat ─────────────────────────────────────────────
  List<_UpcomingScheduleItem> _getUpcomingSchedules() {
    final List<_UpcomingScheduleItem> items = [];
    for (final med in _medications) {
      for (var i = 0; i < med.schedules.length; i++) {
        items.add(
          _UpcomingScheduleItem(
            medication: med,
            schedule: med.schedules[i],
            scheduleIndex: i,
          ),
        );
      }
    }

    // Prioritaskan yang belum diminum, lalu urutkan berdasarkan jam
    items.sort((a, b) {
      if (a.schedule.taken != b.schedule.taken) {
        return a.schedule.taken ? 1 : -1;
      }
      return a.schedule.hour.compareTo(b.schedule.hour);
    });

    return items;
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final userName = AuthRepository.instance.currentUser?.name ?? 'RiFaEl';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Selamat Datang,',
              style: TextStyle(fontSize: 13, color: Colors.white70),
            ),
            Text(
              userName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          NotificationBell(
            onTap: () => _go(AppRoutes.patientNotificationsName),
          ),
          const RoleBadge.patient(size: 26),
        ],
      ),
      bottomNavigationBar: widget.showNavBar
          ? const PatientNavBar(currentIndex: 0)
          : null,
      body: Stack(
        children: [
          // Latar ilustrasi medis, dibuat samar agar konten tetap terbaca.
          Positioned.fill(
            child: IgnorePointer(
              child: Image.asset(
                'assets/icons/BG.jpg',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                opacity: const AlwaysStoppedAnimation<double>(0.2),
              ),
            ),
          ),
          RefreshIndicator(
            onRefresh: _loadDashboardData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSearchBar(),
                  _buildQuickActions(scheme),
                  // ── 1. Ringkasan Jurnal Kesehatan & Grafik Rekam Medis ──
                  _buildJournalSection(scheme),
                  // ── 2. Ringkasan Pengingat Obat & Jadwal Terdekat ──────
                  _buildMedicationSection(scheme),
                  // ── 3. Konsultasi Aktif ──────────────────────────────
                  _buildSectionHeader(
                    'Konsultasi Aktif',
                    onSeeAll: () => _go(AppRoutes.patientChatName),
                  ),
                  _buildScheduleList(scheme),
                  // ── 4. Dokter Rekomendasi ─────────────────────────────
                  _buildSectionHeader(
                    'Dokter Rekomendasi',
                    onSeeAll: () => _go(AppRoutes.patientDoctorsName),
                  ),
                  _buildRecommendations(scheme),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Search bar ──────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
        ),
        child: TextField(
          readOnly: true,
          onTap: () => _go(AppRoutes.patientDoctorsName),
          decoration: const InputDecoration(
            hintText: 'Cari dokter...',
            prefixIcon: Icon(Icons.search, color: Colors.grey),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  // ── Aksi cepat: Cek Gejala & Chat dengan Dokter ──────────────────────────────
  Widget _buildQuickActions(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: _QuickActionCard(
              cardKey: const Key('symptom_checker_button'),
              iconAsset: 'assets/icons/Cek Gejala.png',
              title: 'Cek Gejala',
              subtitle: 'Periksa gejala',
              color: scheme.primary,
              onTap: () => _go(AppRoutes.patientSymptomCheckerName),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickActionCard(
              cardKey: const Key('chat_doctor_button'),
              iconAsset: 'assets/icons/Chat.png',
              title: 'Chat Dokter',
              subtitle: 'Tanya dokter',
              color: const Color(0xFF00897B),
              onTap: () => _go(AppRoutes.patientDoctorsName),
            ),
          ),
        ],
      ),
    );
  }

  // ── 1. Jurnal Kesehatan & Grafik Rekam Medis ────────────────────────────────
  Widget _buildJournalSection(ColorScheme scheme) {
    final latestBp = _latestEntry('cat1');
    final latestBs = _latestEntry('cat2');
    final latestWeight = _latestEntry('cat3');

    final bpValue = latestBp != null
        ? '${latestBp.systolic ?? latestBp.value.toInt()}/${latestBp.diastolic ?? 80}'
        : '120/80';
    final bsValue = latestBs != null ? latestBs.value.toInt().toString() : '95';
    final weightValue = latestWeight != null
        ? latestWeight.value.toStringAsFixed(1)
        : '65.4';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 8, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59F00).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Image.asset(
                        'assets/icons/Jurnal Kesehatan.png',
                        width: 18,
                        height: 18,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                    const SizedBox(width: 9),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Jurnal Kesehatan',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Grafik rekam medis & kondisi fisik',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                key: const Key('journal_detail_arrow_button'),
                onPressed: () => _go(AppRoutes.patientJournalName),
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Lihat',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: scheme.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 4 Vitals row
                  Row(
                    children: [
                      _buildVitalMetric(
                        label: 'Tensi',
                        value: bpValue,
                        unit: 'mmHg',
                        assetPath: 'assets/icons/Tensi.png',
                        color: const Color(0xFFE05252),
                      ),
                      _buildVitalMetric(
                        label: 'Gula Darah',
                        value: bsValue,
                        unit: 'mg/dL',
                        assetPath: 'assets/icons/Gula Darah.png',
                        color: const Color(0xFFD98E04),
                      ),
                      _buildVitalMetric(
                        label: 'Detak',
                        value: '75',
                        unit: 'bpm',
                        assetPath: 'assets/icons/Detak.png',
                        color: const Color(0xFFD6336C),
                      ),
                      _buildVitalMetric(
                        label: 'Berat',
                        value: weightValue,
                        unit: 'kg',
                        assetPath: 'assets/icons/Berat Badan.png',
                        color: const Color(0xFF4C6EF5),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  // Pemilih kategori grafik
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildChartCategoryTab('cat1', 'Tekanan Darah', scheme),
                        _buildChartCategoryTab('cat2', 'Gula Darah', scheme),
                        _buildChartCategoryTab('cat3', 'Berat Badan', scheme),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Chart display
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F9FC),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _buildMedicalRecordChart(scheme),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVitalMetric({
    required String label,
    required String value,
    required String unit,
    required String assetPath,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Image.asset(assetPath, filterQuality: FilterQuality.high),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              height: 1.1,
            ),
          ),
          Text(
            unit,
            style: TextStyle(fontSize: 9.5, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildChartCategoryTab(
    String categoryId,
    String label,
    ColorScheme scheme,
  ) {
    final isSelected = _selectedChartCategoryId == categoryId;
    return InkWell(
      onTap: () => setState(() => _selectedChartCategoryId = categoryId),
      child: Padding(
        padding: const EdgeInsets.only(right: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? scheme.primary : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 2,
              width: isSelected ? 22 : 0,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicalRecordChart(ColorScheme scheme) {
    final entries = _chartEntries(_selectedChartCategoryId);

    if (entries.isEmpty) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        child: Text(
          'Belum ada rekaman medis untuk kategori ini',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
      );
    }

    if (_selectedChartCategoryId == 'cat1') {
      const sysColor = Color(0xFFE05252);
      const diaColor = Color(0xFF7A9BE8);
      // Grafik Tekanan Darah (Sistolik & Diastolik)
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _chartLegendDot(sysColor, 'Sistolik'),
              const SizedBox(width: 14),
              _chartLegendDot(diaColor, 'Diastolik'),
              const Spacer(),
              Text(
                '7 pengukuran terakhir',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: entries.map((e) {
                final sys = (e.systolic ?? e.value.toInt()).toDouble();
                final dia = (e.diastolic ?? 80).toDouble();
                const maxV = 160.0;
                final sysH = (sys / maxV).clamp(0.1, 1.0) * 88.0;
                final diaH = (dia / maxV).clamp(0.1, 1.0) * 88.0;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${sys.toInt()}',
                          style: const TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w600,
                            color: sysColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 7,
                              height: sysH,
                              decoration: BoxDecoration(
                                color: sysColor,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(3),
                                ),
                              ),
                            ),
                            const SizedBox(width: 2),
                            Container(
                              width: 7,
                              height: diaH,
                              decoration: BoxDecoration(
                                color: diaColor,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(3),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${e.date.day}/${e.date.month}',
                          style: TextStyle(
                            fontSize: 8.5,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      );
    } else {
      // Grafik Nilai Tunggal (Gula Darah / Berat Badan)
      final isSugar = _selectedChartCategoryId == 'cat2';
      final chartColor = isSugar
          ? const Color(0xFFD98E04)
          : const Color(0xFF4C6EF5);
      final unitLabel = isSugar ? 'mg/dL' : 'kg';
      final vals = entries.map((e) => e.value).toList();
      final maxV = vals.reduce((a, b) => a > b ? a : b);
      final minV = vals.reduce((a, b) => a < b ? a : b);
      final range = (maxV - minV) > 0 ? (maxV - minV) : 10.0;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _chartLegendDot(
                chartColor,
                isSugar
                    ? 'Gula Darah ($unitLabel)'
                    : 'Berat Badan ($unitLabel)',
              ),
              const Spacer(),
              Text(
                '7 pengukuran terakhir',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: entries.map((e) {
                final ratio = ((e.value - minV + 5) / (range + 10)).clamp(
                  0.15,
                  1.0,
                );
                final barH = ratio * 88.0;
                final displayVal = isSugar
                    ? e.value.toInt().toString()
                    : e.value.toStringAsFixed(1);

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          displayVal,
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w600,
                            color: chartColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          width: 12,
                          height: barH,
                          decoration: BoxDecoration(
                            color: chartColor,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${e.date.day}/${e.date.month}',
                          style: TextStyle(
                            fontSize: 8.5,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      );
    }
  }

  Widget _chartLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  // Pengingat Obat & Jadwal Konsumsi Terdekat
  Widget _buildMedicationSection(ColorScheme scheme) {
    final upcoming = _getUpcomingSchedules();
    final totalSchedules = _medications.fold<int>(
      0,
      (sum, m) => sum + m.totalSchedules,
    );
    final takenSchedules = _medications.fold<int>(
      0,
      (sum, m) => sum + m.takenSchedules,
    );
    final progress = totalSchedules > 0 ? takenSchedules / totalSchedules : 0.0;

    // Ambil maksimal 2 jadwal obat terdekat
    final nearestItems = upcoming.take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 8, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7E57C2).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Image.asset(
                        'assets/icons/Pengingat Obat.png',
                        width: 18,
                        height: 18,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                    const SizedBox(width: 9),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pengingat Obat',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Jadwal konsumsi terdekat & kepatuhan',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                key: const Key('medication_detail_arrow_button'),
                onPressed: () => _go(AppRoutes.patientMedicationName),
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Lihat',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: scheme.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress Kepatuhan Hari Ini
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Kepatuhan Hari Ini',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '$takenSchedules dari $totalSchedules jadwal selesai',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 7,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progress == 1.0 ? Colors.green : scheme.primary,
                      ),
                    ),
                  ),
                  const Divider(height: 24),
                  // List jadwal terdekat
                  if (nearestItems.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      alignment: Alignment.center,
                      child: Text(
                        'Tidak ada jadwal obat aktif hari ini.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    )
                  else ...[
                    Text(
                      'Jadwal Konsumsi Terdekat',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...nearestItems.map((item) {
                      final med = item.medication;
                      final sched = item.schedule;
                      final isTaken = sched.taken;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isTaken
                              ? Colors.green.withValues(alpha: 0.05)
                              : med.color.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isTaken
                                ? Colors.green.withValues(alpha: 0.25)
                                : med.color.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isTaken
                                    ? Colors.green.withValues(alpha: 0.15)
                                    : med.color.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isTaken ? Icons.check_circle : med.icon,
                                color: isTaken ? Colors.green : med.color,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          med.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isTaken
                                              ? Colors.green
                                              : Colors.orange.shade800,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          isTaken
                                              ? 'Sudah Diminum'
                                              : 'Jadwal Terdekat',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${med.dose} • ${sched.hour} (${sched.time}) • ${med.note}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () =>
                                  _toggleMedication(med, item.scheduleIndex),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isTaken
                                      ? Colors.grey.shade200
                                      : scheme.primary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isTaken ? 'Batal' : 'Minum',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isTaken
                                        ? Colors.grey.shade700
                                        : Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── 3. Active consultations ────────────────────────────────────────────────
  Widget _buildScheduleList(ColorScheme scheme) {
    if (_loading) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      );
    }

    if (_activeConsultations.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.forum_outlined, size: 18, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Belum ada konsultasi aktif. Mulai chat dengan dokter.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 132,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _activeConsultations.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final conversation = _activeConsultations[i];
          final color = conversation.color;

          return SizedBox(
            width: 236,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => context.pushNamed(
                  AppRoutes.patientChatRoomName,
                  pathParameters: {'conversationId': conversation.id},
                ),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 17,
                                backgroundColor: color.withValues(alpha: 0.12),
                                child: Text(
                                  conversation.initials,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: color,
                                  ),
                                ),
                              ),
                              if (conversation.isOnline)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 9,
                                    height: 9,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2E7D32),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  conversation.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  conversation.isOnline
                                      ? 'Online'
                                      : 'Terakhir ${conversation.time}',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: conversation.isOnline
                                        ? const Color(0xFF2E7D32)
                                        : Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: Text(
                          conversation.lastMessage,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.4,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            'Lanjutkan chat',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 13,
                            color: color,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── 4. Recommended doctors ──────────────────────────────────────────────────
  Widget _buildRecommendations(ColorScheme scheme) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: LoadingView(message: 'Memuat dokter rekomendasi...'),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: ErrorView(message: _error!, onRetry: _loadDashboardData),
      );
    }
    if (_recommended.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: EmptyView(
          icon: Icons.medical_services_outlined,
          title: 'Belum Ada Dokter',
          message: 'Daftar dokter rekomendasi masih kosong.',
          actionLabel: 'Muat Ulang',
          onAction: _loadDashboardData,
        ),
      );
    }
    return _buildDoctorList(scheme);
  }

  Widget _buildDoctorList(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Column(
          children: _recommended.asMap().entries.map((entry) {
            final i = entry.key;
            final doc = entry.value;
            return Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: scheme.primaryContainer,
                    child: Text(
                      doc.initials,
                      style: TextStyle(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    doc.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.specialization,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 14),
                          const SizedBox(width: 2),
                          Text(
                            '${doc.rating}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '• ${doc.experience} thn',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: ElevatedButton(
                    onPressed: () => context.pushNamed(
                      AppRoutes.patientDoctorDetailName,
                      pathParameters: {'doctorId': doc.id},
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Konsultasi',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ),
                if (i < _recommended.length - 1)
                  const Divider(height: 1, indent: 72),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  Widget _buildSectionHeader(String title, {required VoidCallback onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: onSeeAll,
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Lihat semua',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu aksi cepat pada dashboard (Cek Gejala / Chat Dokter).
class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.cardKey,
    required this.iconAsset,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final Key cardKey;
  final String iconAsset;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: cardKey,
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Image.asset(
                  iconAsset,
                  width: 22,
                  height: 22,
                  filterQuality: FilterQuality.high,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
