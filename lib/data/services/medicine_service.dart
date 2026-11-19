import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:Telehealth/core/supabase/supabase_config.dart';
import 'package:Telehealth/data/models/medicine_catalog.dart';

/// Kesalahan yang pesannya aman ditampilkan di UI admin.
class MedicineServiceException implements Exception {
  const MedicineServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Service master database obat (`public.medicines_catalog`).
///
/// Modul ini sengaja berdiri sendiri agar dapat dipakai ulang (reusable) dan
/// tidak terikat pada satu halaman. Saat ini hanya Web Dashboard Admin Rumah
/// Sakit yang memanggilnya; halaman dokter/pasien tidak diubah.
///
/// Semua query memakai [SupabaseConfig.firebaseAuthClient] sehingga RLS dapat
/// membaca Firebase UID dari `auth.jwt() ->> 'sub'`. Bila Supabase belum
/// dikonfigurasi, service memakai data demo lokal agar UI tetap berjalan.
class MedicineService {
  MedicineService._();

  static final MedicineService instance = MedicineService._();

  /// Dipakai unit test agar tidak pernah menyentuh jaringan.
  @visibleForTesting
  static bool forceDemoMode = false;

  SupabaseClient? get _db =>
      forceDemoMode ? null : SupabaseConfig.firebaseAuthClient;

  /// `true` bila service sedang memakai data demo lokal.
  bool get isDemoMode => _db == null;

  static const String _columns =
      'id, medicine_name, generic_name, category, dosage_form, '
      'default_dosage, default_frequency_per_day, default_duration_days, '
      'default_instructions, is_active, created_at';

  /// Pencarian obat untuk dropdown katalog.
  ///
  /// Mencari pada `medicine_name` **dan** `generic_name` (ILIKE), hanya obat
  /// aktif, diurutkan berdasarkan nama. Query kosong mengembalikan daftar awal
  /// obat aktif sehingga dropdown tetap dapat menampilkan pilihan.
  Future<List<MedicineCatalogItem>> searchMedicines(
    String query, {
    int limit = 20,
  }) async {
    final term = _sanitize(query);
    final db = _db;
    if (db == null) return _demoSearch(term, limit: limit);

    try {
      var builder = db
          .from('medicines_catalog')
          .select(_columns)
          .eq('is_active', true);

      if (term.isNotEmpty) {
        builder = builder.or(
          'medicine_name.ilike.%$term%,generic_name.ilike.%$term%',
        );
      }

      final rows = await builder.order('medicine_name').limit(limit);
      return rows.map(MedicineCatalogItem.fromRow).toList(growable: false);
    } catch (error) {
      throw MedicineServiceException(_readableError(error));
    }
  }

  /// Daftar katalog untuk halaman manajemen (termasuk yang nonaktif).
  Future<List<MedicineCatalogItem>> fetchAll({String query = ''}) async {
    final term = _sanitize(query);
    final db = _db;
    if (db == null) return _demoSearch(term, limit: 200, includeInactive: true);

    try {
      var builder = db.from('medicines_catalog').select(_columns);
      if (term.isNotEmpty) {
        builder = builder.or(
          'medicine_name.ilike.%$term%,generic_name.ilike.%$term%,'
          'category.ilike.%$term%',
        );
      }

      final rows = await builder
          .order('category')
          .order('medicine_name')
          .limit(500);
      return rows.map(MedicineCatalogItem.fromRow).toList(growable: false);
    } catch (error) {
      throw MedicineServiceException(_readableError(error));
    }
  }

  /// Menambah referensi obat baru. Hanya `hospital_admin` yang lolos RLS.
  Future<MedicineCatalogItem> createMedicine(MedicineCatalogDraft draft) async {
    final name = draft.medicineName.trim();
    if (name.isEmpty) {
      throw const MedicineServiceException('Nama obat wajib diisi.');
    }

    final db = _db;
    if (db == null) return _demoCreate(draft);

    try {
      final row = await db
          .from('medicines_catalog')
          .insert(draft.toRow())
          .select(_columns)
          .single();
      return MedicineCatalogItem.fromRow(row);
    } catch (error) {
      throw MedicineServiceException(_readableError(error));
    }
  }

