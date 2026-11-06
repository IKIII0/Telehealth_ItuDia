import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:Telehealth/data/models/hospital_admin.dart';
import 'package:Telehealth/data/repositories/hospital_admin_repository.dart';
import 'package:Telehealth/features/hospital_admin/presentation/theme/admin_theme.dart';

/// Modal verifikasi resep.
///
/// Admin dapat memperbaiki rincian obat dari dokter, lalu menekan
/// "Verifikasi & Terbitkan Jadwal". Item resep diganti utuh di server sehingga
/// jadwal yang dilihat pasien selalu sama dengan yang diverifikasi.
class PrescriptionVerificationDialog extends StatefulWidget {
  const PrescriptionVerificationDialog({super.key, required this.prescription});

  final AdminPrescription prescription;

  static Future<bool> show(
    BuildContext context,
    AdminPrescription prescription,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          PrescriptionVerificationDialog(prescription: prescription),
    );
    return result ?? false;
  }

  @override
  State<PrescriptionVerificationDialog> createState() =>
      _PrescriptionVerificationDialogState();
}

class _PrescriptionVerificationDialogState
    extends State<PrescriptionVerificationDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _adminNote = TextEditingController();
  final List<_DrugForm> _drugs = [];

  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.prescription.drugs.isEmpty) {
      _drugs.add(_DrugForm.empty());
    } else {
      for (final drug in widget.prescription.drugs) {
        _drugs.add(_DrugForm.fromDrug(drug));
      }
    }
  }

  @override
  void dispose() {
    _adminNote.dispose();
    for (final drug in _drugs) {
      drug.dispose();
    }
    super.dispose();
  }

  void _addDrug() {
    setState(() => _drugs.add(_DrugForm.empty()));
  }

  void _removeDrug(int index) {
    if (_drugs.length == 1) return;
    setState(() {
      _drugs.removeAt(index).dispose();
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await HospitalAdminRepository.instance.verifyPrescription(
        prescription: widget.prescription,
        drugs: _drugs.map((form) => form.toDrug()).toList(),
        adminNote: _adminNote.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on HospitalAdminException catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Terjadi kesalahan saat memverifikasi resep. Coba lagi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final prescription = widget.prescription;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: AdminColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 780,
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DialogHeader(
              icon: Icons.verified_outlined,
              title: 'Verifikasi Resep',
              subtitle:
                  '${prescription.patientName} • ${prescription.doctorName}',
              onClose: _submitting
                  ? null
                  : () => Navigator.of(context).pop(false),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (prescription.doctorNote.trim().isNotEmpty)
                        _InfoBox(
                          icon: Icons.sticky_note_2_outlined,
                          title: 'Catatan dokter',
                          message: prescription.doctorNote,
                        ),
                      if (_error != null) ...[
                        _ErrorBox(message: _error!),
                        const SizedBox(height: 14),
                      ],
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Rincian obat',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AdminColors.textPrimary,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _submitting ? null : _addDrug,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Tambah obat'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      for (var index = 0; index < _drugs.length; index++) ...[
                        _DrugEditor(
                          index: index,
                          form: _drugs[index],
                          canRemove: _drugs.length > 1,
                          enabled: !_submitting,
                          onRemove: () => _removeDrug(index),
                        ),
                        if (index != _drugs.length - 1)
                          const SizedBox(height: 12),
                      ],
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _adminNote,
                        enabled: !_submitting,
                        minLines: 2,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Catatan admin (opsional)',
                          hintText:
                              'Mis. jadwal disesuaikan dengan kebiasaan makan '
                              'pasien.',
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final message = Text(
                    'Jadwal minum obat otomatis diterbitkan untuk pasien '
                    'setelah diverifikasi.',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: Colors.grey.shade600,
                    ),
                  );
                  final buttons = Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _submitting
                            ? null
                            : () => Navigator.of(context).pop(false),
                        child: const Text('Batal'),
                      ),
                      FilledButton.icon(
                        onPressed: _submitting ? null : _submit,
                        icon: _submitting
                            ? const SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.verified_rounded, size: 18),
                        label: Text(
                          _submitting
                              ? 'Memproses…'
                              : 'Verifikasi & Terbitkan Jadwal',
                        ),
                      ),
                    ],
                  );

                  if (constraints.maxWidth < 640) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [message, const SizedBox(height: 12), buttons],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: message),
                      const SizedBox(width: 16),
                      buttons,
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal permintaan klarifikasi ke dokter.
class ClarificationDialog extends StatefulWidget {
  const ClarificationDialog({super.key, required this.prescription});

  final AdminPrescription prescription;

  static Future<bool> show(
    BuildContext context,
    AdminPrescription prescription,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClarificationDialog(prescription: prescription),
    );
    return result ?? false;
  }

  @override
  State<ClarificationDialog> createState() => _ClarificationDialogState();
}

