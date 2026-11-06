import 'package:flutter/material.dart';

import 'package:Telehealth/core/widgets/app_dialogs.dart';
import 'package:Telehealth/core/widgets/async_state.dart';
import 'package:Telehealth/data/models/hospital_admin.dart';
import 'package:Telehealth/data/repositories/hospital_admin_repository.dart';
import 'package:Telehealth/features/hospital_admin/presentation/theme/admin_theme.dart';
import 'package:Telehealth/features/hospital_admin/presentation/widgets/admin_widgets.dart';
import 'package:Telehealth/features/hospital_admin/presentation/widgets/prescription_dialogs.dart';

/// Halaman 2 — Verifikasi Obat.
///
/// Menampilkan resep dokter dan memungkinkan admin memverifikasi rincian obat
/// (nama, dosis, frekuensi harian, durasi, instruksi) lalu menerbitkan jadwal.
class AdminMedicationVerificationPage extends StatefulWidget {
  const AdminMedicationVerificationPage({super.key});

  @override
  State<AdminMedicationVerificationPage> createState() =>
      _AdminMedicationVerificationPageState();
}

class _AdminMedicationVerificationPageState
    extends State<AdminMedicationVerificationPage> {
  late Future<List<AdminPrescription>> _future;
  PrescriptionStatus _filter = PrescriptionStatus.pendingVerification;

  @override
  void initState() {
    super.initState();
    _future = HospitalAdminRepository.instance.fetchPrescriptions();
  }

  Future<void> _reload() async {
    final future = HospitalAdminRepository.instance.fetchPrescriptions();
    setState(() => _future = future);
    try {
      await future;
    } catch (_) {
      // Ditampilkan oleh FutureBuilder.
    }
  }

  Future<void> _openVerify(AdminPrescription prescription) async {
    final verified = await PrescriptionVerificationDialog.show(
      context,
      prescription,
    );
    if (!mounted || !verified) return;
    showAppSnack(context, 'Resep diverifikasi & jadwal berhasil diterbitkan');
    await _reload();
  }

  Future<void> _openClarification(AdminPrescription prescription) async {
    final sent = await ClarificationDialog.show(context, prescription);
    if (!mounted || !sent) return;
    showAppSnack(context, 'Permintaan klarifikasi dikirim ke dokter');
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AdminPrescription>>(
      future: _future,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState == ConnectionState.waiting;

        return LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth < 720 ? 16.0 : 28.0;

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
                    title: 'Verifikasi Obat',
                    subtitle:
                        'Periksa resep dokter, lengkapi rincian obat, lalu '
                        'terbitkan jadwal minum obat untuk pasien.',
                    actions: [
                      OutlinedButton.icon(
                        onPressed: loading ? null : _reload,
                        icon: const Icon(Icons.refresh_rounded, size: 17),
                        label: const Text('Perbarui'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const _WorkflowHint(),
                  const SizedBox(height: 18),
                  if (snapshot.hasError)
                    AdminPanel(
                      child: ErrorView(
                        message: '${snapshot.error}',
                        onRetry: _reload,
                      ),
                    )
                  else if (loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 64),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AdminColors.primary,
                        ),
                      ),
                    )
                  else
                    _buildContent(snapshot.data ?? const []),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildContent(List<AdminPrescription> all) {
    final counts = <PrescriptionStatus, int>{
      for (final status in PrescriptionStatus.values)
        status: all.where((item) => item.status == status).length,
    };

    final filtered = all.where((item) => item.status == _filter).toList();
    if (_filter == PrescriptionStatus.pendingVerification ||
        _filter == PrescriptionStatus.needsClarification) {
      filtered.sort((a, b) {
        final left = a.createdAt;
        final right = b.createdAt;
        if (left == null && right == null) return 0;
        if (left == null) return 1;
        if (right == null) return -1;
        return left.compareTo(right);
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final status in PrescriptionStatus.values)
              if (status != PrescriptionStatus.cancelled || counts[status]! > 0)
                ChoiceChip(
                  selected: _filter == status,
                  showCheckmark: false,
                  avatar: Icon(
                    iconForPrescription(status),
                    size: 15,
                    color: _filter == status
                        ? AdminColors.primary
                        : AdminColors.textMuted,
                  ),
                  label: Text('${status.label} (${counts[status]})'),
                  onSelected: (_) => setState(() => _filter = status),
                ),
          ],
        ),
        const SizedBox(height: 18),
        if (filtered.isEmpty)
          AdminPanel(
            child: AdminEmptyState(
              icon: _filter == PrescriptionStatus.pendingVerification
                  ? Icons.verified_rounded
                  : Icons.inbox_outlined,
              title: _filter == PrescriptionStatus.pendingVerification
                  ? 'Tidak ada resep yang menunggu verifikasi'
                  : 'Tidak ada resep dengan status ini',
              message: _filter == PrescriptionStatus.pendingVerification
                  ? 'Semua resep dokter sudah ditindaklanjuti.'
                  : null,
            ),
          )
        else
          for (final prescription in filtered) ...[
            _PrescriptionCard(
              prescription: prescription,
              onVerify: () => _openVerify(prescription),
              onClarify: () => _openClarification(prescription),
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _WorkflowHint extends StatelessWidget {
  const _WorkflowHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.primary.withValues(alpha: 0.15)),
      ),
      child: const Wrap(
        spacing: 20,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _WorkflowStep(
            number: '1',
            label: 'Resep masuk',
            caption: 'Dokter mengirim resep',
          ),
          _WorkflowArrow(),
          _WorkflowStep(
            number: '2',
            label: 'Verifikasi admin',
            caption: 'Lengkapi rincian obat',
            active: true,
          ),
          _WorkflowArrow(),
          _WorkflowStep(
            number: '3',
            label: 'Jadwal terbit',
            caption: 'Pasien menerima pengingat',
          ),
        ],
      ),
    );
  }
}

class _WorkflowStep extends StatelessWidget {
  const _WorkflowStep({
    required this.number,
    required this.label,
    required this.caption,
    this.active = false,
  });

  final String number;
  final String label;
  final String caption;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AdminColors.primary : AdminColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active ? AdminColors.primary : AdminColors.border,
            ),
          ),
          child: Text(
            number,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : AdminColors.textMuted,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AdminColors.textPrimary,
              ),
            ),
            Text(
              caption,
              style: const TextStyle(
                fontSize: 10.5,
                color: AdminColors.textMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _WorkflowArrow extends StatelessWidget {
  const _WorkflowArrow();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.arrow_forward_rounded,
      size: 15,
      color: AdminColors.textMuted,
    );
  }
}

