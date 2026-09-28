import 'package:flutter/material.dart';

class MedicationReminderPage extends StatefulWidget {
  const MedicationReminderPage({super.key});

  @override
  State<MedicationReminderPage> createState() =>
      _MedicationReminderPageState();
}

class _MedicationReminderPageState extends State<MedicationReminderPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // ── Dummy medication data ──────────────────────────────────────────────────
  final List<Map<String, dynamic>> _medications = [
    {
      'name': 'Paracetamol',
      'dose': '500 mg',
      'frequency': '3x sehari',
      'startDate': '20 Sep 2024',
      'endDate': '27 Sep 2024',
      'note': 'Sesudah makan',
      'color': const Color(0xFF1E88E5),
      'icon': Icons.medication_rounded,
      'schedules': <Map<String, dynamic>>[
        {'time': 'Pagi', 'hour': '08:00', 'taken': true},
        {'time': 'Siang', 'hour': '14:00', 'taken': true},
        {'time': 'Malam', 'hour': '20:00', 'taken': false},
      ],
    },
    {
      'name': 'Amoxicillin',
      'dose': '500 mg',
      'frequency': '3x sehari',
      'startDate': '22 Sep 2024',
      'endDate': '29 Sep 2024',
      'note': 'Sebelum makan',
      'color': const Color(0xFFE53935),
      'icon': Icons.medication_liquid_rounded,
      'schedules': <Map<String, dynamic>>[
        {'time': 'Pagi', 'hour': '08:00', 'taken': true},
        {'time': 'Siang', 'hour': '14:00', 'taken': false},
        {'time': 'Malam', 'hour': '20:00', 'taken': false},
      ],
    },
    {
      'name': 'Vitamin C',
      'dose': '1000 mg',
      'frequency': '1x sehari',
      'startDate': '01 Sep 2024',
      'endDate': '30 Sep 2024',
      'note': 'Sesudah makan',
      'color': const Color(0xFFFF8F00),
      'icon': Icons.local_pharmacy_rounded,
      'schedules': <Map<String, dynamic>>[
        {'time': 'Pagi', 'hour': '08:00', 'taken': true},
      ],
    },
  ];

  // ── Progress helpers ───────────────────────────────────────────────────────

  int get _totalSchedules => _medications.fold<int>(
        0,
        (sum, med) =>
            sum +
            (med['schedules'] as List<Map<String, dynamic>>).length,
      );

  int get _takenSchedules => _medications.fold<int>(
        0,
        (sum, med) =>
            sum +
            (med['schedules'] as List<Map<String, dynamic>>)
                .where((s) => s['taken'] == true)
                .length,
      );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Add medication bottom sheet ────────────────────────────────────────────

  void _showAddMedicationSheet() {
    final nameController = TextEditingController();
    final doseController = TextEditingController();
    String selectedFrequency = '1x sehari';
    final frequencies = ['1x sehari', '2x sehari', '3x sehari', '4x sehari'];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                top: 8,
                left: 20,
                right: 20,
              ),
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
                        color: Colors.grey[300],
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
                          color: const Color(0xFF2196F3).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.add_circle_outline,
                            color: Color(0xFF2196F3), size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Tambah Obat Baru',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Nama Obat
                  TextField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Nama Obat',
                      hintText: 'Contoh: Paracetamol',
                      prefixIcon:
                          const Icon(Icons.medication_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFF2196F3), width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Dosis
                  TextField(
                    controller: doseController,
                    decoration: InputDecoration(
                      labelText: 'Dosis',
                      hintText: 'Contoh: 500 mg',
                      prefixIcon: const Icon(Icons.straighten_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFF2196F3), width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Frekuensi dropdown
                  DropdownButtonFormField<String>(
                    value: selectedFrequency,
                    decoration: InputDecoration(
                      labelText: 'Frekuensi',
                      prefixIcon: const Icon(Icons.repeat_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFF2196F3), width: 2),
                      ),
                    ),
                    items: frequencies
                        .map((f) => DropdownMenuItem(
                              value: f,
                              child: Text(f),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setSheetState(() => selectedFrequency = val);
                      }
                    },
                  ),
                  const SizedBox(height: 24),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (nameController.text.trim().isNotEmpty &&
                            doseController.text.trim().isNotEmpty) {
                          setState(() {
                            _medications.add({
                              'name': nameController.text.trim(),
                              'dose': doseController.text.trim(),
                              'frequency': selectedFrequency,
                              'startDate': 'Hari Ini',
                              'endDate': '-',
                              'note': 'Sesudah makan',
                              'color': const Color(0xFF00897B),
                              'icon': Icons.medication_rounded,
                              'schedules': <Map<String, dynamic>>[
                                {
                                  'time': 'Pagi',
                                  'hour': '08:00',
                                  'taken': false
                                },
                              ],
                            });
                          });
                          Navigator.pop(ctx);
                        }
                      },
                      icon: const Icon(Icons.save_rounded,
                          color: Colors.white),
                      label: const Text(
                        'Simpan Obat',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Pengingat Obat',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF2196F3),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined,
                color: Colors.white),
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
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMedicationList(),
          _buildMedicationList(),
          _buildMedicationList(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMedicationSheet,
        backgroundColor: const Color(0xFF2196F3),
        tooltip: 'Tambah Obat',
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  // ── Medication list ────────────────────────────────────────────────────────

  Widget _buildMedicationList() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        _buildProgressCard(),
        const SizedBox(height: 16),
        ..._medications.asMap().entries.map(
              (entry) => _buildMedicationCard(entry.value, entry.key),
            ),
      ],
    );
  }

  // ── Progress summary card ──────────────────────────────────────────────────

  Widget _buildProgressCard() {
    final total = _totalSchedules;
    final taken = _takenSchedules;
    final double progress = total > 0 ? taken / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF2196F3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2196F3).withOpacity(0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
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
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.medication_outlined,
                    color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Progress Hari Ini',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$taken dari $total dosis sudah diminum',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white24,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            progress >= 1.0
                ? '🎉 Semua dosis hari ini sudah selesai!'
                : '${total - taken} dosis lagi untuk diselesaikan',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ── Single medication card ─────────────────────────────────────────────────

  Widget _buildMedicationCard(Map<String, dynamic> med, int medIndex) {
    final schedules =
        med['schedules'] as List<Map<String, dynamic>>;
    final allTaken = schedules.every((s) => s['taken'] == true);
    final someTaken = schedules.any((s) => s['taken'] == true);
    final Color medColor = med['color'] as Color;

    final Color borderColor;
    if (allTaken) {
      borderColor = Colors.green;
    } else if (someTaken) {
      borderColor = Colors.orange;
    } else {
      borderColor = Colors.grey[300]!;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card header ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            decoration: BoxDecoration(
              color: medColor.withOpacity(0.06),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: medColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(med['icon'] as IconData,
                      color: medColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        med['name'] as String,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${med['dose']}  •  ${med['frequency']}',
                        style: TextStyle(
                            color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: allTaken
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: allTaken
                          ? const Color(0xFF66BB6A)
                          : const Color(0xFFFFB300),
                    ),
                  ),
                  child: Text(
                    allTaken ? 'Selesai' : 'Dalam Proses',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: allTaken
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFE65100),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Sub-info: date range + note ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Row(
              children: [
                Icon(Icons.calendar_today_outlined,
                    size: 13, color: Colors.grey[400]),
                const SizedBox(width: 5),
                Text(
                  '${med['startDate']} - ${med['endDate']}',
                  style:
                      TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                const SizedBox(width: 16),
                Icon(Icons.restaurant_outlined,
                    size: 13, color: Colors.grey[400]),
                const SizedBox(width: 5),
                Text(
                  med['note'] as String,
                  style:
                      TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),

          const Divider(height: 1, indent: 14, endIndent: 14),

          // ── Schedule checkboxes ──────────────────────────────────────────
          ...schedules.asMap().entries.map((entry) {
            final schedIndex = entry.key;
            final sched = entry.value;
            final bool isTaken = sched['taken'] == true;

            return CheckboxListTile(
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              value: isTaken,
              activeColor: const Color(0xFF2196F3),
              checkColor: Colors.white,
              onChanged: (val) {
                setState(() {
                  (_medications[medIndex]['schedules']
                          as List<Map<String, dynamic>>)[schedIndex]
                      ['taken'] = val ?? false;
                });
              },
              title: Row(
                children: [
                  Text(
                    sched['time'] as String,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isTaken
                          ? FontWeight.normal
                          : FontWeight.w600,
                      color: isTaken ? Colors.grey[400] : Colors.black87,
                      decoration: isTaken
                          ? TextDecoration.lineThrough
                          : null,
                      decorationColor: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isTaken
                          ? Colors.grey[100]
                          : const Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isTaken
                            ? Colors.grey[300]!
                            : Colors.grey[200]!,
                      ),
                    ),
                    child: Text(
                      sched['hour'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        color: isTaken
                            ? Colors.grey[400]
                            : Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              secondary: isTaken
                  ? const Icon(Icons.check_circle_rounded,
                      color: Colors.green, size: 20)
                  : Icon(Icons.radio_button_unchecked_rounded,
                      color: Colors.grey[400], size: 20),
            );
          }),

          const SizedBox(height: 6),
        ],
      ),
    );
  }
}
