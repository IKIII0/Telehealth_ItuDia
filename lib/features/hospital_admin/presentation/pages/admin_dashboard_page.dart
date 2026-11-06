import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:Telehealth/core/routing/app_routes.dart';
import 'package:Telehealth/core/widgets/app_dialogs.dart';
import 'package:Telehealth/core/widgets/async_state.dart';
import 'package:Telehealth/data/models/hospital_admin.dart';
import 'package:Telehealth/data/repositories/hospital_admin_repository.dart';
import 'package:Telehealth/features/hospital_admin/presentation/theme/admin_theme.dart';
import 'package:Telehealth/features/hospital_admin/presentation/widgets/admin_widgets.dart';
import 'package:Telehealth/features/hospital_admin/presentation/widgets/follow_up_dialog.dart';

/// Halaman 1 — Ringkasan Dashboard (analitik utama).
class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  late Future<_DashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DashboardData> _load() async {
    final repository = HospitalAdminRepository.instance;
    final results = await Future.wait<Object>([
      repository.fetchSummary(),
      repository.fetchPrescriptions(
        status: PrescriptionStatus.pendingVerification,
      ),
      repository.fetchPatients(),
      repository.fetchAlerts(),
    ]);

    return _DashboardData(
      summary: results[0] as HospitalAdminSummary,
      pending: results[1] as List<AdminPrescription>,
      patients: results[2] as List<MonitoredPatient>,
      alerts: results[3] as List<AdherenceAlert>,
    );
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    try {
      await future;
    } catch (_) {
      // Error ditampilkan oleh FutureBuilder.
    }
  }

  Future<void> _openFollowUp(AdherenceAlert alert) async {
    final saved = await FollowUpDialog.show(
      context,
      patientId: alert.patientId,
      patientName: alert.patientName,
      reportId: alert.type == AlertType.complaint ? alert.id : null,
    );
    if (!mounted || !saved) return;
    showAppSnack(context, 'Tindak lanjut berhasil dicatat');
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DashboardData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AdminColors.primary),
          );
        }

        if (snapshot.hasError) {
          return ErrorView(message: '${snapshot.error}', onRetry: _refresh);
        }

        final data = snapshot.data;
        if (data == null) return const SizedBox.shrink();

        return RefreshIndicator(
          color: AdminColors.primary,
          onRefresh: _refresh,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding = constraints.maxWidth < 720
                  ? 16.0
                  : 28.0;

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
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
                      title: 'Ringkasan Dashboard',
                      subtitle:
                          'Analitik utama pasien pasca rawat inap • '
                          '${data.summary.hospitalName}',
                      actions: [
                        OutlinedButton.icon(
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh_rounded, size: 17),
                          label: const Text('Perbarui'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _StatGrid(summary: data.summary),
                    const SizedBox(height: 20),
                    _AttentionSection(
                      pending: data.pending,
                      alerts: data.alerts,
                      onOpenMedications: () =>
                          context.go(AppRoutes.hospitalAdminMedicationPath),
                      onOpenPatients: () =>
                          context.go(AppRoutes.hospitalAdminPatientsPath),
                      onFollowUp: _openFollowUp,
                    ),
                    const SizedBox(height: 20),
                    _AdherenceSection(
                      patients: data.patients,
                      onOpenPatients: () =>
                          context.go(AppRoutes.hospitalAdminPatientsPath),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _DashboardData {
  const _DashboardData({
    required this.summary,
    required this.pending,
    required this.patients,
    required this.alerts,
  });

  final HospitalAdminSummary summary;
  final List<AdminPrescription> pending;
  final List<MonitoredPatient> patients;
  final List<AdherenceAlert> alerts;
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.summary});

  final HospitalAdminSummary summary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1180
            ? 4
            : constraints.maxWidth >= 740
            ? 2
            : 1;
        const spacing = 14.0;
        final cardWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        final cards = <Widget>[
          AdminStatCard(
            label: 'Total Pasien Aktif',
            value: '${summary.activePatients}',
            caption: 'Pasca rawat inap',
            icon: Icons.groups_2_outlined,
            accent: AdminColors.info,
          ),
          AdminStatCard(
            label: 'Resep Menunggu Verifikasi',
            value: '${summary.pendingPrescriptions}',
            caption: 'Perlu diverifikasi admin',
            icon: Icons.medication_outlined,
            accent: AdminColors.warning,
            highlight: summary.pendingPrescriptions > 0,
          ),
          AdminStatCard(
            label: 'Kepatuhan Minum Obat',
            value: '${summary.adherenceLabel}%',
            caption: 'Rata-rata seluruh pasien',
            icon: Icons.insights_rounded,
            accent: colorForAdherence(summary.adherenceScore),
          ),
          AdminStatCard(
            label: 'Peringatan Risiko Tinggi',
            value: '${summary.highRiskAlerts}',
            caption: '${summary.openAlerts} peringatan aktif',
            icon: Icons.warning_amber_rounded,
            accent: AdminColors.danger,
            highlight: summary.highRiskAlerts > 0,
          ),
        ];

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final card in cards) SizedBox(width: cardWidth, child: card),
          ],
        );
      },
    );
  }
}

class _AttentionSection extends StatelessWidget {
  const _AttentionSection({
    required this.pending,
    required this.alerts,
    required this.onOpenMedications,
    required this.onOpenPatients,
    required this.onFollowUp,
  });

