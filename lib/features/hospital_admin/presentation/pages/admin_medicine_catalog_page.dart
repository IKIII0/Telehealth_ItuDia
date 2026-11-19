import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:Telehealth/core/widgets/app_dialogs.dart';
import 'package:Telehealth/core/widgets/async_state.dart';
import 'package:Telehealth/data/models/medicine_catalog.dart';
import 'package:Telehealth/data/services/medicine_service.dart';
import 'package:Telehealth/features/hospital_admin/presentation/theme/admin_theme.dart';
import 'package:Telehealth/features/hospital_admin/presentation/widgets/admin_widgets.dart';

/// Halaman 4 — Katalog Obat (opsional).
///
/// Referensi obat yang dipakai autocomplete pada form verifikasi resep.
/// Admin rumah sakit dapat menambah/mengubah entri; RLS tetap membatasi
/// penulisan hanya untuk `hospital_admin`.
class AdminMedicineCatalogPage extends StatefulWidget {
  const AdminMedicineCatalogPage({super.key});

  @override
  State<AdminMedicineCatalogPage> createState() =>
      _AdminMedicineCatalogPageState();
}

class _AdminMedicineCatalogPageState extends State<AdminMedicineCatalogPage> {
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;
  late Future<List<MedicineCatalogItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<List<MedicineCatalogItem>> _load() {
    return MedicineService.instance.fetchAll(query: _search.text.trim());
  }

  void _reload() {
    setState(() => _future = _load());
  }