class _ClarificationDialogState extends State<ClarificationDialog> {
  static const List<String> _templates = [
    'Dosis tidak sesuai dengan kondisi pasien.',
    'Frekuensi pemberian terlalu tinggi.',
    'Durasi terapi perlu dikonfirmasi.',
    'Mohon konfirmasi interaksi dengan obat lain.',
  ];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _message = TextEditingController();

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  void _applyTemplate(String template) {
    final current = _message.text.trim();
    _message.text = current.isEmpty ? template : '$current\n$template';
    _message.selection = TextSelection.collapsed(offset: _message.text.length);
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await HospitalAdminRepository.instance.requestClarification(
        prescription: widget.prescription,
        message: _message.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on HospitalAdminException catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Terjadi kesalahan. Coba lagi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final prescription = widget.prescription;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: AdminColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DialogHeader(
              icon: Icons.forum_outlined,
              title: 'Minta Klarifikasi ke Dokter',
              subtitle:
                  '${prescription.patientName} • ${prescription.doctorName}',
              onClose: _submitting
                  ? null
                  : () => Navigator.of(context).pop(false),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoBox(
                        icon: Icons.medication_outlined,
                        title: 'Resep saat ini',
                        message: prescription.medicationSummary,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        _ErrorBox(message: _error!),
                      ],
                      const SizedBox(height: 18),
                      FormField<void>(
                        validator: (_) => _message.text.trim().isEmpty
                            ? 'Pesan klarifikasi wajib diisi'
                            : null,
                        builder: (field) => TextFormField(
                          controller: _message,
                          enabled: !_submitting,
                          minLines: 4,
                          maxLines: 8,
                          onChanged: (_) {
                            field.didChange(null);
                            if (field.hasError) field.validate();
                          },
                          decoration: InputDecoration(
                            labelText: 'Pesan untuk dokter',
                            alignLabelWithHint: true,
                            hintText:
                                'Jelaskan bagian resep yang perlu dikonfirmasi…',
                            errorText: field.errorText,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final template in _templates)
                            ActionChip(
                              label: Text(template),
                              onPressed: _submitting
                                  ? null
                                  : () => _applyTemplate(template),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.end,
                children: [
                  TextButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('Batal'),
                  ),
                  FilledButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 17),
                    label: Text(
                      _submitting
                          ? 'Mengirim…'
                          : 'Kirim Permintaan Klarifikasi',
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

// ─── Bagian dalam dialog ─────────────────────────────────────────────────────

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onClose,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 18),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AdminColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AdminColors.primary, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AdminColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AdminColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Tutup',
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminColors.infoSoft.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.info.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AdminColors.info),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AdminColors.info,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 12.5,
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

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminColors.dangerSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 17,
            color: AdminColors.danger,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AdminColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrugEditor extends StatelessWidget {
  const _DrugEditor({
    required this.index,
    required this.form,
    required this.canRemove,
    required this.enabled,
    required this.onRemove,
  });

  final int index;
  final _DrugForm form;
  final bool canRemove;
  final bool enabled;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                margin: const EdgeInsets.only(top: 9),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AdminColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AdminColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: form.name,
                  enabled: enabled,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nama obat',
                    hintText: 'mis. Furosemide',
                  ),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Nama obat wajib diisi'
                      : null,
                ),
              ),
              if (canRemove) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: IconButton(
                    tooltip: 'Hapus obat',
                    onPressed: enabled ? onRemove : null,
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 19,
                      color: AdminColors.danger,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 170,
                child: TextFormField(
                  controller: form.dose,
                  enabled: enabled,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Dosis',
                    hintText: '500 mg',
                  ),
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? 'Dosis wajib diisi' : null,
                ),
              ),
              SizedBox(
                width: 152,
                child: TextFormField(
                  controller: form.frequency,
                  enabled: enabled,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Frekuensi/hari',
                    hintText: '3',
                    suffixText: '×',
                  ),
                  validator: (value) {
                    final parsed = int.tryParse((value ?? '').trim());
                    if (parsed == null) return 'Wajib diisi';
                    if (parsed < 1 || parsed > 12) return '1–12';
                    return null;
                  },
                ),
              ),
              SizedBox(
                width: 152,
                child: TextFormField(
                  controller: form.duration,
                  enabled: enabled,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Durasi',
                    hintText: '5',
                    suffixText: 'hari',
                  ),
                  validator: (value) {
                    final parsed = int.tryParse((value ?? '').trim());
                    if (parsed == null) return 'Wajib diisi';
                    if (parsed < 1 || parsed > 365) return '1–365';
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: form.instructions,
            enabled: enabled,
            decoration: const InputDecoration(
              labelText: 'Instruksi khusus (opsional)',
              hintText: 'mis. sesudah makan, sebelum tidur',
            ),
          ),
        ],
      ),
    );
  }
}

class _DrugForm {
  _DrugForm({
    required this.name,
    required this.dose,
    required this.frequency,
    required this.duration,
    required this.instructions,
  });

  factory _DrugForm.empty() => _DrugForm(
    name: TextEditingController(),
    dose: TextEditingController(),
    frequency: TextEditingController(text: '1'),
    duration: TextEditingController(text: '1'),
    instructions: TextEditingController(),
  );

  factory _DrugForm.fromDrug(PrescriptionDrug drug) => _DrugForm(
    name: TextEditingController(text: drug.name),
    dose: TextEditingController(text: drug.dose),
    frequency: TextEditingController(text: '${drug.frequencyPerDay}'),
    duration: TextEditingController(text: '${drug.durationDays}'),
    instructions: TextEditingController(text: drug.instructions),
  );

  final TextEditingController name;
  final TextEditingController dose;
  final TextEditingController frequency;
  final TextEditingController duration;
  final TextEditingController instructions;

  PrescriptionDrug toDrug() {
    return PrescriptionDrug(
      name: name.text.trim(),
      dose: dose.text.trim(),
      frequencyPerDay: int.tryParse(frequency.text.trim()) ?? 1,
      durationDays: int.tryParse(duration.text.trim()) ?? 1,
      instructions: instructions.text.trim(),
    );
  }

  void dispose() {
    name.dispose();
    dose.dispose();
    frequency.dispose();
    duration.dispose();
    instructions.dispose();
  }
}