  final List<AdminPrescription> pending;
  final List<AdherenceAlert> alerts;
  final VoidCallback onOpenMedications;
  final VoidCallback onOpenPatients;
  final ValueChanged<AdherenceAlert> onFollowUp;

  @override
  Widget build(BuildContext context) {
    final pendingPanel = AdminPanel(
      title: 'Resep Menunggu Verifikasi',
      subtitle: '${pending.length} resep menunggu tindakan admin',
      trailing: TextButton(
        onPressed: onOpenMedications,
        child: const Text('Lihat semua'),
      ),
      child: pending.isEmpty
          ? const AdminEmptyState(
              icon: Icons.verified_rounded,
              title: 'Tidak ada resep yang menunggu',
              message: 'Semua resep dokter sudah diverifikasi.',
            )
          : Column(
              children: [
                for (var index = 0; index < pending.length; index++) ...[
                  _PendingPrescriptionTile(
                    prescription: pending[index],
                    onVerify: onOpenMedications,
                  ),
                  if (index != pending.length - 1)
                    const Divider(height: 20, color: AdminColors.border),
                ],
              ],
            ),
    );

    final alertPanel = AdminPanel(
      title: 'Peringatan Risiko Tinggi',
      subtitle: '${alerts.length} peringatan aktif dari pasien',
      trailing: TextButton(
        onPressed: onOpenPatients,
        child: const Text('Pantau'),
      ),
      child: alerts.isEmpty
          ? const AdminEmptyState(
              icon: Icons.shield_outlined,
              title: 'Tidak ada peringatan aktif',
              message: 'Tidak ada dosis terlewat atau keluhan baru.',
            )
          : Column(
              children: [
                for (var index = 0; index < alerts.length; index++) ...[
                  _AlertTile(
                    alert: alerts[index],
                    onFollowUp: () => onFollowUp(alerts[index]),
                  ),
                  if (index != alerts.length - 1)
                    const Divider(height: 20, color: AdminColors.border),
                ],
              ],
            ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 980) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [pendingPanel, const SizedBox(height: 16), alertPanel],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: pendingPanel),
            const SizedBox(width: 16),
            Expanded(child: alertPanel),
          ],
        );
      },
    );
  }
}

class _PendingPrescriptionTile extends StatelessWidget {
  const _PendingPrescriptionTile({
    required this.prescription,
    required this.onVerify,
  });

  final AdminPrescription prescription;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdminInitialsAvatar(
              name: prescription.patientName,
              size: 38,
              color: AdminColors.warning,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prescription.patientName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AdminColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${prescription.doctorName} • '
                    '${adminRelativeTime(prescription.createdAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AdminColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    prescription.medicationSummary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: AdminColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            AdminStatusBadge(
              label: prescription.status.label,
              tone: badgeToneForPrescription(prescription.status),
              icon: iconForPrescription(prescription.status),
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: onVerify,
              icon: const Icon(Icons.fact_check_outlined, size: 16),
              label: const Text('Verifikasi'),
            ),
          ],
        ),
      ],
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.alert, required this.onFollowUp});

  final AdherenceAlert alert;
  final VoidCallback onFollowUp;

  @override
  Widget build(BuildContext context) {
    final color = colorForRisk(alert.severity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: AdminLiveDot(color: color, size: 8),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          alert.patientName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AdminColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AdminStatusBadge(
                        label: alert.type.label,
                        tone: alert.isCritical
                            ? AdminBadgeTone.danger
                            : AdminBadgeTone.warning,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    alert.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: AdminColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    adminRelativeTime(alert.createdAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AdminColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: onFollowUp,
            icon: const Icon(Icons.support_agent_rounded, size: 16),
            label: const Text('Tindak Lanjut'),
          ),
        ),
      ],
    );
  }
}

class _AdherenceSection extends StatelessWidget {
  const _AdherenceSection({
    required this.patients,
    required this.onOpenPatients,
  });

  final List<MonitoredPatient> patients;
  final VoidCallback onOpenPatients;

  @override
  Widget build(BuildContext context) {
    final sorted = List<MonitoredPatient>.of(patients)
      ..sort((a, b) => a.adherenceScore.compareTo(b.adherenceScore));
    final preview = sorted.take(5).toList();

    return AdminPanel(
      title: 'Kepatuhan Pasien',
      subtitle: 'Lima pasien dengan skor kepatuhan terendah',
      trailing: TextButton(
        onPressed: onOpenPatients,
        child: const Text('Pemantauan'),
      ),
      child: preview.isEmpty
          ? const AdminEmptyState(
              icon: Icons.monitor_heart_outlined,
              title: 'Belum ada pasien terdaftar',
            )
          : Column(
              children: [
                for (var index = 0; index < preview.length; index++) ...[
                  _AdherenceRow(patient: preview[index]),
                  if (index != preview.length - 1)
                    const Divider(height: 18, color: AdminColors.border),
                ],
              ],
            ),
    );
  }
}

class _AdherenceRow extends StatelessWidget {
  const _AdherenceRow({required this.patient});

  final MonitoredPatient patient;

  @override
  Widget build(BuildContext context) {
    final color = colorForAdherence(patient.adherenceScore);

    return Row(
      children: [
        AdminInitialsAvatar(name: patient.name, size: 34, color: color),
        const SizedBox(width: 10),
        Expanded(
          flex: 4,
          child: Column(
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
                patient.doctorName,
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
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: AdminProgressBar(value: patient.adherenceScore, color: color),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 42,
          child: Text(
            patient.adherenceLabel,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