  void _onSearchChanged(String _) {
    // Segarkan ikon hapus tanpa menunggu debounce.
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _reload();
    });
  }

  Future<void> _openEditor([MedicineCatalogItem? item]) async {
    final saved = await MedicineCatalogDialog.show(context, item: item);
    if (!mounted || !saved) return;
    showAppSnack(
      context,
      item == null
          ? 'Obat baru ditambahkan ke katalog'
          : 'Katalog obat diperbarui',
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) {
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
                title: 'Katalog Obat',
                subtitle:
                    'Master referensi obat pasca rawat inap. Entri di sini muncul '
                    'sebagai saran otomatis pada form verifikasi resep.',
                actions: [
                  OutlinedButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh_rounded, size: 17),
                    label: const Text('Perbarui'),
                  ),
                  FilledButton.icon(
                    onPressed: _openEditor,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Tambah obat'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              AdminPanel(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: TextField(
                  controller: _search,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Cari nama obat, zat aktif, atau kategori…',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Bersihkan',
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _search.clear();
                              _onSearchChanged('');
                            },
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FutureBuilder<List<MedicineCatalogItem>>(
                future: _future,
                builder: (context, snapshot) {
                  final loading =
                      snapshot.connectionState == ConnectionState.waiting;

                  if (snapshot.hasError) {
                    return AdminPanel(
                      child: ErrorView(
                        message: '${snapshot.error}',
                        onRetry: _reload,
                      ),
                    );
                  }

                  if (loading) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 64),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AdminColors.primary,
                        ),
                      ),
                    );
                  }

                  final items = snapshot.data ?? const <MedicineCatalogItem>[];
                  if (items.isEmpty) {
                    return AdminPanel(
                      child: AdminEmptyState(
                        icon: Icons.medication_outlined,
                        title: 'Belum ada obat di katalog',
                        message: _search.text.trim().isEmpty
                            ? 'Tambahkan referensi obat agar admin dapat '
                                  'mengisi resep lebih cepat.'
                            : 'Tidak ada obat yang cocok dengan pencarian.',
                        action: FilledButton.icon(
                          onPressed: _openEditor,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Tambah obat'),
                        ),
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final item in items) ...[
                        _CatalogCard(
                          item: item,
                          onEdit: () => _openEditor(item),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CatalogCard extends StatelessWidget {
  const _CatalogCard({required this.item, required this.onEdit});

  final MedicineCatalogItem item;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (item.genericName.isNotEmpty) item.genericName,
      if (item.category.isNotEmpty) item.category,
      if (item.dosageForm.isNotEmpty) item.dosageForm,
    ].join(' • ');

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AdminColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.medication_rounded,
              size: 19,
              color: AdminColors.primary,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.medicineName,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AdminColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AdminStatusBadge(
                      label: item.isActive ? 'Aktif' : 'Nonaktif',
                      tone: item.isActive
                          ? AdminBadgeTone.success
                          : AdminBadgeTone.neutral,
                    ),
                  ],
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    meta,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AdminColors.textMuted,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  item.defaultSummary,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AdminColors.primaryDark,
                  ),
                ),
                if (item.defaultInstructions.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.defaultInstructions,
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.4,
                      color: AdminColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Ubah obat',
            onPressed: onEdit,
            icon: const Icon(
              Icons.edit_outlined,
              size: 19,
              color: AdminColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Modal tambah/ubah entri katalog obat.
class MedicineCatalogDialog extends StatefulWidget {
  const MedicineCatalogDialog({super.key, this.item});

  final MedicineCatalogItem? item;

  static Future<bool> show(
    BuildContext context, {
    MedicineCatalogItem? item,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => MedicineCatalogDialog(item: item),
    );
    return result ?? false;
  }

  @override
  State<MedicineCatalogDialog> createState() => _MedicineCatalogDialogState();
}

class _MedicineCatalogDialogState extends State<MedicineCatalogDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _generic;
  late final TextEditingController _category;
  late final TextEditingController _form;
  late final TextEditingController _dosage;
  late final TextEditingController _frequency;
  late final TextEditingController _duration;
  late final TextEditingController _instructions;

  late bool _isActive;
  bool _submitting = false;
  String? _error;

  bool get _isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _name = TextEditingController(text: item?.medicineName ?? '');
    _generic = TextEditingController(text: item?.genericName ?? '');
    _category = TextEditingController(text: item?.category ?? '');
    _form = TextEditingController(text: item?.dosageForm ?? 'Tablet');
    _dosage = TextEditingController(text: item?.defaultDosage ?? '');
    _frequency = TextEditingController(
      text: '${item?.defaultFrequencyPerDay ?? 1}',
    );
    _duration = TextEditingController(
      text: '${item?.defaultDurationDays ?? 1}',
    );
    _instructions = TextEditingController(
      text: item?.defaultInstructions ?? '',
    );
    _isActive = item?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _generic.dispose();
    _category.dispose();
    _form.dispose();
    _dosage.dispose();
    _frequency.dispose();
    _duration.dispose();
    _instructions.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    final service = MedicineService.instance;
    try {
      final existing = widget.item;
      if (existing == null) {
        await service.createMedicine(
          MedicineCatalogDraft(
            medicineName: _name.text,
            genericName: _generic.text,
            category: _category.text,
            dosageForm: _form.text,
            defaultDosage: _dosage.text,
            defaultFrequencyPerDay: int.tryParse(_frequency.text.trim()) ?? 1,
            defaultDurationDays: int.tryParse(_duration.text.trim()) ?? 1,
            defaultInstructions: _instructions.text,
            isActive: _isActive,
          ),
        );
      } else {
        await service.updateMedicine(
          existing.copyWith(
            medicineName: _name.text.trim(),
            genericName: _generic.text.trim(),
            category: _category.text.trim(),
            dosageForm: _form.text.trim(),
            defaultDosage: _dosage.text.trim(),
            defaultFrequencyPerDay: int.tryParse(_frequency.text.trim()) ?? 1,
            defaultDurationDays: int.tryParse(_duration.text.trim()) ?? 1,
            defaultInstructions: _instructions.text.trim(),
            isActive: _isActive,
          ),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } on MedicineServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Terjadi kesalahan saat menyimpan katalog. Coba lagi.';
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
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 12, 16),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AdminColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Icons.medication_rounded,
                      size: 20,
                      color: AdminColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEditing ? 'Ubah Obat' : 'Tambah Obat',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AdminColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Nilai default dipakai untuk mengisi resep otomatis.',
                          style: TextStyle(
                            fontSize: 11.5,
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
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
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
                      TextFormField(
                        controller: _name,
                        enabled: !_submitting,
                        decoration: const InputDecoration(
                          labelText: 'Nama obat *',
                          hintText: 'mis. Amoxicillin 500 mg',
                        ),
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'Nama obat wajib diisi'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: 280,
                            child: TextFormField(
                              controller: _generic,
                              enabled: !_submitting,
                              decoration: const InputDecoration(
                                labelText: 'Nama generik / zat aktif',
                                hintText: 'mis. Amoxicillin',
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 280,
                            child: TextFormField(
                              controller: _category,
                              enabled: !_submitting,
                              decoration: const InputDecoration(
                                labelText: 'Kategori',
                                hintText: 'mis. Antibiotik',
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 280,
                            child: TextFormField(
                              controller: _form,
                              enabled: !_submitting,
                              decoration: const InputDecoration(
                                labelText: 'Bentuk sediaan',
                                hintText: 'Tablet / Kapsul / Suspensi',
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 280,
                            child: TextFormField(
                              controller: _dosage,
                              enabled: !_submitting,
                              decoration: const InputDecoration(
                                labelText: 'Dosis default',
                                hintText: 'mis. 1 Tablet',
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 135,
                            child: TextFormField(
                              controller: _frequency,
                              enabled: !_submitting,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Frekuensi',
                                suffixText: '×/hari',
                              ),
                              validator: (value) {
                                final parsed = int.tryParse(
                                  (value ?? '').trim(),
                                );
                                if (parsed == null) return 'Wajib';
                                if (parsed < 1 || parsed > 12) return '1–12';
                                return null;
                              },
                            ),
                          ),
                          SizedBox(
                            width: 135,
                            child: TextFormField(
                              controller: _duration,
                              enabled: !_submitting,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Durasi',
                                suffixText: 'hari',
                              ),
                              validator: (value) {
                                final parsed = int.tryParse(
                                  (value ?? '').trim(),
                                );
                                if (parsed == null) return 'Wajib';
                                if (parsed < 1 || parsed > 365) return '1–365';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _instructions,
                        enabled: !_submitting,
                        minLines: 2,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Instruksi default',
                          hintText: 'mis. Diminum sesudah makan',
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        value: _isActive,
                        onChanged: _submitting
                            ? null
                            : (value) => setState(() => _isActive = value),
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Aktif',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AdminColors.textPrimary,
                          ),
                        ),
                        subtitle: const Text(
                          'Obat nonaktif tidak muncul pada saran autocomplete.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AdminColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('Batal'),
                  ),
                  const SizedBox(width: 8),
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
                        : const Icon(Icons.save_rounded, size: 18),
                    label: Text(_submitting ? 'Menyimpan…' : 'Simpan'),
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