  /// Memperbarui referensi obat. Hanya `hospital_admin` yang lolos RLS.
  Future<MedicineCatalogItem> updateMedicine(MedicineCatalogItem item) async {
    if (item.id.isEmpty) {
      throw const MedicineServiceException('Obat tidak ditemukan.');
    }

    final db = _db;
    if (db == null) return _demoUpdate(item);

    try {
      final row = await db
          .from('medicines_catalog')
          .update(_toRow(item))
          .eq('id', item.id)
          .select(_columns)
          .single();
      return MedicineCatalogItem.fromRow(row);
    } catch (error) {
      throw MedicineServiceException(_readableError(error));
    }
  }

  Map<String, dynamic> _toRow(MedicineCatalogItem item) => {
    'medicine_name': item.medicineName.trim(),
    'generic_name': item.genericName.trim(),
    'category': item.category.trim(),
    'dosage_form': item.dosageForm.trim(),
    'default_dosage': item.defaultDosage.trim(),
    'default_frequency_per_day': item.defaultFrequencyPerDay,
    'default_duration_days': item.defaultDurationDays,
    'default_instructions': item.defaultInstructions.trim(),
    'is_active': item.isActive,
  };

  /// Membersihkan karakter yang dapat merusak sintaks filter PostgREST.
  String _sanitize(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'[,%()]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _readableError(Object error) {
    debugPrint('[MedicineService] $error');
    if (error is MedicineServiceException) return error.message;
    if (error is PostgrestException) {
      return switch (error.code) {
        '23505' => 'Nama obat tersebut sudah ada di katalog.',
        '42501' =>
          'Akses ditolak. Hanya admin rumah sakit yang dapat mengubah katalog.',
        '23514' => 'Nilai frekuensi/durasi di luar rentang yang diizinkan.',
        _ => error.message,
      };
    }
    return 'Tidak dapat menghubungi server. Periksa koneksi lalu coba lagi.';
  }

  // ─── Data demo (tanpa kredensial Supabase) ──────────────────────────────────

  final List<MedicineCatalogItem> _demoItems = [
    _demo(
      '01',
      'Amoxicillin 500 mg',
      'Amoxicillin',
      'Antibiotik',
      'Kapsul',
      '1 Kapsul',
      3,
      7,
      'Diminum sesudah makan dan dihabiskan.',
    ),
    _demo(
      '02',
      'Cefixime 200 mg',
      'Cefixime',
      'Antibiotik',
      'Kapsul',
      '1 Kapsul',
      2,
      5,
      'Diminum sesudah makan pagi dan malam.',
    ),
    _demo(
      '03',
      'Azithromycin 500 mg',
      'Azithromycin',
      'Antibiotik',
      'Tablet',
      '1 Tablet',
      1,
      3,
      'Diminum sebelum makan.',
    ),
    _demo(
      '04',
      'Paracetamol 500 mg',
      'Paracetamol',
      'Analgesik',
      'Tablet',
      '1 Tablet',
      3,
      3,
      'Diminum bila nyeri/demam.',
    ),
    _demo(
      '05',
      'Ibuprofen 400 mg',
      'Ibuprofen',
      'Analgesik',
      'Tablet',
      '1 Tablet',
      3,
      3,
      'Diminum sesudah makan.',
    ),
    _demo(
      '06',
      'Omeprazole 20 mg',
      'Omeprazole',
      'Gastrointestinal',
      'Kapsul',
      '1 Kapsul',
      1,
      7,
      'Diminum sebelum makan pagi.',
    ),
    _demo(
      '07',
      'Domperidone 10 mg',
      'Domperidone',
      'Gastrointestinal',
      'Tablet',
      '1 Tablet',
      3,
      5,
      'Diminum sebelum makan.',
    ),
    _demo(
      '08',
      'Amlodipine 5 mg',
      'Amlodipine',
      'Kardiovaskular',
      'Tablet',
      '1 Tablet',
      1,
      30,
      'Diminum setiap pagi.',
    ),
    _demo(
      '09',
      'Furosemide 40 mg',
      'Furosemide',
      'Kardiovaskular',
      'Tablet',
      '1 Tablet',
      1,
      30,
      'Diminum pagi hari.',
    ),
    _demo(
      '10',
      'Metformin 500 mg',
      'Metformin',
      'Antidiabetes',
      'Tablet',
      '1 Tablet',
      2,
      30,
      'Diminum sesudah makan.',
    ),
    _demo(
      '11',
      'Atorvastatin 20 mg',
      'Atorvastatin',
      'Kolesterol',
      'Tablet',
      '1 Tablet',
      1,
      30,
      'Diminum malam hari.',
    ),
    _demo(
      '12',
      'Clopidogrel 75 mg',
      'Clopidogrel',
      'Pengencer Darah',
      'Tablet',
      '1 Tablet',
      1,
      30,
      'Diminum setiap hari.',
    ),
    _demo(
      '13',
      'Vitamin B Complex',
      'Vitamin B Complex',
      'Vitamin',
      'Tablet',
      '1 Tablet',
      1,
      30,
      'Diminum sesudah makan.',
    ),
    _demo(
      '14',
      'Vitamin D3 1000 IU',
      'Cholecalciferol',
      'Vitamin',
      'Tablet',
      '1 Tablet',
      1,
      30,
      'Diminum sesudah makan pagi.',
    ),
  ];

