import 'package:flutter/material.dart';

import 'package:Telehealth/data/models/consultation_session.dart';
import 'package:Telehealth/data/repositories/consultation_repository.dart';

/// Tab 2 – Riwayat Obat Pasien.
///
/// Menampilkan:
/// - Bagian "Obat Aktif": obat yang sedang dikonsumsi
/// - Bagian "Riwayat Obat": obat yang sudah selesai atau dihentikan
class MedicationHistoryTab extends StatefulWidget {
  const MedicationHistoryTab({super.key, required this.patientId});

  final String patientId;

  @override
  State<MedicationHistoryTab> createState() => _MedicationHistoryTabState();
}

class _MedicationHistoryTabState extends State<MedicationHistoryTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<PatientMedicationRecord> _all = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final records = await ConsultationRepository.instance
        .getMedicationRecords(widget.patientId);
    if (!mounted) return;
    setState(() {
      _all = records;
      _loading = false;
    });
  }

  List<PatientMedicationRecord> get _active =>
      _all.where((m) => m.isActive).toList();
  List<PatientMedicationRecord> get _history =>
      _all.where((m) => !m.isActive).toList();

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Obat Aktif ───────────────────────────────────────────────────────
        _SectionLabel(
          icon: Icons.medication_rounded,
          title: 'Obat Aktif',
          count: _active.length,
          color: Colors.green.shade600,
        ),
        const SizedBox(height: 10),
        if (_active.isEmpty)
          _EmptyState(
            icon: Icons.check_circle_outline,
            message: 'Tidak ada obat aktif tercatat',
            color: Colors.green.shade400,
          )
        else
          ..._active.map((m) => _MedicationCard(medication: m, isActive: true)),

        const SizedBox(height: 20),

        // ── Riwayat Obat ─────────────────────────────────────────────────────
        _SectionLabel(
          icon: Icons.history_rounded,
          title: 'Riwayat Obat',
          count: _history.length,
          color: Colors.grey.shade700,
        ),
        const SizedBox(height: 10),
        if (_history.isEmpty)
          _EmptyState(
            icon: Icons.inventory_2_outlined,
            message: 'Tidak ada riwayat obat sebelumnya',
            color: Colors.grey.shade400,
          )
        else
          ..._history
              .map((m) => _MedicationCard(medication: m, isActive: false)),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Card obat ─────────────────────────────────────────────────────────────────
class _MedicationCard extends StatelessWidget {
  const _MedicationCard({
    required this.medication,
    required this.isActive,
  });

  final PatientMedicationRecord medication;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: isActive
            ? BorderSide(color: medication.color.withValues(alpha: 0.3))
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ikon warna
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: medication.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: medication.color.withValues(alpha: 0.25)),
              ),
              child: Icon(
                Icons.medication_rounded,
                color: medication.color,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            // Detail obat
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          medication.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isActive
                                ? Colors.black87
                                : Colors.grey.shade700,
                          ),
                        ),
                      ),
                      if (!isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Selesai',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _InfoRow(
                    icon: Icons.scale_outlined,
                    label: '${medication.dose} • ${medication.frequency}',
                    color: medication.color,
                  ),
                  const SizedBox(height: 2),
                  _InfoRow(
                    icon: Icons.calendar_month_outlined,
                    label: '${medication.startDate} – ${medication.endDate}',
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(height: 2),
                  _InfoRow(
                    icon: Icons.person_outline,
                    label: 'Diresepkan: ${medication.prescribedBy}',
                    color: scheme.primary,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            medication.indication,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Info row ──────────────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.icon,
    required this.title,
    required this.count,
    required this.color,
  });

  final IconData icon;
  final String title;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count item',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
