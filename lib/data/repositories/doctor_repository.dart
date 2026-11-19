import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_config.dart';
import '../models/doctor.dart';
import 'simulated_api.dart';
import 'supabase_mappers.dart';

/// Repository dokter.
///
/// Sumber tunggal: tabel `doctors` di Supabase. Baris tabel ini diisi
/// otomatis ketika seorang dokter mendaftar (lihat
/// `supabase/05_doctor_directory_sync.sql`), sehingga tidak ada lagi data
/// dokter dummy di aplikasi.
///
/// Bila Supabase belum dikonfigurasi, daftar dokter kosong dan halaman
/// menampilkan empty state.
class DoctorRepository {
  DoctorRepository._();
  static final DoctorRepository instance = DoctorRepository._();

  SupabaseClient? get _db => SupabaseConfig.client;

  /// Cache hasil fetch terakhir untuk [specializations].
  List<Doctor> _cached = const [];

  /// Daftar spesialisasi unik (data referensi/kategori untuk filter).
  List<String> get specializations {
    final list = _cached.map((d) => d.specialization).toSet().toList();
    list.sort();
    return list;
  }

  Future<List<Doctor>> fetchAll({bool simulateError = false}) async {
    final db = _db;
    if (db == null) {
      return SimulatedApi.run(() => <Doctor>[], simulateError: simulateError);
    }

    final rows = await db.from('doctors').select().order('name');
    final doctors = rows.map(doctorFromRow).toList();
    _cached = doctors;
    return doctors;
  }

  Future<Doctor?> findById(String id) async {
    final db = _db;
    if (db == null) {
      return SimulatedApi.run(() {
        for (final doctor in _cached) {
          if (doctor.id == id) return doctor;
        }
        return null;
      });
    }

    final row = await db.from('doctors').select().eq('id', id).maybeSingle();
    return row == null ? null : doctorFromRow(row);
  }
}
