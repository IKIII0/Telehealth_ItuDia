import '../models/journal.dart';
import 'simulated_api.dart';

/// Repository jurnal kesehatan (modul CRUD 2) dengan data simulasi.
///
/// Entri jurnal memiliki `categoryId` sebagai relasi ke data kategori.
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

  final List<JournalEntry> _entries = [];

  List<JournalCategory> get categories => List.unmodifiable(_categories);

  JournalCategory categoryById(String id) => _categories.firstWhere(
    (c) => c.id == id,
    orElse: () => _categories.first,
  );

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

  Future<List<JournalEntry>> fetchEntries({bool simulateError = false}) {
    return SimulatedApi.run(
      () => List<JournalEntry>.of(_entries),
      simulateError: simulateError,
    );
  }

  Future<List<JournalEntry>> fetchByCategory(
    String categoryId, {
    bool simulateError = false,
  }) {
    return SimulatedApi.run(
      () => _entries.where((e) => e.categoryId == categoryId).toList(),
      simulateError: simulateError,
    );
  }

  Future<JournalEntry> create(JournalEntry entry) {
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

  Future<JournalEntry> update(JournalEntry entry) {
    return SimulatedApi.run(() {
      final index = _entries.indexWhere((e) => e.id == entry.id);
      if (index != -1) _entries[index] = entry;
      return entry;
    });
  }

  Future<void> delete(String id) {
    return SimulatedApi.run(() => _entries.removeWhere((e) => e.id == id));
  }
}