class _PrescriptionCard extends StatelessWidget {
  const _PrescriptionCard({
    required this.prescription,
    required this.onVerify,
    required this.onClarify,
  });

  final AdminPrescription prescription;
  final VoidCallback onVerify;
  final VoidCallback onClarify;

  bool get _canAct =>
      prescription.status.isPending || prescription.status.isNeedsClarification;

  @override
  Widget build(BuildContext context) {
    final tone = badgeToneForPrescription(prescription.status);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: prescription.status.isPending
              ? AdminColors.warning.withValues(alpha: 0.35)
              : AdminColors.border,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F2E3A),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdminInitialsAvatar(
                name: prescription.patientName,
                size: 42,
                color: prescription.status.isPending
                    ? AdminColors.warning
                    : AdminColors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            prescription.patientName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AdminColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        AdminStatusBadge(
                          label: prescription.status.label,
                          tone: tone,
                          icon: iconForPrescription(prescription.status),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${prescription.medicalRecordNo.isEmpty ? 'No. RM -' : prescription.medicalRecordNo}'
                      ' • ${prescription.doctorName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AdminColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Diajukan ${adminRelativeTime(prescription.createdAt)}',
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
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final drug in prescription.drugs)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AdminColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: AdminColors.border),
                  ),
                  child: Text(
                    '${drug.name} • ${drug.dose} • '
                    '${drug.frequencyPerDay}×/hari • ${drug.durationDays} hari',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: AdminColors.textPrimary,
                    ),
                  ),
                ),
            ],
          ),
          if (prescription.doctorNote.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _NoteLine(
              icon: Icons.sticky_note_2_outlined,
              label: 'Catatan dokter',
              message: prescription.doctorNote,
              color: AdminColors.info,
            ),
          ],
          if (prescription.adminNote.trim().isNotEmpty &&
              !prescription.status.isPending) ...[
            const SizedBox(height: 8),
            _NoteLine(
              icon: Icons.admin_panel_settings_outlined,
              label: 'Catatan admin',
              message: prescription.adminNote,
              color: prescription.status.isNeedsClarification
                  ? AdminColors.warning
                  : AdminColors.success,
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.medication_outlined,
                size: 15,
                color: AdminColors.textMuted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  prescription.scheduleSummary,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AdminColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          if (_canAct) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: onClarify,
                  icon: const Icon(Icons.forum_outlined, size: 16),
                  label: const Text('Minta Klarifikasi ke Dokter'),
                ),
                FilledButton.icon(
                  onPressed: onVerify,
                  icon: const Icon(Icons.verified_rounded, size: 17),
                  label: const Text('Verifikasi & Terbitkan Jadwal'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _NoteLine extends StatelessWidget {
  const _NoteLine({
    required this.icon,
    required this.label,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: AdminColors.textPrimary,
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
