import 'package:flutter/material.dart';

class AddJournalEntryPage extends StatefulWidget {
  const AddJournalEntryPage({super.key});

  @override
  State<AddJournalEntryPage> createState() => _AddJournalEntryPageState();
}

class _AddJournalEntryPageState extends State<AddJournalEntryPage> {
  final _formKey = GlobalKey<FormState>();

  // ── Form state ──────────────────────────────────────────────────────────────
  String _type = 'Tekanan Darah';
  static const List<String> _types = [
    'Tekanan Darah',
    'Gula Darah',
    'Berat Badan',
    'Suhu Tubuh',
    'Detak Jantung',
  ];

  final _sysCtrl    = TextEditingController();
  final _diaCtrl    = TextEditingController();
  final _valueCtrl  = TextEditingController();
  final _noteCtrl   = TextEditingController();

  DateTime   _date = DateTime.now();
  TimeOfDay  _time = TimeOfDay.now();

  @override
  void dispose() {
    _sysCtrl.dispose();
    _diaCtrl.dispose();
    _valueCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  String get _unit {
    switch (_type) {
      case 'Gula Darah':    return 'mg/dL';
      case 'Berat Badan':   return 'kg';
      case 'Suhu Tubuh':    return '°C';
      case 'Detak Jantung': return 'BPM';
      default:              return '';
    }
  }

  String get _fieldLabel {
    switch (_type) {
      case 'Gula Darah':    return 'Nilai Gula Darah';
      case 'Berat Badan':   return 'Berat Badan';
      case 'Suhu Tubuh':    return 'Suhu Tubuh';
      case 'Detak Jantung': return 'Detak Jantung';
      default:              return 'Nilai';
    }
  }

  String get _dateStr =>
      '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}';

  String _timeStr(BuildContext context) => _time.format(context);

  // ── Pickers ─────────────────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData(
          colorScheme: ColorScheme.light(primary: Colors.blue.shade700),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (ctx, child) => Theme(
        data: ThemeData(
          colorScheme: ColorScheme.light(primary: Colors.blue.shade700),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _time = picked);
  }

  // ── Save ─────────────────────────────────────────────────────────────────────
  void _save() {
    if (_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Catatan berhasil disimpan!'),
          backgroundColor: Colors.green.shade600,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        title: const Text('Tambah Catatan',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Tipe catatan ───────────────────────────────────────────────
              _label('Tipe Catatan'),
              const SizedBox(height: 8),
              _dropdownField(),

              const SizedBox(height: 20),

              // ── Input nilai ────────────────────────────────────────────────
              _label('Nilai Pengukuran'),
              const SizedBox(height: 8),
              if (_type == 'Tekanan Darah') _bpFields() else _singleField(),

              const SizedBox(height: 20),

              // ── Tanggal & waktu ────────────────────────────────────────────
              _label('Tanggal & Waktu'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _datePicker(context)),
                  const SizedBox(width: 12),
                  Expanded(child: _timePicker(context)),
                ],
              ),

              const SizedBox(height: 20),

              // ── Catatan ────────────────────────────────────────────────────
              _label('Catatan (Opsional)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _noteCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText:
                      'Kondisi saat pengukuran, aktivitas sebelumnya, dll.',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.blue.shade700, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
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
      value: _type,
      decoration: _dec('Pilih tipe catatan', Icons.category_outlined),
      items: _types
          .map((t) => DropdownMenuItem(
                value: t,
                child: Text(t, style: const TextStyle(fontSize: 14)),
              ))
          .toList(),
      onChanged: (v) {
        setState(() {
          _type = v!;
          _valueCtrl.clear();
          _sysCtrl.clear();
          _diaCtrl.clear();
        });
      },
      validator: (v) => v == null ? 'Pilih tipe catatan' : null,
    );
  }

  Widget _bpFields() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _sysCtrl,
            keyboardType: TextInputType.number,
            decoration: _dec('Sistolik (mmHg)', Icons.arrow_upward),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Wajib diisi';
              if (int.tryParse(v.trim()) == null) return 'Angka saja';
              return null;
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            controller: _diaCtrl,
            keyboardType: TextInputType.number,
            decoration: _dec('Diastolik (mmHg)', Icons.arrow_downward),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Wajib diisi';
              if (int.tryParse(v.trim()) == null) return 'Angka saja';
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _singleField() {
    return TextFormField(
      controller: _valueCtrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: _dec('$_fieldLabel ($_unit)', Icons.straighten),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Wajib diisi';
        if (double.tryParse(v.trim()) == null) return 'Masukkan angka yang valid';
        return null;
      },
    );
  }

  Widget _datePicker(BuildContext context) {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today,
                color: Colors.blue.shade600, size: 18),
            const SizedBox(width: 8),
            Text(_dateStr,
                style: const TextStyle(fontSize: 14, color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  Widget _timePicker(BuildContext context) {
    return GestureDetector(
      onTap: _pickTime,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time, color: Colors.blue.shade600, size: 18),
            const SizedBox(width: 8),
            Text(_timeStr(context),
                style: const TextStyle(fontSize: 14, color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  Widget _cancelBtn(BuildContext context) {
    return OutlinedButton(
      onPressed: () => Navigator.of(context).pop(),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: BorderSide(color: Colors.blue.shade700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text('Batal',
          style: TextStyle(
              color: Colors.blue.shade700,
              fontSize: 15,
              fontWeight: FontWeight.w600)),
    );
  }

  Widget _saveBtn() {
    return ElevatedButton(
      onPressed: _save,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        backgroundColor: Colors.blue.shade700,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
      child: const Text('Simpan',
          style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold)),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700),
      );

  InputDecoration _dec(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.blue.shade600),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );
}
