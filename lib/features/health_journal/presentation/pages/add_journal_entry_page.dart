import 'package:flutter/material.dart';

import 'package:telehealth_app/core/widgets/app_dialogs.dart';
import 'package:telehealth_app/data/models/journal.dart';
import 'package:telehealth_app/data/repositories/journal_repository.dart';

class AddJournalEntryPage extends StatefulWidget {
  const AddJournalEntryPage({super.key, this.entry});

  /// Bila tidak null, form berjalan dalam mode edit.
  final JournalEntry? entry;

  @override
  State<AddJournalEntryPage> createState() => _AddJournalEntryPageState();
}

class _AddJournalEntryPageState extends State<AddJournalEntryPage> {
  final _formKey = GlobalKey<FormState>();

  late final List<JournalCategory> _categories;
  late String _categoryId;

  final _sysCtrl = TextEditingController();
  final _diaCtrl = TextEditingController();
  final _valueCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  late DateTime _date;
  late TimeOfDay _time;
  bool _submitting = false;

  bool get _isEditing => widget.entry != null;

  JournalCategory get _category {
    for (final c in _categories) {
      if (c.id == _categoryId) return c;
    }
    return _categories.first;
  }

  @override
  void initState() {
    super.initState();
    _categories = JournalRepository.instance.categories;

    final entry = widget.entry;
    _categoryId = entry?.categoryId ?? _categories.first.id;

    if (entry != null) {
      _date = entry.date;
      _time = TimeOfDay.fromDateTime(entry.date);
      _noteCtrl.text = entry.note;
      if (_category.isPressure) {
        _sysCtrl.text = (entry.systolic ?? entry.value.toInt()).toString();
        _diaCtrl.text = (entry.diastolic ?? 0).toString();
      } else {
        _valueCtrl.text = _formatInitial(entry.value);
      }
    } else {
      _date = DateTime.now();
      _time = TimeOfDay.now();
    }
  }

