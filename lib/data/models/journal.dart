/// Kategori / referensi jenis catatan jurnal (mis. Tekanan Darah, Gula Darah).
class JournalCategory {
  const JournalCategory({
    required this.id,
    required this.name,
    required this.unit,
    this.isPressure = false,
  });

  final String id;
  final String name;
  final String unit;
  final bool isPressure; // true -> input sistolik & diastolik
}

/// Satu entri catatan jurnal kesehatan.
///
/// `categoryId` adalah relasi ke [JournalCategory].
class JournalEntry {
  JournalEntry({
    required this.id,
    required this.categoryId,
    required this.value,
    required this.date,
    required this.status,
    this.systolic,
    this.diastolic,
    this.note = '',
  });

  final String id;
  final String categoryId;
  final double value;
  final DateTime date;
  final String status; // 'Normal' | 'Perhatian'
  final int? systolic;
  final int? diastolic;
  final String note;

  JournalEntry copyWith({
    String? categoryId,
    double? value,
    DateTime? date,
    String? status,
    int? systolic,
    int? diastolic,
    String? note,
  }) {
    return JournalEntry(
      id: id,
      categoryId: categoryId ?? this.categoryId,
      value: value ?? this.value,
      date: date ?? this.date,
      status: status ?? this.status,
      systolic: systolic ?? this.systolic,
      diastolic: diastolic ?? this.diastolic,
      note: note ?? this.note,
    );
  }
}
