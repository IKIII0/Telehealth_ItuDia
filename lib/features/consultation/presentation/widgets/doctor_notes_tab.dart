import 'package:flutter/material.dart';

import 'package:Telehealth/data/models/consultation_session.dart';

/// Tab 4 – Catatan Dokter.
///
/// Memungkinkan dokter menulis:
/// - Diagnosis utama
/// - Catatan observasi / anamnesis
/// - Daftar resep obat baru
///
/// Data disimpan via callback [onSaved] ke halaman induk.
class DoctorNotesTab extends StatefulWidget {
  const DoctorNotesTab({
    super.key,
    required this.session,
    required this.onSaved,
  });

  final ConsultationSession session;
  final Future<void> Function({
    required String diagnosis,
    required String notes,
    required List<String> medications,
  }) onSaved;

  @override
  State<DoctorNotesTab> createState() => _DoctorNotesTabState();
}

class _DoctorNotesTabState extends State<DoctorNotesTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final TextEditingController _diagnosisCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _medicationInputCtrl;
  final _formKey = GlobalKey<FormState>();

  final List<String> _medications = [];
  bool _saving = false;
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    _diagnosisCtrl = TextEditingController(
      text: widget.session.diagnosisSummary,
    );
    _notesCtrl = TextEditingController(text: widget.session.doctorNotes);
    _medicationInputCtrl = TextEditingController();
    _medications.addAll(widget.session.prescribedMedications);

    _diagnosisCtrl.addListener(() => setState(() => _isDirty = true));
    _notesCtrl.addListener(() => setState(() => _isDirty = true));
  }

  @override
  void dispose() {
    _diagnosisCtrl.dispose();
    _notesCtrl.dispose();
    _medicationInputCtrl.dispose();
    super.dispose();
  }

  void _addMedication() {
    final val = _medicationInputCtrl.text.trim();
    if (val.isEmpty) return;
    setState(() {
      _medications.add(val);
      _isDirty = true;
    });
    _medicationInputCtrl.clear();
  }

  void _removeMedication(int index) {
    setState(() {
      _medications.removeAt(index);
      _isDirty = true;
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await widget.onSaved(
        diagnosis: _diagnosisCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
        medications: List.from(_medications),
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _isDirty = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scheme = Theme.of(context).colorScheme;
    final isReadOnly = widget.session.status == ConsultationStatus.completed ||
        widget.session.status == ConsultationStatus.cancelled;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Banner jika sesi selesai ─────────────────────────────────────
          if (isReadOnly) ...[
            _ReadOnlyBanner(scheme: scheme),
            const SizedBox(height: 16),
          ],

          // ── Keluhan Pasien (read-only dari session) ──────────────────────
          _SectionCard(
            icon: Icons.report_problem_outlined,
            title: 'Keluhan Utama Pasien',
            iconColor: Colors.orange.shade700,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Text(
                widget.session.complaint,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade800,
                  height: 1.4,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Diagnosis ────────────────────────────────────────────────────
          _SectionCard(
            icon: Icons.medical_information_outlined,
            title: 'Diagnosis & Kesimpulan Klinis',
            iconColor: Colors.blue.shade700,
            child: TextFormField(
              controller: _diagnosisCtrl,
              enabled: !isReadOnly,
              maxLines: 3,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText:
                    'Contoh: Hipertensi Stage II – ganti obat ke Amlodipine 10 mg. '
                    'Pantau tekanan darah harian.',
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                filled: true,
                fillColor: isReadOnly ? Colors.grey.shade50 : Colors.white,
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      BorderSide(color: scheme.primary, width: 1.8),
                ),
              ),
              validator: (v) {
                if (!isReadOnly &&
                    (v == null || v.trim().isEmpty)) {
                  return 'Diagnosis tidak boleh kosong';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 14),

          // ── Catatan Medis ────────────────────────────────────────────────
          _SectionCard(
            icon: Icons.notes_rounded,
            title: 'Catatan Observasi & Anamnesis',
            iconColor: Colors.teal.shade700,
            child: TextFormField(
              controller: _notesCtrl,
              enabled: !isReadOnly,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText:
                    'Catat observasi fisik, anamnesis, riwayat penyakit, '
                    'rencana tindak lanjut, dan rekomendasi gaya hidup...',
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                filled: true,
                fillColor: isReadOnly ? Colors.grey.shade50 : Colors.white,
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      BorderSide(color: scheme.primary, width: 1.8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Resep Obat ───────────────────────────────────────────────────
          _SectionCard(
            icon: Icons.medication_liquid_outlined,
            title: 'Resep Obat',
            iconColor: Colors.purple.shade700,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Input tambah obat
                if (!isReadOnly) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _medicationInputCtrl,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _addMedication(),
                          decoration: InputDecoration(
                            hintText: 'Contoh: Amlodipine 10 mg 1x sehari',
                            hintStyle: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade400,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                  color: scheme.primary, width: 1.8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        onPressed: _addMedication,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.purple.shade600,
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Icon(Icons.add, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                // Daftar obat yang diresepkan
                if (_medications.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.medication_outlined,
                          size: 18,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Belum ada obat yang diresepkan',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...List.generate(_medications.length, (i) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.purple.shade100),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.medication_rounded,
                            size: 16,
                            color: Colors.purple.shade600,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _medications[i],
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          if (!isReadOnly)
                            GestureDetector(
                              onTap: () => _removeMedication(i),
                              child: Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.red.shade400,
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Tombol Simpan ────────────────────────────────────────────────
          if (!isReadOnly)
            FilledButton.icon(
              onPressed: _saving ? null : (_isDirty ? _save : null),
              style: FilledButton.styleFrom(
                backgroundColor: _isDirty
                    ? scheme.primary
                    : Colors.grey.shade400,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(
                _saving
                    ? 'Menyimpan...'
                    : (_isDirty
                        ? 'Simpan Catatan'
                        : 'Catatan Tersimpan'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Banner read-only ──────────────────────────────────────────────────────────
class _ReadOnlyBanner extends StatelessWidget {
  const _ReadOnlyBanner({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, color: Colors.blue.shade700, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Sesi ini telah selesai. Catatan tidak dapat diubah.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section card pembungkus ───────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.iconColor,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Color iconColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
