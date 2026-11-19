/// Model master database obat (`public.medicines_catalog`).
///
/// Model ini dipakai oleh [MedicineService] dan hanya dikonsumsi oleh Web
/// Dashboard Admin Rumah Sakit. Tidak ada model/komponen pasien atau dokter
/// yang diubah.
library;

/// Satu baris referensi obat beserta nilai default untuk auto-fill resep.
class MedicineCatalogItem {
  const MedicineCatalogItem({
    required this.id,
    required this.medicineName,
    this.genericName = '',
    this.category = '',
    this.dosageForm = '',
    this.defaultDosage = '',
    this.defaultFrequencyPerDay = 1,
    this.defaultDurationDays = 1,
    this.defaultInstructions = '',
    this.isActive = true,
    this.createdAt,
  });

  factory MedicineCatalogItem.fromRow(Map<String, dynamic> row) {
    return MedicineCatalogItem(
      id: _asString(row['id']),
      medicineName: _asString(row['medicine_name']),
      genericName: _asString(row['generic_name']),
      category: _asString(row['category']),
      dosageForm: _asString(row['dosage_form']),
      defaultDosage: _asString(row['default_dosage']),
      defaultFrequencyPerDay: _asInt(
        row['default_frequency_per_day'],
        fallback: 1,
      ),
      defaultDurationDays: _asInt(row['default_duration_days'], fallback: 1),
      defaultInstructions: _asString(row['default_instructions']),
      isActive: row['is_active'] as bool? ?? true,
      createdAt: _asDate(row['created_at']),
    );
  }

  final String id;

  /// Nama obat + kekuatan sediaan, mis. `Amoxicillin 500 mg`.
  final String medicineName;

  /// Nama zat aktif / generik, mis. `Amoxicillin`.
  final String genericName;

  /// Kategori terapi, mis. `Antibiotik`.
  final String category;

  /// Bentuk sediaan, mis. `Tablet`, `Kapsul`, `Suspensi`.
  final String dosageForm;

  /// Dosis standar, mis. `1 Tablet` atau `10 ml`.
  final String defaultDosage;

  final int defaultFrequencyPerDay;
  final int defaultDurationDays;

  /// Instruksi konsumsi standar.
  final String defaultInstructions;

  final bool isActive;
  final DateTime? createdAt;

  /// Label saran pencarian, mis. `Amoxicillin 500 mg • Antibiotik`.
  String get suggestionLabel {
    final suffix = [category, dosageForm].where((part) => part.isNotEmpty);
    return suffix.isEmpty
        ? medicineName
        : '$medicineName • ${suffix.join(' • ')}';
  }

  /// Ringkasan default, mis. `1 Kapsul • 3× sehari • 7 hari`.
  String get defaultSummary {
    final parts = <String>[
      if (defaultDosage.isNotEmpty) defaultDosage,
      '$defaultFrequencyPerDay× sehari',
      '$defaultDurationDays hari',
    ];
    return parts.join(' • ');
  }

  MedicineCatalogItem copyWith({
    String? medicineName,
    String? genericName,
    String? category,
    String? dosageForm,
    String? defaultDosage,
    int? defaultFrequencyPerDay,
    int? defaultDurationDays,
    String? defaultInstructions,
    bool? isActive,
  }) {
    return MedicineCatalogItem(
      id: id,
      medicineName: medicineName ?? this.medicineName,
      genericName: genericName ?? this.genericName,
      category: category ?? this.category,
      dosageForm: dosageForm ?? this.dosageForm,
      defaultDosage: defaultDosage ?? this.defaultDosage,
      defaultFrequencyPerDay:
          defaultFrequencyPerDay ?? this.defaultFrequencyPerDay,
      defaultDurationDays: defaultDurationDays ?? this.defaultDurationDays,
      defaultInstructions: defaultInstructions ?? this.defaultInstructions,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }
}

/// Data untuk membuat entri katalog baru (belum memiliki `id`).
class MedicineCatalogDraft {
  const MedicineCatalogDraft({
    required this.medicineName,
    this.genericName = '',
    this.category = 'Lainnya',
    this.dosageForm = 'Tablet',
    this.defaultDosage = '',
    this.defaultFrequencyPerDay = 1,
    this.defaultDurationDays = 1,
    this.defaultInstructions = '',
    this.isActive = true,
  });

  final String medicineName;
  final String genericName;
  final String category;
  final String dosageForm;
  final String defaultDosage;
  final int defaultFrequencyPerDay;
  final int defaultDurationDays;
  final String defaultInstructions;
  final bool isActive;

  Map<String, dynamic> toRow() => {
    'medicine_name': medicineName.trim(),
    'generic_name': genericName.trim(),
    'category': category.trim(),
    'dosage_form': dosageForm.trim(),
    'default_dosage': defaultDosage.trim(),
    'default_frequency_per_day': defaultFrequencyPerDay,
    'default_duration_days': defaultDurationDays,
    'default_instructions': defaultInstructions.trim(),
    'is_active': isActive,
  };
}

String _asString(Object? value, {String fallback = ''}) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

int _asInt(Object? value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

DateTime? _asDate(Object? value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
