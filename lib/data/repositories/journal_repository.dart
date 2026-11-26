import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_config.dart';
import '../models/journal.dart';
import 'auth_repository.dart';
import 'simulated_api.dart';

/// Repository jurnal kesehatan pasien.
///
/// Bila Supabase aktif, entri disimpan di `patient_vital_records` sehingga
/// dokter dapat membacanya di tab "Riwayat Medis". Tanpa koneksi, repository
/// memakai data simulasi lokal.
class JournalRepository {
  JournalRepository._() {
    _seed();
  }

  static final JournalRepository instance = JournalRepository._();

  int _counter = 0;

  final List<JournalCategory> _categories = const [
    JournalCategory(
      id: 'cat1',
      name: 'Tekanan Darah',
      unit: 'mmHg',
      isPressure: true,
    ),
    JournalCategory(id: 'cat2', name: 'Gula Darah', unit: 'mg/dL'),
    JournalCategory(id: 'cat3', name: 'Berat Badan', unit: 'kg'),
    JournalCategory(id: 'cat4', name: 'Suhu Tubuh', unit: '°C'),
    JournalCategory(id: 'cat5', name: 'Detak Jantung', unit: 'BPM'),
  ];

  /// Pemetaan kategori jurnal → metrik `patient_vital_records`.
  static const Map<String, String> _metricByCategory = {
    'cat1': 'blood_pressure',
    'cat2': 'blood_sugar',
    'cat3': 'weight',
    'cat4': 'body_temperature',
    'cat5': 'heart_rate',
  };

  static const Map<String, String> _categoryByMetric = {
    'blood_pressure': 'cat1',
    'blood_sugar': 'cat2',
    'weight': 'cat3',
    'body_temperature': 'cat4',
    'heart_rate': 'cat5',
  };

  final List<JournalEntry> _entries = [];

  List<JournalCategory> get categories => List.unmodifiable(_categories);

  JournalCategory categoryById(String id) => _categories.firstWhere(
    (c) => c.id == id,
    orElse: () => _categories.first,
  );

  SupabaseClient? get _db =>
      SupabaseConfig.firebaseAuthClient ?? SupabaseConfig.client;

  String? get _uid => AuthRepository.instance.currentUser?.id;

  bool get isRemote {
    final db = _db;
    return db != null && _uid != null;
  }

