import 'dart:async';

import 'package:flutter/material.dart';

import 'package:Telehealth/core/widgets/app_dialogs.dart';
import 'package:Telehealth/core/widgets/async_state.dart';
import 'package:Telehealth/data/models/hospital_admin.dart';
import 'package:Telehealth/data/repositories/hospital_admin_repository.dart';
import 'package:Telehealth/features/hospital_admin/presentation/theme/admin_theme.dart';
import 'package:Telehealth/features/hospital_admin/presentation/widgets/admin_widgets.dart';
import 'package:Telehealth/features/hospital_admin/presentation/widgets/follow_up_dialog.dart';
import 'package:Telehealth/features/hospital_admin/presentation/widgets/notification_follow_up_dialog.dart';

/// Halaman 3 — Pemantauan Kepatuhan Pasien.
///
/// Menampilkan daftar pasien pasca rawat inap, skor kepatuhan, status obat,
/// indikator real-time dosis terlewat/keluhan, dan aksi tindak lanjut.
class AdminPatientMonitoringPage extends StatefulWidget {
  const AdminPatientMonitoringPage({super.key});

  @override
  State<AdminPatientMonitoringPage> createState() =>
      _AdminPatientMonitoringPageState();
}

class _AdminPatientMonitoringPageState
    extends State<AdminPatientMonitoringPage> {
  StreamSubscription<List<AdherenceAlert>>? _alertSubscription;
  final TextEditingController _search = TextEditingController();

  List<MonitoredPatient> _patients = const [];
  List<AdherenceAlert> _alerts = const [];

  /// Waktu kirim notifikasi terakhir per id peringatan (badge "Sudah Diingatkan").
  final Map<String, DateTime> _alertNotifiedAt = {};
  RiskLevel? _riskFilter;
  bool _onlyAttention = false;
  bool _liveConnected = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPatients();
    _subscribeAlerts();
  }

  @override
  void dispose() {
    _alertSubscription?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadPatients({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final patients = await HospitalAdminRepository.instance.fetchPatients();
      if (!mounted) return;
      setState(() {
        _patients = patients;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      if (silent && _patients.isNotEmpty) {
        // Data lama tetap ditampilkan; peringatan realtime sudah cukup.
        setState(() => _loading = false);
        return;
      }
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  void _subscribeAlerts() {
    _alertSubscription = HospitalAdminRepository.instance.watchAlerts().listen(
      (alerts) {
        if (!mounted) return;
        setState(() {
          _alerts = alerts;
          _liveConnected = true;
        });
        unawaited(_loadNotificationLogs(alerts));
        // Indikator dosis terlewat/keluhan di tabel ikut diperbarui tanpa
        // menampilkan loading.
        unawaited(_loadPatients(silent: true));
      },
      onError: (_) {
        if (!mounted) return;
        setState(() => _liveConnected = false);
      },
    );
  }

  Future<void> _refresh() => _loadPatients();

  /// Muat riwayat notifikasi agar badge "Sudah Diingatkan" tetap tampil
  /// setelah halaman dimuat ulang.
  Future<void> _loadNotificationLogs(List<AdherenceAlert> alerts) async {
    final ids = alerts.map((alert) => alert.id).where((id) => id.isNotEmpty);
    final logs = await HospitalAdminRepository.instance.fetchNotificationLogs(
      alertIds: ids,
    );
    if (!mounted || logs.isEmpty) return;
    setState(() => _alertNotifiedAt.addAll(logs));
  }

  Future<void> _openNotificationDialog(AdherenceAlert alert) async {
    final patient = _findPatient(alert.patientId);
    if (patient == null) {
      showAppSnack(context, 'Data pasien tidak ditemukan.', success: false);
      return;
    }

    final outcome = await NotificationFollowUpDialog.show(
      context,
      alert: alert,
      patient: patient,
      loadMedications: () => HospitalAdminRepository.instance
          .fetchActiveMedicationNames(patient.id),
    );
    if (!mounted || outcome == null) return;

    setState(() => _alertNotifiedAt[alert.id] = outcome.sentAt);
    if (outcome.whatsappOpened) {
      showAppSnack(context, 'WhatsApp keluarga ${patient.name} dibuka');
    } else if (outcome.pushDelivered) {
      showAppSnack(context, 'Notifikasi pengingat terkirim ke ${patient.name}');
    } else {
      showAppSnack(
        context,
        'Notifikasi tercatat. Pengingat dikirim saat aplikasi menerima data.',
      );
    }
  }

  Future<void> _openFollowUp(
    MonitoredPatient patient, {
    String? reportId,
  }) async {
    final saved = await FollowUpDialog.show(
      context,
      patientId: patient.id,
      patientName: patient.name,
      reportId: reportId,
    );
    if (!mounted || !saved) return;
    showAppSnack(context, 'Tindak lanjut ${patient.name} berhasil dicatat');
    await _refresh();
  }

  String? _reportIdFor(MonitoredPatient patient) {
    for (final alert in _alerts) {
      if (alert.patientId == patient.id && alert.type == AlertType.complaint) {
        return alert.id;
      }
    }
    return null;
  }

  MonitoredPatient? _findPatient(String patientId) {
    for (final patient in _patients) {
      if (patient.id == patientId) return patient;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 720 ? 16.0 : 28.0;
        final patients = _applyFilters(_patients);

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            24,
            horizontalPadding,
            32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminPageHeader(
                title: 'Pemantauan Pasien',
                subtitle:
                    'Pantau kepatuhan minum obat dan keluhan pasien pasca '
                    'rawat inap secara langsung.',
                actions: [
                  _LiveStatusChip(connected: _liveConnected),
                  OutlinedButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded, size: 17),
                    label: const Text('Perbarui'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _AlertsPanel(
                alerts: _alerts,
                notifiedAt: _alertNotifiedAt,
                onFollowUp: (alert) async {
                  await _openNotificationDialog(alert);
                },
              ),
              const SizedBox(height: 18),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 64),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AdminColors.primary,
                    ),
                  ),
                )
              else if (_error != null)
                AdminPanel(
                  child: ErrorView(message: _error!, onRetry: _refresh),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildFilters(),
                    const SizedBox(height: 16),
                    if (patients.isEmpty)
                      const AdminPanel(
                        child: AdminEmptyState(
                          icon: Icons.search_off_rounded,
                          title: 'Tidak ada pasien yang cocok',
                          message:
                              'Ubah kata kunci atau filter risiko untuk '
                              'melihat pasien lain.',
                        ),
                      )
                    else if (constraints.maxWidth >= 900)
                      _PatientTable(
                        patients: patients,
                        onFollowUp: (patient) => _openFollowUp(
                          patient,
                          reportId: _reportIdFor(patient),
                        ),
                      )
                    else
                      Column(
                        children: [
                          for (final patient in patients) ...[
                            _PatientCard(
                              patient: patient,
                              onFollowUp: () => _openFollowUp(
                                patient,
                                reportId: _reportIdFor(patient),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  List<MonitoredPatient> _applyFilters(List<MonitoredPatient> patients) {
    final query = _search.text.trim().toLowerCase();

    return patients.where((patient) {
      final matchesQuery =
          query.isEmpty ||
          [
            patient.name,
            patient.medicalRecordNo,
            patient.doctorName,
            patient.diagnosis,
          ].any((value) => value.toLowerCase().contains(query));

      final matchesRisk =
          _riskFilter == null || patient.riskLevel == _riskFilter;
      final matchesAttention = !_onlyAttention || patient.needsAttention;

      return matchesQuery && matchesRisk && matchesAttention;
    }).toList();
  }

  Widget _buildFilters() {
    return AdminPanel(
      padding: const EdgeInsets.all(14),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 280,
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Cari pasien, no. RM, atau dokter…',
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Bersihkan',
                        onPressed: () {
                          _search.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded, size: 17),
                      ),
              ),
            ),
          ),
          for (final level in [null, ...RiskLevel.values])
            FilterChip(
              selected: _riskFilter == level,
              showCheckmark: false,
              label: Text(
                level == null ? 'Semua risiko' : 'Risiko ${level.label}',
              ),
              onSelected: (_) => setState(() => _riskFilter = level),
            ),
          FilterChip(
            selected: _onlyAttention,
            showCheckmark: false,
            avatar: const Icon(
              Icons.priority_high_rounded,
              size: 15,
              color: AdminColors.danger,
            ),
            label: const Text('Perlu perhatian'),
            onSelected: (value) => setState(() => _onlyAttention = value),
          ),
        ],
      ),
    );
  }
}

class _LiveStatusChip extends StatelessWidget {
  const _LiveStatusChip({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AdminColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AdminLiveDot(
            color: connected ? AdminColors.success : AdminColors.textMuted,
            size: 8,
          ),
          const SizedBox(width: 7),
          Text(
            connected ? 'Real-time aktif' : 'Menghubungkan…',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AdminColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertsPanel extends StatelessWidget {
  const _AlertsPanel({
    required this.alerts,
    required this.notifiedAt,
    required this.onFollowUp,
  });

  final List<AdherenceAlert> alerts;
  final Map<String, DateTime> notifiedAt;
  final ValueChanged<AdherenceAlert> onFollowUp;

  @override
  Widget build(BuildContext context) {
    final pending = alerts
        .where((alert) => !notifiedAt.containsKey(alert.id))
        .length;

    final String subtitle;
    if (alerts.isEmpty) {
      subtitle = 'Belum ada dosis terlewat atau keluhan baru';
    } else if (pending == 0) {
      subtitle = 'Semua peringatan sudah ditindaklanjuti';
    } else {
      subtitle = '$pending peringatan perlu ditindaklanjuti';
    }

    return AdminPanel(
      title: 'Peringatan Real-time',
      subtitle: subtitle,
      trailing: AdminLiveDot(
        color: alerts.isEmpty || pending == 0
            ? AdminColors.success
            : AdminColors.danger,
      ),
      child: alerts.isEmpty
          ? const AdminEmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'Tidak ada peringatan aktif',
              message:
                  'Indikator akan muncul otomatis saat pasien melewatkan dosis '
                  'atau melaporkan keluhan.',
            )
          : Column(
              children: [
                for (var index = 0; index < alerts.length; index++) ...[
                  _AlertRow(
                    alert: alerts[index],
                    notifiedAt: notifiedAt[alerts[index].id],
                    onFollowUp: () => onFollowUp(alerts[index]),
                  ),
                  if (index != alerts.length - 1)
                    const Divider(height: 18, color: AdminColors.border),
                ],
              ],
            ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({
    required this.alert,
    required this.onFollowUp,
    this.notifiedAt,
  });

  final AdherenceAlert alert;
  final VoidCallback onFollowUp;
  final DateTime? notifiedAt;

  @override
  Widget build(BuildContext context) {
    final color = colorForRisk(alert.severity);
    final isNotified = notifiedAt != null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: AdminLiveDot(
            color: isNotified ? AdminColors.success : color,
            size: 8,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    alert.patientName,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AdminColors.textPrimary,
                    ),
                  ),
                  AdminStatusBadge(
                    label: alert.type.label,
                    tone: alert.isCritical
                        ? AdminBadgeTone.danger
                        : AdminBadgeTone.warning,
                  ),
                  if (isNotified)
                    const AdminStatusBadge(
                      label: 'Sudah Diingatkan',
                      tone: AdminBadgeTone.success,
                      icon: Icons.mark_email_read_rounded,
                    ),
                  Text(
                    isNotified
                        ? 'Diingatkan ${adminRelativeTime(notifiedAt)}'
                        : adminRelativeTime(alert.createdAt),
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AdminColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                alert.message,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: AdminColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: onFollowUp,
          child: Text(isNotified ? 'Ingatkan Lagi' : 'Tindak lanjut'),
        ),
      ],
    );
  }
}

class _PatientTable extends StatelessWidget {
  const _PatientTable({required this.patients, required this.onFollowUp});

  final List<MonitoredPatient> patients;
  final ValueChanged<MonitoredPatient> onFollowUp;

  @override
  Widget build(BuildContext context) {
    return AdminPanel(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 26,
          horizontalMargin: 16,
          headingRowHeight: 44,
          dataRowMinHeight: 68,
          dataRowMaxHeight: 84,
          headingRowColor: const WidgetStatePropertyAll(
            AdminColors.surfaceMuted,
          ),
          dividerThickness: 1,
          border: null,
          columns: const [
            DataColumn(label: _TableHeading('PASIEN')),
            DataColumn(label: _TableHeading('DOKTER PENANGGUNG JAWAB')),
            DataColumn(label: _TableHeading('SKOR KEPATUHAN')),
            DataColumn(label: _TableHeading('STATUS OBAT')),
            DataColumn(label: _TableHeading('INDIKATOR')),
            DataColumn(label: _TableHeading('AKSI')),
          ],
          rows: [
            for (final patient in patients)
              DataRow(
                cells: [
                  DataCell(_PatientIdentity(patient: patient)),
                  DataCell(
                    SizedBox(
                      width: 190,
                      child: Text(
                        patient.doctorName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AdminColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: 160,
                      child: _AdherenceCell(patient: patient),
                    ),
                  ),
                  DataCell(_MedicationStatusCell(patient: patient)),
                  DataCell(_IndicatorCell(patient: patient)),
                  DataCell(
                    TextButton.icon(
                      onPressed: () => onFollowUp(patient),
                      icon: const Icon(Icons.support_agent_rounded, size: 16),
                      label: const Text('Tindak Lanjut'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _TableHeading extends StatelessWidget {
  const _TableHeading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: AdminColors.textMuted,
      ),
    );
  }
}

class _PatientIdentity extends StatelessWidget {
  const _PatientIdentity({required this.patient});

  final MonitoredPatient patient;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      child: Row(
        children: [
          AdminInitialsAvatar(
            name: patient.name,
            size: 34,
            color: colorForRisk(patient.riskLevel),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AdminColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (patient.medicalRecordNo.isNotEmpty)
                      patient.medicalRecordNo,
                    'Risiko ${patient.riskLevel.label}',
                  ].join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AdminColors.textMuted,
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

class _AdherenceCell extends StatelessWidget {
  const _AdherenceCell({required this.patient});

  final MonitoredPatient patient;

  @override
  Widget build(BuildContext context) {
    final color = colorForAdherence(patient.adherenceScore);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: AdminProgressBar(
                value: patient.adherenceScore,
                color: color,
                height: 7,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              patient.adherenceLabel,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          patient.lastAdherenceDate == null
              ? 'Belum ada laporan'
              : 'Terakhir ${adminFormatDate(patient.lastAdherenceDate)}',
          style: const TextStyle(fontSize: 10, color: AdminColors.textMuted),
        ),
      ],
    );
  }
}

class _MedicationStatusCell extends StatelessWidget {
  const _MedicationStatusCell({required this.patient});

  final MonitoredPatient patient;

  @override
  Widget build(BuildContext context) {
    final status = medicationStatusOf(patient);
    return AdminStatusBadge(
      label: status.label,
      tone: status.tone,
      icon: status.icon,
    );
  }
}

class _IndicatorCell extends StatelessWidget {
  const _IndicatorCell({required this.patient});

  final MonitoredPatient patient;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch ((
      patient.openReports,
      patient.missedDosesToday,
    )) {
      (> 0, _) => (AdminColors.danger, '${patient.openReports} keluhan'),
      (_, > 0) => (
        AdminColors.danger,
        '${patient.missedDosesToday} dosis terlewat',
      ),
      _ when patient.riskLevel.isHigh => (AdminColors.warning, 'Risiko tinggi'),
      _ => (AdminColors.success, 'Aman'),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AdminLiveDot(color: color, size: 8),
        const SizedBox(width: 7),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _PatientCard extends StatelessWidget {
  const _PatientCard({required this.patient, required this.onFollowUp});

  final MonitoredPatient patient;
  final VoidCallback onFollowUp;

  @override
  Widget build(BuildContext context) {
    final status = medicationStatusOf(patient);
    final adherenceColor = colorForAdherence(patient.adherenceScore);
    final indicatorColor = patient.hasOpenReport || patient.hasMissedDose
        ? AdminColors.danger
        : colorForRisk(patient.riskLevel);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: patient.needsAttention
              ? indicatorColor.withValues(alpha: 0.3)
              : AdminColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdminInitialsAvatar(
                name: patient.name,
                size: 40,
                color: colorForRisk(patient.riskLevel),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AdminColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      patient.doctorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AdminColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              AdminStatusBadge(
                label: 'Risiko ${patient.riskLevel.label}',
                tone: badgeToneForRisk(patient.riskLevel),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: AdminProgressBar(
                  value: patient.adherenceScore,
                  color: adherenceColor,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Kepatuhan ${patient.adherenceLabel}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: adherenceColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AdminStatusBadge(
                label: status.label,
                tone: status.tone,
                icon: status.icon,
              ),
              AdminStatusBadge(
                label: patient.hasOpenReport
                    ? '${patient.openReports} keluhan'
                    : patient.hasMissedDose
                    ? '${patient.missedDosesToday} dosis terlewat'
                    : 'Tidak ada peringatan',
                tone: patient.needsAttention
                    ? AdminBadgeTone.danger
                    : AdminBadgeTone.success,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: onFollowUp,
              icon: const Icon(Icons.support_agent_rounded, size: 16),
              label: const Text('Catat Tindak Lanjut'),
            ),
          ),
        ],
      ),
    );
  }
}