  static MedicineCatalogItem _demo(
    String suffix,
    String name,
    String generic,
    String category,
    String form,
    String dosage,
    int frequency,
    int duration,
    String instructions,
  ) {
    return MedicineCatalogItem(
      id: 'demo-med-$suffix',
      medicineName: name,
      genericName: generic,
      category: category,
      dosageForm: form,
      defaultDosage: dosage,
      defaultFrequencyPerDay: frequency,
      defaultDurationDays: duration,
      defaultInstructions: instructions,
    );
  }

  List<MedicineCatalogItem> _demoSearch(
    String term, {
    required int limit,
    bool includeInactive = false,
  }) {
    final needle = term.toLowerCase();
    final matches = _demoItems.where((item) {
      if (!includeInactive && !item.isActive) return false;
      if (needle.isEmpty) return true;
      return item.medicineName.toLowerCase().contains(needle) ||
          item.genericName.toLowerCase().contains(needle) ||
          item.category.toLowerCase().contains(needle);
    }).toList()..sort((a, b) => a.medicineName.compareTo(b.medicineName));

    return matches.take(limit).toList(growable: false);
  }

  MedicineCatalogItem _demoCreate(MedicineCatalogDraft draft) {
    final name = draft.medicineName.trim();
    final duplicate = _demoItems.any(
      (item) => item.medicineName.toLowerCase() == name.toLowerCase(),
    );
    if (duplicate) {
      throw const MedicineServiceException(
        'Nama obat tersebut sudah ada di katalog.',
      );
    }

    final created = MedicineCatalogItem(
      id: 'demo-med-${DateTime.now().microsecondsSinceEpoch}',
      medicineName: name,
      genericName: draft.genericName,
      category: draft.category,
      dosageForm: draft.dosageForm,
      defaultDosage: draft.defaultDosage,
      defaultFrequencyPerDay: draft.defaultFrequencyPerDay,
      defaultDurationDays: draft.defaultDurationDays,
      defaultInstructions: draft.defaultInstructions,
      isActive: draft.isActive,
      createdAt: DateTime.now(),
    );
    _demoItems.insert(0, created);
    return created;
  }

  MedicineCatalogItem _demoUpdate(MedicineCatalogItem item) {
    final index = _demoItems.indexWhere((entry) => entry.id == item.id);
    if (index < 0) {
      throw const MedicineServiceException('Obat tidak ditemukan.');
    }
    _demoItems[index] = item;
    return item;
  }
}