  JournalEntry _entryFromRow(Map<String, dynamic> row) {
    final metric = row['metric']?.toString() ?? '';
    final categoryId = _categoryByMetric[metric] ?? 'cat1';
    final value = (row['value'] as num?)?.toDouble() ?? 0;
    final secondary = (row['secondary_value'] as num?)?.toInt();
    return JournalEntry(
      id: row['id'].toString(),
      categoryId: categoryId,
      value: value,
      date:
          DateTime.tryParse(row['recorded_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      status: switch (row['status']?.toString()) {
        'warning' => 'Perhatian',
        'critical' => 'Kritis',
        _ => 'Normal',
      },
      systolic: categoryId == 'cat1' ? value.toInt() : null,
      diastolic: categoryId == 'cat1' ? secondary : null,
      note: row['note']?.toString() ?? '',
    );
  }

  Map<String, dynamic> _rowFromEntry(JournalEntry entry, String uid) {
    final category = categoryById(entry.categoryId);
    return {
      'patient_user_id': uid,
      'metric': _metricByCategory[entry.categoryId] ?? 'blood_pressure',
      'value': entry.value,
      'secondary_value': entry.categoryId == 'cat1' ? entry.diastolic : null,
      'unit': category.unit,
      'status': switch (entry.status) {
        'Kritis' => 'critical',
        'Perhatian' => 'warning',
        _ => 'normal',
      },
      'note': entry.note,
      'recorded_at': entry.date.toUtc().toIso8601String(),
    };
  }

  void _seed() {
    // 7 entri tekanan darah
    const bp = <(int, int, String, String)>[
      (120, 80, 'Normal', 'Setelah istirahat'),
      (135, 88, 'Perhatian', 'Setelah olahraga'),
      (118, 78, 'Normal', 'Pagi hari'),
      (122, 82, 'Normal', 'Sebelum makan'),
      (140, 90, 'Perhatian', 'Stres kerja'),
      (119, 79, 'Normal', 'Setelah meditasi'),
      (126, 84, 'Normal', 'Setelah bangun tidur'),
    ];
    for (var i = 0; i < bp.length; i++) {
      final e = bp[i];
      _entries.add(
        JournalEntry(
          id: 'je_bp_$i',
          categoryId: 'cat1',
          systolic: e.$1,
          diastolic: e.$2,
          value: e.$1.toDouble(),
          date: DateTime(2024, 9, 20 + i),
          status: e.$3,
          note: e.$4,
        ),
      );
    }

    // 7 entri gula darah
    const bs = <(double, String, String)>[
      (95, 'Normal', 'Puasa pagi'),
      (140, 'Perhatian', '2 jam setelah makan'),
      (98, 'Normal', 'Puasa pagi'),
      (105, 'Normal', 'Sebelum sarapan'),
      (155, 'Perhatian', 'Setelah makan besar'),
      (92, 'Normal', 'Puasa pagi'),
      (101, 'Normal', 'Sebelum tidur'),
    ];
    for (var i = 0; i < bs.length; i++) {
      final e = bs[i];
      _entries.add(
        JournalEntry(
          id: 'je_bs_$i',
          categoryId: 'cat2',
          value: e.$1,
          date: DateTime(2024, 9, 20 + i),
          status: e.$2,
          note: e.$3,
        ),
      );
    }

    // 7 entri berat badan
    const wt = <(double, String)>[
      (65.5, 'Pagi hari'),
      (65.8, 'Setelah makan'),
      (65.2, 'Setelah olahraga'),
      (65.6, 'Pagi hari'),
      (66.0, 'Malam hari'),
      (65.4, 'Pagi hari'),
      (65.3, 'Setelah bangun tidur'),
    ];
    for (var i = 0; i < wt.length; i++) {
      final e = wt[i];
      _entries.add(
        JournalEntry(
          id: 'je_wt_$i',
          categoryId: 'cat3',
          value: e.$1,
          date: DateTime(2024, 9, 20 + i),
          status: 'Normal',
          note: e.$2,
        ),
      );
    }
  }

  Future<List<JournalCategory>> fetchCategories({bool simulateError = false}) {
    return SimulatedApi.run(
      () => List.unmodifiable(_categories),
      simulateError: simulateError,
    );
  }

  Future<List<JournalEntry>> fetchEntries({bool simulateError = false}) async {
    final db = _db;
    final uid = _uid;
    if (db == null || uid == null) {
      return SimulatedApi.run(
        () => List<JournalEntry>.of(_entries),
        simulateError: simulateError,
      );
    }

    final data = await db
        .from('patient_vital_records')
        .select()
        .eq('patient_user_id', uid)
        .order('recorded_at', ascending: true);
    return data
        .map((row) => _entryFromRow(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<List<JournalEntry>> fetchByCategory(
    String categoryId, {
    bool simulateError = false,
  }) async {
    if (!isRemote) {
      return SimulatedApi.run(
        () => _entries.where((e) => e.categoryId == categoryId).toList(),
        simulateError: simulateError,
      );
    }
    final entries = await fetchEntries();
    return entries.where((e) => e.categoryId == categoryId).toList();
  }

  Future<JournalEntry> create(JournalEntry entry) async {
    final db = _db;
    final uid = _uid;
    if (db == null || uid == null) {
      return SimulatedApi.run(() {
        _counter++;
        final created = JournalEntry(
          id: 'je_new_$_counter',
          categoryId: entry.categoryId,
          value: entry.value,
          date: entry.date,
          status: entry.status,
          systolic: entry.systolic,
          diastolic: entry.diastolic,
          note: entry.note,
        );
        _entries.add(created);
        return created;
      });
    }

    final row = await db
        .from('patient_vital_records')
        .insert(_rowFromEntry(entry, uid))
        .select()
        .single();
    return _entryFromRow(Map<String, dynamic>.from(row as Map));
  }

  Future<JournalEntry> update(JournalEntry entry) async {
    final db = _db;
    if (db == null) {
      return SimulatedApi.run(() {
        final index = _entries.indexWhere((e) => e.id == entry.id);
        if (index != -1) _entries[index] = entry;
        return entry;
      });
    }

    final uid = _uid;
    if (uid == null) throw StateError('Sesi login tidak valid.');
    final row = await db
        .from('patient_vital_records')
        .update(_rowFromEntry(entry, uid))
        .eq('id', entry.id)
        .select()
        .single();
    return _entryFromRow(Map<String, dynamic>.from(row as Map));
  }

  Future<void> delete(String id) async {
    final db = _db;
    if (db == null) {
      await SimulatedApi.run(() => _entries.removeWhere((e) => e.id == id));
      return;
    }
    await db.from('patient_vital_records').delete().eq('id', id);
  }
}
