import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:Telehealth/data/models/hospital_admin.dart';
import 'package:Telehealth/data/repositories/hospital_admin_repository.dart';
import 'package:Telehealth/features/hospital_admin/presentation/theme/admin_theme.dart';
import 'package:Telehealth/features/hospital_admin/presentation/widgets/admin_widgets.dart';

/// Hasil aksi dari [NotificationFollowUpDialog].
class NotificationFollowUpOutcome {
  const NotificationFollowUpOutcome({
    required this.sentAt,
    this.pushDelivered = false,
    this.whatsappOpened = false,
  });

  final DateTime sentAt;
  final bool pushDelivered;
  final bool whatsappOpened;
}

/// Modal "Tindak Lanjut & Kirim Pengingat" untuk satu peringatan real-time.
///
/// Admin dapat memilih target penerima (pasien dan/atau keluarga), mengedit
/// template pesan, lalu mengirim push notification atau membuka WhatsApp.
class NotificationFollowUpDialog extends StatefulWidget {
  const NotificationFollowUpDialog({
    super.key,
    required this.alert,
    required this.patient,
    this.loadMedications,
  });

  final AdherenceAlert alert;
  final MonitoredPatient patient;

  /// Pemuat nama obat (opsional) untuk melengkapi template dosis terlewat.
  final Future<List<String>> Function()? loadMedications;

  static Future<NotificationFollowUpOutcome?> show(
    BuildContext context, {
    required AdherenceAlert alert,
    required MonitoredPatient patient,
    Future<List<String>> Function()? loadMedications,
  }) {
    return showDialog<NotificationFollowUpOutcome>(
      context: context,
      barrierDismissible: false,
      builder: (_) => NotificationFollowUpDialog(
        alert: alert,
        patient: patient,
        loadMedications: loadMedications,
      ),
    );
  }

  @override
  State<NotificationFollowUpDialog> createState() =>
      _NotificationFollowUpDialogState();
}

