import 'package:flutter/material.dart';

import 'package:Telehealth/core/widgets/app_dialogs.dart';
import 'package:Telehealth/core/widgets/async_state.dart';
import 'package:Telehealth/data/models/doctor.dart';
import 'package:Telehealth/data/models/medication.dart';
import 'package:Telehealth/data/repositories/doctor_repository.dart';
import 'package:Telehealth/data/repositories/medication_repository.dart';

class MedicationReminderPage extends StatefulWidget {
  const MedicationReminderPage({super.key});

  @override
  State<MedicationReminderPage> createState() => _MedicationReminderPageState();
}

class _MedicationReminderPageState extends State<MedicationReminderPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // ── Loaded data ────────────────────────────────────────────────────────────
  List<Medication> _medications = [];
  List<Medication> _historyMedications = [];
  List<Doctor> _doctors = [];

  // ── Async states ───────────────────────────────────────────────────────────
  bool _loading = true;
  String? _error;

  // ── Progress helpers ───────────────────────────────────────────────────────

  int get _totalSchedules =>
      _medications.fold<int>(0, (sum, med) => sum + med.totalSchedules);

  int get _takenSchedules =>
      _medications.fold<int>(0, (sum, med) => sum + med.takenSchedules);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Data loading ───────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<Object>([
        MedicationRepository.instance.fetchAll(),
        MedicationRepository.instance.fetchHistory(),
        DoctorRepository.instance.fetchAll(),
      ]);
      if (!mounted) return;
      setState(() {
        _medications = results[0] as List<Medication>;
        _historyMedications = results[1] as List<Medication>;
        _doctors = results[2] as List<Doctor>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  /// Memuat ulang daftar obat tanpa menampilkan indikator loading penuh,
  /// dipakai setelah aksi toggle/CRUD agar UI tetap sinkron dengan repository.
  Future<void> _refresh() async {
    try {
      final results = await Future.wait<Object>([
        MedicationRepository.instance.fetchAll(),
        MedicationRepository.instance.fetchHistory(),
      ]);
      if (!mounted) return;
      setState(() {
        _medications = results[0] as List<Medication>;
        _historyMedications = results[1] as List<Medication>;
      });
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Gagal memuat ulang data obat', success: false);
      }
    }
  }

  String _doctorName(String doctorId) {
    for (final doc in _doctors) {
      if (doc.id == doctorId) return doc.name;
    }
    return 'Dokter tidak diketahui';
  }

  // ── Create / Update bottom sheet ───────────────────────────────────────────

  Future<void> _openMedicationSheet({Medication? existing}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          _MedicationFormSheet(doctors: _doctors, existing: existing),
    );

    if (saved != true || !mounted) return;
    await _refresh();
    if (!mounted) return;
    showAppSnack(
      context,
      existing == null
          ? 'Obat berhasil ditambahkan'
          : 'Obat berhasil diperbarui',
    );
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  Future<void> _deleteMedication(Medication med) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Hapus Obat',
      message:
          'Yakin ingin menghapus "${med.name}"? Tindakan ini tidak dapat dibatalkan.',
    );
    if (!confirmed || !mounted) return;

    try {
      await MedicationRepository.instance.delete(med.id);
      await _refresh();
      if (!mounted) return;
      showAppSnack(context, 'Obat berhasil dihapus');
    } catch (_) {
      if (!mounted) return;
      showAppSnack(context, 'Gagal menghapus obat. Coba lagi.', success: false);
    }
  }

  // ── Toggle taken ───────────────────────────────────────────────────────────

  Future<void> _toggleTaken(Medication med, int scheduleIndex) async {
    try {
      await MedicationRepository.instance.toggleTaken(med.id, scheduleIndex);
      await _refresh();
    } catch (_) {
      if (!mounted) return;
      showAppSnack(context, 'Gagal memperbarui jadwal obat', success: false);
    }
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Pengingat Obat',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: scheme.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.notifications_active_outlined,
              color: Colors.white,
            ),
            onPressed: () {},
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Hari Ini'),
            Tab(text: 'Minggu Ini'),
            Tab(text: 'Semua'),
            Tab(text: 'Riwayat'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTabContent(_medications),
          _buildTabContent(_medications),
          _buildTabContent(_medications),
          _buildHistoryTabContent(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: (_loading || _error != null)
            ? null
            : () => _openMedicationSheet(),
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        tooltip: 'Tambah Obat',
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  // ── Tab content (loading / error / empty / list) ────────────────────────────

  Widget _buildTabContent(List<Medication> meds) {
    if (_loading) {
      return const LoadingView(message: 'Memuat pengingat obat...');
    }
    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _load);
    }
    if (meds.isEmpty) {
      return EmptyView(
        icon: Icons.medication_outlined,
        title: 'Belum ada pengingat obat',
        message: 'Tambahkan obat beserta jadwal minumnya agar tidak terlewat.',
        actionLabel: 'Tambah Obat',
        onAction: () => _openMedicationSheet(),
      );
    }
    return _buildMedicationList(meds);
  }

  Widget _buildHistoryTabContent() {
    if (_loading) {
      return const LoadingView(message: 'Memuat riwayat obat...');
    }
    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _load);
    }
    if (_historyMedications.isEmpty) {
      return const EmptyView(
        icon: Icons.history_rounded,
        title: 'Belum ada riwayat obat',
        message: 'Obat yang telah dihapus akan masuk ke riwayat di sini.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: _historyMedications
          .map((med) => _buildHistoryCard(med))
          .toList(),
    );
  }

  Widget _buildHistoryCard(Medication med) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
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
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(med.icon, color: scheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        med.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${med.dose} • ${med.frequency}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Dihapus: ${med.deletedAt ?? '-'}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            if (med.schedules.any((s) => s.taken)) ...[
              const SizedBox(height: 12),
              Divider(height: 1, color: Colors.grey.shade200),
              const SizedBox(height: 12),
              Text(
                'JADWAL YANG PERNAH DIMINUM',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: med.schedules.where((s) => s.taken).map((s) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${s.time} (${s.hour})',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Medication list ────────────────────────────────────────────────────────

  Widget _buildMedicationList(List<Medication> meds) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        _buildProgressCard(),
        const SizedBox(height: 16),
        ...meds.asMap().entries.map(
          (entry) => _buildMedicationCard(entry.value, entry.key),
        ),
      ],
    );
  }

  // ── Progress summary card ──────────────────────────────────────────────────

  Widget _buildProgressCard() {
    final scheme = Theme.of(context).colorScheme;
    final total = _totalSchedules;
    final taken = _takenSchedules;
    final double progress = total > 0 ? taken / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.medication_outlined,
                  color: scheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PROGRESS KONSUMSI',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$taken dari $total dosis diminum',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            progress >= 1.0
                ? 'Seluruh dosis hari ini telah selesai.'
                : 'Tersisa ${total - taken} dosis lagi.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ── Single medication card ─────────────────────────────────────────────────

  Widget _buildMedicationCard(Medication med, int medIndex) {
    final scheme = Theme.of(context).colorScheme;
    final schedules = med.schedules;
    final allTaken =
        schedules.isNotEmpty && med.takenSchedules == schedules.length;
    final someTaken = med.takenSchedules > 0;
    final Color medColor = med.color;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card header ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(med.icon, color: scheme.primary, size: 22),
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
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: allTaken
                                  ? const Color(0xFF4CAF50)
                                  : someTaken
                                  ? const Color(0xFFFF9800)
                                  : const Color(0xFF9E9E9E),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              allTaken
                                  ? 'Selesai'
                                  : someTaken
                                  ? 'Sebagian'
                                  : 'Belum',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${med.dose} • ${med.frequency}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.medical_services_outlined,
                            size: 12,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _doctorName(med.doctorId),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Sub-info: date range + note ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 13,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 5),
                Text(
                  '${med.startDate} - ${med.endDate}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.restaurant_outlined,
                  size: 13,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    med.note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: Colors.grey.shade200,
          ),

          // ── Schedule checkboxes ──────────────────────────────────────────
          ...schedules.asMap().entries.map((entry) {
            final schedIndex = entry.key;
            final sched = entry.value;
            final bool isTaken = sched.taken;

            return CheckboxListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              controlAffinity: ListTileControlAffinity.leading,
              value: isTaken,
              activeColor: scheme.primary,
              checkColor: Colors.white,
              onChanged: (_) => _toggleTaken(med, schedIndex),
              title: Row(
                children: [
                  Text(
                    sched.time,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isTaken ? FontWeight.normal : FontWeight.w600,
                      color: isTaken ? Colors.grey.shade500 : Colors.black87,
                      decoration: isTaken ? TextDecoration.lineThrough : null,
                      decorationColor: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isTaken
                          ? const Color(0xFF4CAF50)
                          : scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isTaken)
                          if (isTaken)
                            const Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Icon(
                                Icons.check_circle,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                        Text(
                          sched.hour,
                          style: TextStyle(
                            fontSize: 12,
                            color: isTaken ? Colors.white : scheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 8),

          // ── Action buttons ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openMedicationSheet(existing: med),
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    label: Text(
                      'Edit',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _deleteMedication(med),
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: Color(0xFFFF6B6B),
                    ),
                    label: const Text(
                      'Hapus',
                      style: TextStyle(color: Color(0xFFFF6B6B)),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 8),
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
}

// ── Add / Edit medication form (bottom sheet) ────────────────────────────────

class _MedicationFormSheet extends StatefulWidget {
  const _MedicationFormSheet({required this.doctors, this.existing});

  final List<Doctor> doctors;
  final Medication? existing;

  @override
  State<_MedicationFormSheet> createState() => _MedicationFormSheetState();
}

class _MedicationFormSheetState extends State<_MedicationFormSheet> {
  static const List<String> _frequencies = [
    '1x sehari',
    '2x sehari',
    '3x sehari',
    '4x sehari',
  ];

  late final TextEditingController _nameController;
  late final TextEditingController _doseController;
  late final TextEditingController _noteController;

  late String _frequency;
  String? _doctorId;

  String? _nameError;
  String? _doseError;
  String? _doctorError;

  bool _submitting = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final med = widget.existing;
    _nameController = TextEditingController(text: med?.name ?? '');
    _doseController = TextEditingController(text: med?.dose ?? '');
    _noteController = TextEditingController(
      text: (med != null && med.note != '-') ? med.note : '',
    );
    _frequency = (med != null && _frequencies.contains(med.frequency))
        ? med.frequency
        : _frequencies.first;
    _doctorId =
        med?.doctorId ??
        (widget.doctors.isNotEmpty ? widget.doctors.first.id : null);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _doseController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  List<MedicationSchedule> _defaultSchedules(String frequency) {
    switch (frequency) {
      case '2x sehari':
        return [
          MedicationSchedule(time: 'Pagi', hour: '08:00'),
          MedicationSchedule(time: 'Malam', hour: '20:00'),
        ];
      case '3x sehari':
        return [
          MedicationSchedule(time: 'Pagi', hour: '08:00'),
          MedicationSchedule(time: 'Siang', hour: '14:00'),
          MedicationSchedule(time: 'Malam', hour: '20:00'),
        ];
      case '4x sehari':
        return [
          MedicationSchedule(time: 'Pagi', hour: '08:00'),
          MedicationSchedule(time: 'Siang', hour: '12:00'),
          MedicationSchedule(time: 'Sore', hour: '16:00'),
          MedicationSchedule(time: 'Malam', hour: '20:00'),
        ];
      case '1x sehari':
      default:
        return [MedicationSchedule(time: 'Pagi', hour: '08:00')];
    }
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final dose = _doseController.text.trim();

    setState(() {
      _nameError = name.isEmpty ? 'Nama obat wajib diisi' : null;
      _doseError = dose.isEmpty ? 'Dosis wajib diisi' : null;
      _doctorError = _doctorId == null ? 'Pilih dokter peresep' : null;
    });

    if (_nameError != null || _doseError != null || _doctorError != null) {
      return;
    }

    setState(() => _submitting = true);
    try {
      final note = _noteController.text.trim();
      if (_isEditing) {
        await MedicationRepository.instance.update(
          widget.existing!.copyWith(
            name: name,
            dose: dose,
            frequency: _frequency,
            note: note,
            doctorId: _doctorId,
          ),
        );
      } else {
        await MedicationRepository.instance.create(
          name: name,
          dose: dose,
          frequency: _frequency,
          note: note,
          doctorId: _doctorId!,
          schedules: _defaultSchedules(_frequency),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showAppSnack(context, 'Gagal menyimpan obat. Coba lagi.', success: false);
    }
  }

  InputDecoration _decoration({
    required String label,
    required IconData icon,
    String? hint,
    String? errorText,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade700),
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400),
      errorText: errorText,
      prefixIcon: Icon(icon, color: Colors.grey.shade600),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 8,
        left: 20,
        right: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sheet handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _isEditing ? Icons.edit_outlined : Icons.add_circle_outline,
                    color: scheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _isEditing ? 'Edit Obat' : 'Tambah Obat Baru',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.grey.shade700),
                  onPressed: _submitting ? null : () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Nama Obat
            TextField(
              controller: _nameController,
              enabled: !_submitting,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(color: Colors.black87),
              decoration: _decoration(
                label: 'Nama Obat',
                hint: 'Contoh: Paracetamol',
                icon: Icons.medication_rounded,
                errorText: _nameError,
              ),
            ),
            const SizedBox(height: 14),

            // Dosis
            TextField(
              controller: _doseController,
              enabled: !_submitting,
              style: const TextStyle(color: Colors.black87),
              decoration: _decoration(
                label: 'Dosis',
                hint: 'Contoh: 500 mg',
                icon: Icons.straighten_rounded,
                errorText: _doseError,
              ),
            ),
            const SizedBox(height: 14),

            // Frekuensi dropdown
            DropdownButtonFormField<String>(
              value: _frequency,
              style: const TextStyle(color: Colors.black87),
              decoration: _decoration(
                label: 'Frekuensi',
                icon: Icons.repeat_rounded,
              ),
              dropdownColor: Colors.white,
              items: _frequencies
                  .map(
                    (f) => DropdownMenuItem(
                      value: f,
                      child: Text(
                        f,
                        style: const TextStyle(color: Colors.black87),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _submitting
                  ? null
                  : (val) {
                      if (val != null) {
                        setState(() => _frequency = val);
                      }
                    },
            ),
            const SizedBox(height: 14),

            // Dokter peresep dropdown (relasi doctorId)
            DropdownButtonFormField<String>(
              value: _doctorId,
              isExpanded: true,
              style: const TextStyle(color: Colors.black87),
              decoration: _decoration(
                label: 'Dokter Peresep',
                icon: Icons.medical_services_outlined,
                errorText: _doctorError,
              ),
              dropdownColor: Colors.white,
              items: widget.doctors
                  .map(
                    (doc) => DropdownMenuItem(
                      value: doc.id,
                      child: Text(
                        doc.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.black87),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _submitting
                  ? null
                  : (val) => setState(() => _doctorId = val),
            ),
            const SizedBox(height: 14),

            // Catatan (opsional)
            TextField(
              controller: _noteController,
              enabled: !_submitting,
              style: const TextStyle(color: Colors.black87),
              decoration: _decoration(
                label: 'Catatan (opsional)',
                hint: 'Contoh: Sesudah makan',
                icon: Icons.notes_rounded,
              ),
            ),
            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(
                  _submitting
                      ? 'Menyimpan...'
                      : (_isEditing ? 'Perbarui Obat' : 'Simpan Obat'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
