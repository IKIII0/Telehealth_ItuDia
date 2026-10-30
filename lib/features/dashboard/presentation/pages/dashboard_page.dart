import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:Telehealth/core/routing/app_routes.dart';
import 'package:Telehealth/core/widgets/app_dialogs.dart';
import 'package:Telehealth/core/widgets/async_state.dart';
import 'package:Telehealth/core/widgets/patient_nav_bar.dart';
import 'package:Telehealth/data/models/appointment.dart';
import 'package:Telehealth/data/models/doctor.dart';
import 'package:Telehealth/data/models/journal.dart';
import 'package:Telehealth/data/models/medication.dart';
import 'package:Telehealth/data/repositories/auth_repository.dart';
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
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // ── Jadwal konsultasi contoh (data lokal) ───────────────────────────────────
  static const List<Appointment> _appointments = [
    Appointment(
      id: 'apt1',
      doctorId: 'doc1',
      doctorName: 'Dr. Rifki Al Sauqy, Sp.JP',
      specialization: 'Spesialis Jantung',
      date: '28 Sep 2026',
      time: '09:00',
    ),
    Appointment(
      id: 'apt2',
      doctorId: 'doc2',
      doctorName: 'Dr. Yehezkiel Sitanggang, Sp.A',
      specialization: 'Spesialis Anak',
      date: '30 Sep 2026',
      time: '14:30',
    ),
    Appointment(
      id: 'apt3',
      doctorId: 'doc5',
      doctorName: 'Dr. Farhan Prasetyo, Sp.PD',
      specialization: 'Spesialis Penyakit Dalam',
      date: '02 Okt 2026',
      time: '11:00',
    ),
  ];

  // ── Async state ─────────────────────────────────────────────────────────────
  bool _loading = true;
  String? _error;
  List<Doctor> _recommended = const [];
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
      ]);
      if (!mounted) return;
      setState(() {
        _recommended = (results[0] as List<Doctor>).take(3).toList();
        _journalEntries = results[1] as List<JournalEntry>;
        _journalCategories = results[2] as List<JournalCategory>;
        _medications = results[3] as List<Medication>;
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
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, size: 28),
                onPressed: () =>
                    showAppSnack(context, 'Tidak ada notifikasi baru'),
              ),
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: scheme.error,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => _go(AppRoutes.patientProfileName),
              child: const CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white24,
                child: Icon(Icons.person, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const PatientNavBar(currentIndex: 0),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSearchBar(),
              // ── 1. Ringkasan Jurnal Kesehatan & Grafik Rekam Medis ──────
              _buildJournalSection(scheme),
              // ── 2. Ringkasan Pengingat Obat & Jadwal Terdekat ──────────
              _buildMedicationSection(scheme),
              // ── 3. Jadwal Konsultasi Dokter Mendatang ──────────────────
              _buildSectionHeader(
                'Jadwal Konsultasi Mendatang',
                onSeeAll: () => _go(AppRoutes.patientDoctorsName),
              ),
              _buildScheduleList(scheme),
              // ── 4. Dokter Rekomendasi ───────────────────────────────────
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
            hintText: 'Cari dokter, spesialisasi, atau obat...',
            prefixIcon: Icon(Icons.search, color: Colors.grey),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 14),
          ),
        ),
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.show_chart_rounded,
                  color: Colors.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jurnal Kesehatan',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Grafik rekam medis & kondisi fisik',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              InkWell(
                key: const Key('journal_detail_arrow_button'),
                onTap: () => _go(AppRoutes.patientJournalName),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Detail',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: scheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
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
                        icon: Icons.favorite,
                        color: Colors.red,
                      ),
                      _buildVitalMetric(
                        label: 'Gula Darah',
                        value: bsValue,
                        unit: 'mg/dL',
                        icon: Icons.water_drop_outlined,
                        color: Colors.green,
                      ),
                      _buildVitalMetric(
                        label: 'Detak',
                        value: '75',
                        unit: 'bpm',
                        icon: Icons.monitor_heart,
                        color: Colors.pink,
                      ),
                      _buildVitalMetric(
                        label: 'Berat',
                        value: weightValue,
                        unit: 'kg',
                        icon: Icons.scale,
                        color: Colors.blue,
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  // Category selector pills for chart
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildChartCategoryChip(
                          'cat1',
                          'Tekanan Darah',
                          scheme,
                        ),
                        const SizedBox(width: 8),
                        _buildChartCategoryChip('cat2', 'Gula Darah', scheme),
                        const SizedBox(width: 8),
                        _buildChartCategoryChip('cat3', 'Berat Badan', scheme),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Chart display
                  _buildMedicalRecordChart(scheme),
                  const SizedBox(height: 12),
                  // Bottom hint & arrow to detail
                  InkWell(
                    onTap: () => _go(AppRoutes.patientJournalName),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withValues(
                          alpha: 0.35,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 16,
                            color: Colors.green.shade700,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Data rekam medis normal & tercatat rapi',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: scheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
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
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          Text(
            unit,
            style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildChartCategoryChip(
    String categoryId,
    String label,
    ColorScheme scheme,
  ) {
    final isSelected = _selectedChartCategoryId == categoryId;
    return InkWell(
      onTap: () => setState(() => _selectedChartCategoryId = categoryId),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? scheme.primary
              : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : Colors.grey.shade800,
          ),
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
      // Grafik Tekanan Darah (Sistolik & Diastolik)
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _chartLegendDot(Colors.red.shade400, 'Sistolik'),
              const SizedBox(width: 14),
              _chartLegendDot(Colors.blue.shade400, 'Diastolik'),
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
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 8,
                              height: sysH,
                              decoration: BoxDecoration(
                                color: Colors.red.shade400,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(3),
                                ),
                              ),
                            ),
                            const SizedBox(width: 2),
                            Container(
                              width: 8,
                              height: diaH,
                              decoration: BoxDecoration(
                                color: Colors.blue.shade400,
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
                          style: const TextStyle(fontSize: 8),
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
      final chartColor = isSugar ? Colors.green.shade600 : Colors.blue.shade600;
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
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: chartColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          width: 14,
                          height: barH,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                chartColor,
                                chartColor.withValues(alpha: 0.5),
                              ],
                            ),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${e.date.day}/${e.date.month}',
                          style: const TextStyle(fontSize: 8),
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

  // ── 2. Pengingat Obat & Jadwal Konsumsi Terdekat ────────────────────────────
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.alarm_rounded,
                  color: Colors.purple,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pengingat Obat',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Jadwal konsumsi terdekat & kepatuhan',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              InkWell(
                key: const Key('medication_detail_arrow_button'),
                onTap: () => _go(AppRoutes.patientMedicationName),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Detail',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: scheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
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
                  const SizedBox(height: 4),
                  // Bottom link to medication page
                  InkWell(
                    onTap: () => _go(AppRoutes.patientMedicationName),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withValues(
                          alpha: 0.35,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.medication_outlined,
                            size: 16,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Kelola semua resep & riwayat pengingat obat',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: scheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── 3. Schedule list ────────────────────────────────────────────────────────
  Widget _buildScheduleList(ColorScheme scheme) {
    final gradientEnd = Color.lerp(scheme.primary, Colors.white, 0.35)!;
    return SizedBox(
      height: 140,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _appointments.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final appointment = _appointments[i];
          return Container(
            width: 240,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [scheme.primary, gradientEnd]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.3),
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
                      radius: 18,
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.person, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        appointment.doctorName,
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
                Text(
                  appointment.specialization,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const Spacer(),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      color: Colors.white70,
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        appointment.date,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.access_time,
                      color: Colors.white70,
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      appointment.time,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
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
                    onPressed: () => _go(AppRoutes.patientDoctorsName),
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
                      'Buat Janji',
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
            child: const Text('Lihat Semua', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