class _NotificationFollowUpDialogState
    extends State<NotificationFollowUpDialog> {
  final TextEditingController _message = TextEditingController();

  bool _toPatient = true;
  bool _toFamily = true;
  bool _sending = false;
  bool _loadingMeds = false;
  bool _messageEdited = false;
  String? _error;
  List<String> _medications = const [];

  bool get _familyAvailable => widget.patient.hasFamilyContact;

  @override
  void initState() {
    super.initState();
    _toFamily = _familyAvailable;
    _message.text = _buildTemplate();
    _message.addListener(_onMessageChanged);
    _loadMedications();
  }

  @override
  void dispose() {
    _message.removeListener(_onMessageChanged);
    _message.dispose();
    super.dispose();
  }

  void _onMessageChanged() {
    if (!_messageEdited) _messageEdited = true;
  }

  Future<void> _loadMedications() async {
    final loader = widget.loadMedications;
    if (loader == null) return;
    setState(() => _loadingMeds = true);
    final meds = await loader();
    if (!mounted) return;
    setState(() {
      _medications = meds;
      _loadingMeds = false;
    });
    // Lengkapi template otomatis bila admin belum menyunting pesan.
    if (!_messageEdited) {
      _message.text = _buildTemplate();
      _messageEdited = false;
    }
  }

  String _buildTemplate() {
    final name = widget.patient.name;
    final date = adminFormatDateTime(widget.alert.createdAt);
    final meds = _medications.isEmpty ? 'rutin Anda' : _medications.join(', ');

    if (widget.alert.type == AlertType.missedDose) {
      return 'Halo $name/Keluarga, jadwal minum obat $meds pada $date tercatat '
          'terlewat. Mohon segera diminum sesuai anjuran dokter demi '
          'kelancaran pemulihan pasca rawat inap.';
    }
    return 'Halo $name/Keluarga, tim medis RS telah menerima laporan keluhan '
        'Anda: "${widget.alert.message}". Mohon pantau kondisi dan pastikan '
        'obat rutin tetap dikonsumsi sesuai jadwal.';
  }

  void _applyTemplate(AlertType type) {
    setState(() {
      if (type == AlertType.missedDose) {
        _message.text = _buildTemplate();
      } else {
        _message.text =
            'Halo ${widget.patient.name}/Keluarga, tim medis RS telah menerima '
            'laporan keluhan Anda: "${widget.alert.message}". Mohon pantau '
            'kondisi dan pastikan obat rutin tetap dikonsumsi sesuai jadwal.';
      }
      _messageEdited = false;
    });
  }

  String get _recipientTarget {
    if (_toPatient && _toFamily) return 'both';
    if (_toFamily) return 'family';
    return 'patient';
  }

  Future<void> _sendPush() async {
    if (_sending) return;
    if (!_toPatient && !_toFamily) {
      setState(() => _error = 'Pilih minimal satu penerima notifikasi.');
      return;
    }
    if (_message.text.trim().isEmpty) {
      setState(() => _error = 'Isi pesan pengingat wajib diisi.');
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      final result = await HospitalAdminRepository.instance
          .sendPatientNotification(
            patientUid: widget.patient.patientUid.isNotEmpty
                ? widget.patient.patientUid
                : widget.patient.id,
            alertReferenceId: widget.alert.id,
            recipientTarget: _recipientTarget,
            deliveryChannel: 'push_notification',
            title: _title,
            message: _message.text.trim(),
            sendPush: true,
          );
      if (!mounted) return;
      Navigator.of(context).pop(
        NotificationFollowUpOutcome(
          sentAt: result.sentAt,
          pushDelivered: result.pushDelivered,
        ),
      );
    } on HospitalAdminException catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = 'Terjadi kesalahan. Coba lagi.';
      });
    }
  }

  Future<void> _sendWhatsApp() async {
    if (_sending) return;
    final phone = _normalizePhone(widget.patient.familyPhone);
    if (phone.isEmpty) {
      setState(
        () => _error =
            'Nomor WhatsApp keluarga belum terdaftar untuk pasien '
            'ini.',
      );
      return;
    }
    if (_message.text.trim().isEmpty) {
      setState(() => _error = 'Isi pesan pengingat wajib diisi.');
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    final uri = Uri.parse(
      'https://wa.me/$phone?text=${Uri.encodeComponent(_message.text.trim())}',
    );

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw const HospitalAdminException(
          'Tidak dapat membuka WhatsApp. Periksa browser/izin perangkat.',
        );
      }

      // Catat sebagai log tindak lanjut via jalur WhatsApp.
      final result = await HospitalAdminRepository.instance
          .sendPatientNotification(
            patientUid: widget.patient.patientUid.isNotEmpty
                ? widget.patient.patientUid
                : widget.patient.id,
            alertReferenceId: widget.alert.id,
            recipientTarget: 'family',
            deliveryChannel: 'whatsapp_link',
            title: _title,
            message: _message.text.trim(),
            sendPush: false,
          );
      if (!mounted) return;
      Navigator.of(context).pop(
        NotificationFollowUpOutcome(
          sentAt: result.sentAt,
          whatsappOpened: true,
        ),
      );
    } on HospitalAdminException catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = 'Gagal membuka WhatsApp. Coba lagi.';
      });
    }
  }

  String get _title => widget.alert.type == AlertType.missedDose
      ? 'Pengingat Jadwal Minum Obat'
      : 'Tindak Lanjut Keluhan Pasien';

  String _normalizePhone(String raw) {
    var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    if (digits.startsWith('0')) {
      digits = '62${digits.substring(1)}';
    } else if (digits.startsWith('8')) {
      digits = '62$digits';
    }
    return digits;
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = widget.alert.isCritical
        ? AdminColors.danger
        : AdminColors.warning;

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      backgroundColor: AdminColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
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
                      Icons.notifications_active_rounded,
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
                          'Tindak Lanjut & Kirim Pengingat',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AdminColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.patient.name,
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
                    onPressed: _sending
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
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
                    _ContextCard(
                      alert: widget.alert,
                      patient: widget.patient,
                      statusColor: statusColor,
                    ),
                    const SizedBox(height: 20),
                    const _SectionLabel('Penerima Notifikasi'),
                    const SizedBox(height: 8),
                    _RecipientTile(
                      value: _toPatient,
                      enabled: !_sending,
                      icon: Icons.person_outline_rounded,
                      title: 'Kirim ke HP Pasien',
                      subtitle: 'Push notification ke aplikasi pasien',
                      onChanged: (value) => setState(() => _toPatient = value),
                    ),
                    _RecipientTile(
                      value: _toFamily,
                      enabled: !_sending && _familyAvailable,
                      icon: Icons.family_restroom_rounded,
                      title: 'Kirim ke HP Keluarga / Wali Pasien',
                      subtitle: _familyAvailable
                          ? [
                              if (widget.patient.familyName.isNotEmpty)
                                widget.patient.familyName,
                              if (widget.patient.familyPhone.isNotEmpty)
                                widget.patient.familyPhone,
                            ].join(' • ')
                          : 'Kontak keluarga belum terdaftar',
                      onChanged: (value) => setState(() => _toFamily = value),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const _SectionLabel('Template Pesan Pengingat'),
                        const Spacer(),
                        if (_loadingMeds)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AdminColors.primary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          avatar: const Icon(
                            Icons.alarm_off_rounded,
                            size: 15,
                            color: AdminColors.danger,
                          ),
                          label: const Text('Template Dosis Terlewat'),
                          onPressed: _sending
                              ? null
                              : () => _applyTemplate(AlertType.missedDose),
                        ),
                        ActionChip(
                          avatar: const Icon(
                            Icons.report_problem_outlined,
                            size: 15,
                            color: AdminColors.warning,
                          ),
                          label: const Text('Template Keluhan Pasien'),
                          onPressed: _sending
                              ? null
                              : () => _applyTemplate(AlertType.complaint),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _message,
                      enabled: !_sending,
                      minLines: 4,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        labelText: 'Isi pesan',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 15,
                          color: AdminColors.textMuted,
                        ),
                        SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            'Push notification dikirim ke aplikasi pasien dan/atau '
                            'keluarga. Gunakan WhatsApp sebagai jalur cadangan '
                            'bila keluarga belum memasang aplikasi.',
                            style: TextStyle(
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
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.end,
                children: [
                  TextButton(
                    onPressed: _sending
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Batal'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _sending || !_familyAvailable
                        ? null
                        : _sendWhatsApp,
                    icon: const Icon(Icons.chat_rounded, size: 17),
                    label: const Text('Kirim via WhatsApp Keluarga'),
                  ),
                  FilledButton.icon(
                    onPressed: _sending ? null : _sendPush,
                    icon: _sending
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
                      _sending ? 'Mengirim…' : 'Kirim Notifikasi Aplikasi',
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

class _ContextCard extends StatelessWidget {
  const _ContextCard({
    required this.alert,
    required this.patient,
    required this.statusColor,
  });

  final AdherenceAlert alert;
  final MonitoredPatient patient;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminColors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AdminStatusBadge(
                label: alert.type.label,
                tone: alert.isCritical
                    ? AdminBadgeTone.danger
                    : AdminBadgeTone.warning,
              ),
              const SizedBox(width: 8),
              Text(
                adminFormatDateTime(alert.createdAt),
                style: const TextStyle(
                  fontSize: 11,
                  color: AdminColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Pasien: ${patient.name}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AdminColors.textPrimary,
            ),
          ),
          if (patient.medicalRecordNo.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'No. RM ${patient.medicalRecordNo}',
              style: const TextStyle(
                fontSize: 11.5,
                color: AdminColors.textMuted,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            alert.message,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: AdminColors.textPrimary,
            ),
          ),
          if (patient.familyName.isNotEmpty ||
              patient.familyPhone.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.contact_phone_outlined,
                  size: 14,
                  color: statusColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    [
                      if (patient.familyName.isNotEmpty) patient.familyName,
                      if (patient.familyPhone.isNotEmpty) patient.familyPhone,
                    ].join(' • '),
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AdminColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: AdminColors.textPrimary,
      ),
    );
  }
}

class _RecipientTile extends StatelessWidget {
  const _RecipientTile({
    required this.value,
    required this.enabled,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onChanged,
  });

  final bool value;
  final bool enabled;
  final IconData icon;
  final String title;
  final String subtitle;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? () => onChanged(!value) : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: value && enabled
              ? AdminColors.primary.withValues(alpha: 0.06)
              : AdminColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value && enabled ? AdminColors.primary : AdminColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: enabled ? AdminColors.primary : AdminColors.textMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: enabled
                          ? AdminColors.textPrimary
                          : AdminColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AdminColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Checkbox(
              value: value,
              onChanged: enabled
                  ? (checked) => onChanged(checked ?? false)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
