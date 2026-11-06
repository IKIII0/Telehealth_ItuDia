import 'package:flutter/material.dart';

import 'package:Telehealth/data/repositories/hospital_admin_repository.dart';
import 'package:Telehealth/features/hospital_admin/presentation/theme/admin_theme.dart';

/// Modal untuk mencatat tindakan tindak lanjut admin terhadap pasien.
///
/// Bila [reportId] diisi (keluhan pasien), laporan terkait otomatis ditutup
/// oleh RPC `hospital_record_follow_up`.
class FollowUpDialog extends StatefulWidget {
  const FollowUpDialog({
    super.key,
    required this.patientId,
    required this.patientName,
    this.reportId,
    this.prescriptionId,
  });

  final String patientId;
  final String patientName;
  final String? reportId;
  final String? prescriptionId;

  static Future<bool> show(
    BuildContext context, {
    required String patientId,
    required String patientName,
    String? reportId,
    String? prescriptionId,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => FollowUpDialog(
        patientId: patientId,
        patientName: patientName,
        reportId: reportId,
        prescriptionId: prescriptionId,
      ),
    );
    return result ?? false;
  }

  @override
  State<FollowUpDialog> createState() => _FollowUpDialogState();
}

class _FollowUpDialogState extends State<FollowUpDialog> {
  static const List<String> _actions = [
    'Telepon pasien',
    'Hubungi dokter penanggung jawab',
    'Kunjungan rumah',
    'Edukasi kepatuhan obat',
    'Lainnya',
  ];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _note = TextEditingController();

  String _action = _actions.first;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await HospitalAdminRepository.instance.recordFollowUp(
        patientId: widget.patientId,
        action: _action,
        note: _note.text.trim(),
        reportId: widget.reportId,
        prescriptionId: widget.prescriptionId,
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
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: AdminColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
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
                    child: const Icon(
                      Icons.support_agent_rounded,
                      color: AdminColors.primary,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Catat Tindak Lanjut',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AdminColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.patientName,
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
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
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
                      if (_error != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AdminColors.dangerSoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AdminColors.danger,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      DropdownButtonFormField<String>(
                        initialValue: _action,
                        decoration: const InputDecoration(
                          labelText: 'Jenis tindakan',
                        ),
                        items: [
                          for (final action in _actions)
                            DropdownMenuItem<String>(
                              value: action,
                              child: Text(
                                action,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                        ],
                        onChanged: _submitting
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() => _action = value);
                                }
                              },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _note,
                        enabled: !_submitting,
                        minLines: 3,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: 'Catatan tindak lanjut',
                          alignLabelWithHint: true,
                          hintText:
                              'Contoh: pasien dihubungi, diingatkan meminum '
                              'obat malam dan kontrol pada 12 Mei.',
                        ),
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'Catatan tindak lanjut wajib diisi'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 15,
                            color: AdminColors.textMuted,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              widget.reportId == null
                                  ? 'Tindakan ini tercatat pada riwayat pasien.'
                                  : 'Laporan pasien terkait akan otomatis '
                                        'ditandai selesai.',
                              style: const TextStyle(
                                fontSize: 11.5,
                                height: 1.4,
                                color: AdminColors.textMuted,
                              ),
                            ),
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
                        : const Icon(Icons.save_outlined, size: 17),
                    label: Text(
                      _submitting ? 'Menyimpan…' : 'Simpan Tindak Lanjut',
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
