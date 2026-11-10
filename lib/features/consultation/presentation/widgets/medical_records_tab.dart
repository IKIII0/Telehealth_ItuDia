import 'package:flutter/material.dart';

import 'package:Telehealth/data/models/consultation_session.dart';
import 'package:Telehealth/data/repositories/consultation_repository.dart';

/// Tab 1 – Riwayat Medis Pasien.
///
/// Menampilkan:
/// - Kartu ringkasan vital terkini (nilai terakhir per metrik)
/// - Daftar rekam medis historis dengan indikator tren
class MedicalRecordsTab extends StatefulWidget {
  const MedicalRecordsTab({super.key, required this.patientId});

  final String patientId;

  @override
  State<MedicalRecordsTab> createState() => _MedicalRecordsTabState();
}

class _MedicalRecordsTabState extends State<MedicalRecordsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Map<String, PatientVitalRecord> _latest = {};
  List<PatientVitalRecord> _all = [];
  bool _loading = true;
  String? _selectedMetric;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final latestFuture =
        ConsultationRepository.instance.getLatestVitals(widget.patientId);
    final allFuture =
        ConsultationRepository.instance.getVitalRecords(widget.patientId);
    final results = await Future.wait([latestFuture, allFuture]);
    if (!mounted) return;
    setState(() {
      _latest = results[0] as Map<String, PatientVitalRecord>;
      _all = results[1] as List<PatientVitalRecord>;
      _selectedMetric = _latest.keys.isNotEmpty ? _latest.keys.first : null;
      _loading = false;
    });
  }

  List<PatientVitalRecord> get _filteredRecords => _selectedMetric == null
      ? _all
      : _all.where((r) => r.metricName == _selectedMetric).toList();

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Ringkasan Vital Terkini ──────────────────────────────────────────
        const _SectionHeader(
          icon: Icons.dashboard_outlined,
          title: 'Ringkasan Vital Terkini',
          subtitle: 'Nilai terakhir yang tercatat',
        ),
        const SizedBox(height: 10),
        _buildVitalSummaryGrid(scheme),
        const SizedBox(height: 20),

        // ── Riwayat Detail per Metrik ───────────────────────────────────────
        _SectionHeader(
          icon: Icons.timeline_outlined,
          title: 'Riwayat Detail',
          subtitle: 'Pilih metrik untuk melihat riwayat',
          trailing: _buildMetricFilter(scheme),
        ),
        const SizedBox(height: 10),
        ..._filteredRecords.map((r) => _VitalRecordCard(record: r)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildVitalSummaryGrid(ColorScheme scheme) {
    final metricConfig = {
      'Tekanan Darah': (
        icon: Icons.favorite_outlined,
        color: Colors.red.shade600,
        secondaryLabel: (PatientVitalRecord r) => r.secondaryValue != null
            ? '${r.value.toInt()}/${r.secondaryValue!.toInt()} mmHg'
            : '${r.value.toInt()} mmHg',
      ),
      'Gula Darah': (
        icon: Icons.water_drop_outlined,
        color: Colors.amber.shade700,
        secondaryLabel: (PatientVitalRecord r) =>
            '${r.value.toInt()} ${r.unit}',
      ),
      'Berat Badan': (
        icon: Icons.monitor_weight_outlined,
        color: Colors.teal.shade600,
        secondaryLabel: (PatientVitalRecord r) => '${r.value} ${r.unit}',
      ),
      'Detak Jantung': (
        icon: Icons.monitor_heart_outlined,
        color: Colors.purple.shade600,
        secondaryLabel: (PatientVitalRecord r) =>
            '${r.value.toInt()} ${r.unit}',
      ),
      'Suhu Tubuh': (
        icon: Icons.thermostat_outlined,
        color: Colors.orange.shade700,
        secondaryLabel: (PatientVitalRecord r) => '${r.value} ${r.unit}',
      ),
    };

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _latest.entries.map((e) {
        final metricName = e.key;
        final record = e.value;
        final cfg = metricConfig[metricName];
        final icon = cfg?.icon ?? Icons.show_chart;
        final color = cfg?.color ?? scheme.primary;
        final valueLabel = cfg?.secondaryLabel(record) ??
            '${record.value} ${record.unit}';
        final isAbnormal = record.isAbnormal;
        final statusColor = isAbnormal
            ? (record.status == 'Kritis' ? Colors.red : Colors.orange)
            : Colors.green;

        return GestureDetector(
          onTap: () => setState(() => _selectedMetric = metricName),
          child: Container(
            width: (MediaQuery.of(context).size.width - 48) / 2,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _selectedMetric == metricName
                    ? scheme.primary
                    : Colors.grey.shade200,
                width: _selectedMetric == metricName ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6,
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
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: color, size: 18),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        record.status,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  metricName,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  valueLabel,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isAbnormal ? statusColor : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(record.date),
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMetricFilter(ColorScheme scheme) {
    final metrics = _latest.keys.toList();
    return DropdownButtonHideUnderline(
      child: DropdownButton<String?>(
        value: _selectedMetric,
        isDense: true,
        borderRadius: BorderRadius.circular(10),
        style: TextStyle(
          fontSize: 12,
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        ),
        items: [
          const DropdownMenuItem(value: null, child: Text('Semua')),
          ...metrics.map(
            (m) => DropdownMenuItem(value: m, child: Text(m)),
          ),
        ],
        onChanged: (v) => setState(() => _selectedMetric = v),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

// ── Card rekam medis individual ───────────────────────────────────────────────
class _VitalRecordCard extends StatelessWidget {
  const _VitalRecordCard({required this.record});

  final PatientVitalRecord record;

  @override
  Widget build(BuildContext context) {
    final isAbnormal = record.isAbnormal;
    final isCritical = record.status == 'Kritis';
    final statusColor = isCritical
        ? Colors.red.shade600
        : (isAbnormal ? Colors.orange.shade700 : Colors.green.shade600);

    final valueLabel = record.secondaryValue != null
        ? '${record.value.toInt()}/${record.secondaryValue!.toInt()} ${record.unit}'
        : '${record.value} ${record.unit}';

    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    final dateLabel =
        '${record.date.day} ${months[record.date.month - 1]} ${record.date.year}';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isAbnormal
            ? BorderSide(color: statusColor.withValues(alpha: 0.4))
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Status dot
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.metricName,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        valueLabel,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isAbnormal ? statusColor : Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          record.status,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (record.note.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      record.note,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              dateLabel,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared section header ─────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