  @override
  void dispose() {
    _sysCtrl.dispose();
    _diaCtrl.dispose();
    _valueCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  String _formatInitial(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  String _formatNumber(num v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  String get _dateStr =>
      '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}';

  String _timeStr(BuildContext context) => _time.format(context);

  /// Rentang nilai wajar per kategori untuk validasi.
  (double, double) _valueRange(JournalCategory c) {
    switch (c.id) {
      case 'cat1':
        return (60, 260);
      case 'cat2':
        return (20, 600);
      case 'cat3':
        return (20, 300);
      case 'cat4':
        return (30, 45);
      case 'cat5':
        return (30, 250);
      default:
        return (0, double.infinity);
    }
  }

  String _computeStatus(JournalCategory c, double value, {int? sys, int? dia}) {
    switch (c.id) {
      case 'cat1':
        final s = sys ?? value.toInt();
        final d = dia ?? 0;
        return (s > 130 || d > 85) ? 'Perhatian' : 'Normal';
      case 'cat2':
        return value > 140 ? 'Perhatian' : 'Normal';
      case 'cat4':
        return (value < 36 || value > 37.5) ? 'Perhatian' : 'Normal';
      case 'cat5':
        return (value < 60 || value > 100) ? 'Perhatian' : 'Normal';
      default:
        return 'Normal';
    }
  }

  // ── Pickers ─────────────────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  // ── Save ─────────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    final category = _category;
    final int? sys = category.isPressure
        ? int.tryParse(_sysCtrl.text.trim())
        : null;
    final int? dia = category.isPressure
        ? int.tryParse(_diaCtrl.text.trim())
        : null;
    final double value = category.isPressure
        ? (sys ?? 0).toDouble()
        : double.parse(_valueCtrl.text.trim());
    final status = _computeStatus(category, value, sys: sys, dia: dia);
    final date = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );
    final note = _noteCtrl.text.trim();

    try {
      if (_isEditing) {
        await JournalRepository.instance.update(
          JournalEntry(
            id: widget.entry!.id,
            categoryId: category.id,
            value: value,
            date: date,
            status: status,
            systolic: sys,
            diastolic: dia,
            note: note,
          ),
        );
      } else {
        await JournalRepository.instance.create(
          JournalEntry(
            id: '',
            categoryId: category.id,
            value: value,
            date: date,
            status: status,
            systolic: sys,
            diastolic: dia,
            note: note,
          ),
        );
      }
      if (!mounted) return;
      showAppSnack(context, 'Catatan berhasil disimpan');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showAppSnack(
        context,
        'Gagal menyimpan catatan, coba lagi',
        success: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Catatan' : 'Tambah Catatan'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Kategori ───────────────────────────────────────────────────
              _label('Kategori Catatan'),
              const SizedBox(height: 8),
              _dropdownField(),

              const SizedBox(height: 20),

              // ── Nilai pengukuran ───────────────────────────────────────────
              _label('Nilai Pengukuran'),
              const SizedBox(height: 8),
              if (_category.isPressure) _bpFields() else _singleField(),

              const SizedBox(height: 20),

              // ── Tanggal & waktu ────────────────────────────────────────────
              _label('Tanggal & Waktu'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _pickerTile(
                      icon: Icons.calendar_today,
                      text: _dateStr,
                      onTap: _submitting ? null : _pickDate,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _pickerTile(
                      icon: Icons.access_time,
                      text: _timeStr(context),
                      onTap: _submitting ? null : _pickTime,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Catatan ────────────────────────────────────────────────────
              _label('Catatan (Opsional)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _noteCtrl,
                maxLines: 3,
                enabled: !_submitting,
                decoration: _dec(
                  'Kondisi saat pengukuran, aktivitas sebelumnya, dll.',
                  Icons.notes_outlined,
                ),
                validator: (v) {
                  if ((v ?? '').length > 200) {
                    return 'Catatan maksimal 200 karakter';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 28),

              // ── Buttons ────────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(child: _cancelBtn(context)),
                  const SizedBox(width: 12),
                  Expanded(child: _saveBtn()),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ── Widget builders ──────────────────────────────────────────────────────────
  Widget _dropdownField() {
    return DropdownButtonFormField<String>(
      initialValue: _categoryId,
      decoration: _dec('Pilih kategori catatan', Icons.category_outlined),
      items: _categories
          .map(
            (c) => DropdownMenuItem(
              value: c.id,
              child: Text(c.name, style: const TextStyle(fontSize: 14)),
            ),
          )
          .toList(),
      onChanged: _submitting
          ? null
          : (v) {
              setState(() {
                _categoryId = v!;
                _valueCtrl.clear();
                _sysCtrl.clear();
                _diaCtrl.clear();
              });
            },
      validator: (v) => v == null ? 'Pilih kategori catatan' : null,
    );
  }

  Widget _bpFields() {
    final unit = _category.unit;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextFormField(
            controller: _sysCtrl,
            keyboardType: TextInputType.number,
            enabled: !_submitting,
            decoration: _dec('Sistolik ($unit)', Icons.arrow_upward),
            validator: (v) => _validateNumber(
              v,
              label: 'Sistolik',
              min: 60,
              max: 260,
              unit: unit,
              integer: true,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            controller: _diaCtrl,
            keyboardType: TextInputType.number,
            enabled: !_submitting,
            decoration: _dec('Diastolik ($unit)', Icons.arrow_downward),
            validator: (v) {
              final base = _validateNumber(
                v,
                label: 'Diastolik',
                min: 30,
                max: 200,
                unit: unit,
                integer: true,
              );
              if (base != null) return base;
              final dia = int.tryParse(v!.trim());
              final sys = int.tryParse(_sysCtrl.text.trim());
              if (dia != null && sys != null && dia >= sys) {
                return 'Diastolik harus lebih kecil';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _singleField() {
    final c = _category;
    final range = _valueRange(c);
    return TextFormField(
      controller: _valueCtrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      enabled: !_submitting,
      decoration: _dec('${c.name} (${c.unit})', Icons.straighten),
      validator: (v) => _validateNumber(
        v,
        label: c.name,
        min: range.$1,
        max: range.$2,
        unit: c.unit,
      ),
    );
  }

  String? _validateNumber(
    String? v, {
    required String label,
    required double min,
    required double max,
    required String unit,
    bool integer = false,
  }) {
    final text = (v ?? '').trim();
    if (text.isEmpty) return '$label wajib diisi';
    final parsed = integer ? int.tryParse(text) : double.tryParse(text);
    if (parsed == null) {
      return integer ? 'Masukkan angka bulat' : 'Masukkan angka yang valid';
    }
    final value = parsed.toDouble();
    if (value < min || value > max) {
      return '$label harus ${_formatNumber(min)} - ${_formatNumber(max)} $unit';
    }
    return null;
  }

  Widget _pickerTile({
    required IconData icon,
    required String text,
    required VoidCallback? onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: scheme.primary),
        ),
        child: Text(text, style: const TextStyle(fontSize: 14)),
      ),
    );
  }

  Widget _cancelBtn(BuildContext context) {
    return OutlinedButton(
      onPressed: _submitting ? null : () => Navigator.of(context).pop(),
      child: const Text('Batal'),
    );
  }

  Widget _saveBtn() {
    return ElevatedButton(
      onPressed: _submitting ? null : _save,
      child: _submitting
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(_isEditing ? 'Simpan Perubahan' : 'Simpan'),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: Colors.grey.shade700,
    ),
  );

  InputDecoration _dec(String hint, IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: scheme.primary),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    );
  }
}
