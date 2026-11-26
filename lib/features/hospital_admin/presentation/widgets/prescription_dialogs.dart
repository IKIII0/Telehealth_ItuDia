import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:Telehealth/data/models/hospital_admin.dart';
import 'package:Telehealth/data/models/medicine_catalog.dart';
import 'package:Telehealth/data/repositories/hospital_admin_repository.dart';
import 'package:Telehealth/features/hospital_admin/presentation/theme/admin_theme.dart';
import 'package:Telehealth/features/hospital_admin/presentation/widgets/medicine_dropdown_field.dart';

/// Jam default proporsional sesuai jumlah frekuensi per hari.
///
/// Samakan dengan `app.default_scheduled_times(int)` di SQL agar jadwal awal
/// konsisten antara UI dan database.
List<String> defaultScheduledTimes(int frequency) {
  final freq = frequency.clamp(1, 12);
  if (freq == 1) return ['08:00'];
  if (freq == 2) return ['07:00', '19:00'];
  if (freq == 3) return ['07:00', '15:00', '23:00'];

  // >= 4: sebarkan merata mulai 07:00 dengan interval 24/jumlah jam.
  final step = 1440 ~/ freq;
  return List<String>.generate(freq, (index) {
    final minutes = (7 * 60 + index * step) % 1440;
    final hour = (minutes ~/ 60).toString().padLeft(2, '0');
    final minute = (minutes % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  });
}

String _formatTimeOfDay(TimeOfDay time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

TimeOfDay? _parseTimeOfDay(String raw) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(raw.trim());
  if (match == null) return null;
  final hour = int.tryParse(match.group(1)!);
  final minute = int.tryParse(match.group(2)!);
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

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

    // Pastikan seluruh slot jam minum obat terisi sebelum diproses.
    for (var index = 0; index < _drugs.length; index++) {
      if (!_drugs[index].hasCompleteSchedules) {
        setState(() {
          _error =
              'Lengkapi jam minum obat obat nomor ${index + 1} sesuai jumlah '
              'frekuensi per hari.';
        });
        return;
      }
    }

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

class _DrugEditor extends StatefulWidget {
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
  State<_DrugEditor> createState() => _DrugEditorState();
}

class _DrugEditorState extends State<_DrugEditor> {
  /// Dipanggil saat admin memilih frekuensi dari dropdown.
  void _changeFrequency(int? value) {
    setState(() {
      widget.form.frequencyCount = value;
      widget.form.syncScheduledTimes();
    });
  }

  /// Mengisi field obat dari nilai default katalog. Semua field tetap dapat
  /// diedit admin untuk penyesuaian khusus.
  void _applyCatalogDefaults(_DrugForm form, MedicineCatalogItem item) {
    if (item.defaultDosage.isNotEmpty) {
      form.dose.text = item.defaultDosage;
    }
    form.frequencyCount = item.defaultFrequencyPerDay.clamp(1, 12);
    form.duration.text = '${item.defaultDurationDays}';
    form.instructions.text = item.defaultInstructions;
    form.regenerateScheduledTimes();
    setState(() {});
  }

  Future<void> _pickTime(int slot) async {
    final form = widget.form;
    if (slot >= form.scheduledTimes.length) return;

    final initial =
        _parseTimeOfDay(form.scheduledTimes[slot]) ??
        const TimeOfDay(hour: 8, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: 'Pilih jam minum obat',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;

    setState(() {
      form.scheduledTimes[slot] = _formatTimeOfDay(picked);
    });
  }

  @override
  Widget build(BuildContext context) {
    final form = widget.form;
    final enabled = widget.enabled;
    final slots = form.scheduledTimes;

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
                  '${widget.index + 1}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AdminColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MedicineDropdownField(
                  controller: form.name,
                  enabled: enabled,
                  labelText: 'Nama obat',
                  hintText: 'Pilih obat dari katalog…',
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Nama obat wajib diisi'
                      : null,
                  onSelected: (item) => _applyCatalogDefaults(form, item),
                ),
              ),
              if (widget.canRemove) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: IconButton(
                    tooltip: 'Hapus obat',
                    onPressed: enabled ? widget.onRemove : null,
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
                width: 190,
                child: DropdownButtonFormField<int>(
                  key: ValueKey<String>('freq-${form.frequencyCount}'),
                  initialValue: form.frequencyCount,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Frekuensi minum',
                  ),
                  hint: const Text(
                    'Pilih frekuensi',
                    style: TextStyle(fontSize: 13),
                  ),
                  items: [
                    for (var value = 1; value <= 12; value++)
                      DropdownMenuItem<int>(
                        value: value,
                        child: Text(
                          '$value kali sehari',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                  ],
                  onChanged: enabled ? _changeFrequency : null,
                  validator: (value) =>
                      value == null ? 'Pilih frekuensi' : null,
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
          if (form.frequencyCount != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 15,
                  color: AdminColors.primary,
                ),
                const SizedBox(width: 6),
                const Text(
                  'Jadwal minum obat',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AdminColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${slots.length} slot',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AdminColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            const Text(
              'Ketuk jam untuk menyesuaikan dengan anjuran dokter '
              '(mis. sebelum makan).',
              style: TextStyle(
                fontSize: 11,
                height: 1.4,
                color: AdminColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var slot = 0; slot < slots.length; slot++)
                  _TimeSlotButton(
                    label: slots[slot],
                    enabled: enabled,
                    onTap: () => _pickTime(slot),
                  ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 12),
            const Text(
              'Pilih frekuensi minum terlebih dahulu untuk mengatur jam minum obat.',
              style: TextStyle(
                fontSize: 11,
                height: 1.4,
                color: AdminColors.textMuted,
              ),
            ),
          ],
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

/// Tombol jam minum obat yang membuka TimePicker saat diketuk.
class _TimeSlotButton extends StatelessWidget {
  const _TimeSlotButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: enabled ? onTap : null,
      icon: const Icon(Icons.access_time_rounded, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

class _DrugForm {
  _DrugForm({
    required this.name,
    required this.dose,
    required this.duration,
    required this.instructions,
    this.frequencyCount,
    List<String>? scheduledTimes,
  }) : scheduledTimes = List<String>.from(scheduledTimes ?? const []);

  factory _DrugForm.empty() => _DrugForm(
    name: TextEditingController(),
    dose: TextEditingController(),
    duration: TextEditingController(text: '1'),
    instructions: TextEditingController(),
  );

  factory _DrugForm.fromDrug(PrescriptionDrug drug) {
    final count = (drug.frequencyPerDay >= 1 && drug.frequencyPerDay <= 12)
        ? drug.frequencyPerDay
        : 1;
    return _DrugForm(
      name: TextEditingController(text: drug.name),
      dose: TextEditingController(text: drug.dose),
      duration: TextEditingController(text: '${drug.durationDays}'),
      instructions: TextEditingController(text: drug.instructions),
      frequencyCount: count,
      scheduledTimes: drug.scheduledTimes.isNotEmpty
          ? drug.scheduledTimes
          : defaultScheduledTimes(count),
    );
  }

  final TextEditingController name;
  final TextEditingController dose;
  final TextEditingController duration;
  final TextEditingController instructions;

  /// Frekuensi minum per hari (1–12). `null` = admin belum memilih.
  int? frequencyCount;

  /// Jam minum obat; panjangnya mengikuti [frequencyCount].
  List<String> scheduledTimes;

  /// Sesuaikan jumlah slot tanpa menghapus jam yang sudah diatur admin.
  void syncScheduledTimes() {
    final count = frequencyCount;
    if (count == null) {
      scheduledTimes = [];
      return;
    }
    final defaults = defaultScheduledTimes(count);
    final previous = List<String>.of(scheduledTimes);
    scheduledTimes = List<String>.generate(count, (index) {
      if (index < previous.length && previous[index].trim().isNotEmpty) {
        return previous[index];
      }
      return defaults[index];
    });
  }

  /// Reset seluruh slot ke jam default (mis. setelah memilih katalog obat).
  void regenerateScheduledTimes() {
    final count = frequencyCount;
    scheduledTimes = count == null ? [] : defaultScheduledTimes(count);
  }

  /// `true` bila frekuensi sudah dipilih, jumlah slot sama, dan jamnya valid.
  bool get hasCompleteSchedules {
    final count = frequencyCount;
    if (count == null || count < 1) return false;
    if (scheduledTimes.length != count) return false;
    return scheduledTimes.every((time) => _parseTimeOfDay(time) != null);
  }

  PrescriptionDrug toDrug() {
    return PrescriptionDrug(
      name: name.text.trim(),
      dose: dose.text.trim(),
      frequencyPerDay: frequencyCount ?? 1,
      durationDays: int.tryParse(duration.text.trim()) ?? 1,
      instructions: instructions.text.trim(),
      scheduledTimes: List<String>.of(scheduledTimes),
    );
  }

  void dispose() {
    name.dispose();
    dose.dispose();
    duration.dispose();
    instructions.dispose();
  }
}
