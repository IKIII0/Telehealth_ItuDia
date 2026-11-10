import 'package:flutter/material.dart';

import 'package:Telehealth/data/models/consultation_session.dart';
import 'package:Telehealth/data/repositories/consultation_repository.dart';

/// Tab 3 – Riwayat Konsultasi Pasien dengan Dokter Lain.
///
/// Menampilkan daftar kartu kronologis setiap kunjungan konsultasi
/// sebelumnya, termasuk diagnosis, catatan, dan obat yang diresepkan.
class ConsultationHistoryTab extends StatefulWidget {
  const ConsultationHistoryTab({super.key, required this.patientId});

  final String patientId;

  @override
  State<ConsultationHistoryTab> createState() =>
      _ConsultationHistoryTabState();
}

class _ConsultationHistoryTabState extends State<ConsultationHistoryTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<PastConsultationRecord> _records = [];
  bool _loading = true;
  final Set<String> _expandedIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final records = await ConsultationRepository.instance
        .getConsultationHistory(widget.patientId);
    if (!mounted) return;
    setState(() {
      _records = records;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_records.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.history_edu_outlined,
                size: 64,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 12),
              Text(
                'Belum ada riwayat konsultasi',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Riwayat kunjungan ke dokter lain\nakan tampil di sini.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Icon(
              Icons.history_edu_outlined,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Riwayat Kunjungan (${_records.length} catatan)',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Riwayat konsultasi dengan dokter lain, dari terbaru',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 14),
        // Timeline
        _buildTimeline(),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildTimeline() {
    return Column(
      children: List.generate(_records.length, (i) {
        final record = _records[i];
        final isLast = i == _records.length - 1;
        return _TimelineItem(
          record: record,
          isLast: isLast,
          isExpanded: _expandedIds.contains(record.id),
          onToggle: () => setState(() {
            if (_expandedIds.contains(record.id)) {
              _expandedIds.remove(record.id);
            } else {
              _expandedIds.add(record.id);
            }
          }),
        );
      }),
    );
  }
}

// ── Timeline item ─────────────────────────────────────────────────────────────
class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.record,
    required this.isLast,
    required this.isExpanded,
    required this.onToggle,
  });

  final PastConsultationRecord record;
  final bool isLast;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    final dateLabel =
        '${record.date.day} ${months[record.date.month - 1]} ${record.date.year}';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Garis timeline
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.only(top: 14),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primary,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.3),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: scheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Kartu
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Card(
                elevation: 1.5,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: onToggle,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header kartu
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor:
                                  scheme.primary.withValues(alpha: 0.1),
                              child: Text(
                                _doctorInitials(record.doctorName),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: scheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    record.doctorName,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    record.specialization,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: scheme.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    record.hospital,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  dateLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Icon(
                                  isExpanded
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  size: 18,
                                  color: Colors.grey.shade500,
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Keluhan
                        _InfoChip(
                          icon: Icons.report_problem_outlined,
                          label: 'Keluhan',
                          value: record.complaint,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(height: 6),
                        // Diagnosis – selalu tampil
                        _InfoChip(
                          icon: Icons.medical_information_outlined,
                          label: 'Diagnosis',
                          value: record.diagnosis,
                          color: Colors.blue.shade700,
                        ),
                        // Detail expandable
                        if (isExpanded) ...[
                          const SizedBox(height: 10),
                          const Divider(height: 1),
                          const SizedBox(height: 10),
                          // Catatan dokter
                          _InfoChip(
                            icon: Icons.notes_rounded,
                            label: 'Catatan Dokter',
                            value: record.notes,
                            color: Colors.teal.shade700,
                          ),
                          const SizedBox(height: 8),
                          // Obat diresepkan
                          if (record.prescribedMedications.isNotEmpty) ...[
                            Row(
                              children: [
                                Icon(
                                  Icons.medication_liquid_outlined,
                                  size: 14,
                                  color: Colors.purple.shade700,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Obat Diresepkan:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ...record.prescribedMedications.map(
                              (m) => Padding(
                                padding: const EdgeInsets.only(
                                    left: 8, bottom: 4),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.circle,
                                      size: 6,
                                      color: Colors.purple.shade400,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        m,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          // Follow-up
                          if (record.followUpDate != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.amber.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.event_note,
                                    size: 14,
                                    color: Colors.amber.shade800,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Kontrol ulang: ${_formatDate(record.followUpDate!)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.amber.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _doctorInitials(String name) {
    final cleaned = name.replaceAll('dr.', '').replaceAll(',', ' ').trim();
    final parts = cleaned
        .split(' ')
        .where((p) => p.isNotEmpty && !p.startsWith('Sp'))
        .toList();
    if (parts.isEmpty) return 'DR';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

// ── Info chip (label + value dalam container) ────────────────────────────────
class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}
