import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_config.dart';
import '../models/doctor.dart';
import 'simulated_api.dart';
import 'supabase_mappers.dart';

/// Repository dokter.
///
/// Sumber data: tabel `doctors` di Supabase bila tersedia, selain itu
/// memakai data simulasi lokal (dipakai unit test / mode offline).
class DoctorRepository {
  DoctorRepository._();
  static final DoctorRepository instance = DoctorRepository._();

  SupabaseClient? get _db => SupabaseConfig.client;

  /// Cache hasil fetch terakhir dari Supabase untuk [specializations].
  List<Doctor> _remoteCache = const [];

  final List<Doctor> _doctors = [
    const Doctor(
      id: 'doc1',
      name: 'dr. Rifki Al Sauqy, Sp.JP',
      specialization: 'Spesialis Jantung',
      experience: 12,
      rating: 4.9,
      price: 150000,
      available: true,
      hospital: 'RS Jantung Harapan Kita',
      bio:
          'Spesialis jantung berpengalaman dalam penanganan penyakit jantung koroner, aritmia, dan gagal jantung.',
      education: 'FK Universitas Indonesia • PPDS Kardiologi UI',
      avatarColor: Color(0xFFE53935),
    ),
    const Doctor(
      id: 'doc2',
      name: 'dr. Yehezkiel Sitanggang, Sp.A',
      specialization: 'Spesialis Anak',
      experience: 8,
      rating: 4.8,
      price: 120000,
      available: true,
      hospital: 'RSUP Dr. Cipto Mangunkusumo',
      bio:
          'Dokter spesialis anak yang berdedikasi, menangani berbagai penyakit anak dari neonatus hingga remaja.',
      education: 'FK Universitas Gadjah Mada • PPDS Ilmu Kesehatan Anak UGM',
      avatarColor: Color(0xFF1E88E5),
    ),
    const Doctor(
      id: 'doc3',
      name: 'dr. Farhan Prasetyo',
      specialization: 'Dokter Umum',
      experience: 5,
      rating: 4.6,
      price: 75000,
      available: false,
      hospital: 'Klinik Sehat Bersama',
      bio:
          'Dokter umum berpengalaman menangani keluhan kesehatan sehari-hari dengan pendekatan holistik.',
      education: 'FK Universitas Airlangga',
      avatarColor: Color(0xFF43A047),
    ),
    const Doctor(
      id: 'doc4',
      name: 'dr. Pocut Qanitah, Sp.KK',
      specialization: 'Spesialis Kulit',
      experience: 10,
      rating: 4.7,
      price: 130000,
      available: true,
      hospital: 'RS Dermatologi Indonesia',
      bio:
          'Spesialis kulit dan kelamin dengan keahlian dermatologi estetika dan penyakit kulit kronis.',
      education: 'FK Universitas Padjadjaran • PPDS Dermatologi UNPAD',
      avatarColor: Color(0xFF8E24AA),
    ),
    const Doctor(
      id: 'doc5',
      name: 'dr. Daffa Afdhillah, Sp.PD',
      specialization: 'Spesialis Penyakit Dalam',
      experience: 9,
      rating: 4.8,
      price: 140000,
      available: true,
      hospital: 'RS Pusat Pertamina',
      bio:
          'Spesialis penyakit dalam dengan fokus diabetes, hipertensi, dan gangguan metabolisme.',
      education: 'FK Universitas Indonesia • PPDS Penyakit Dalam UI',
      avatarColor: Color(0xFF00897B),
    ),
    const Doctor(
      id: 'doc6',
      name: 'dr. Arkaan Ramdhan',
      specialization: 'Dokter Umum',
      experience: 6,
      rating: 4.7,
      price: 80000,
      available: true,
      hospital: 'Klinik Telehealth',
      bio:
          'Dokter umum yang ramah dengan layanan konsultasi daring untuk keluhan ringan.',
      education: 'FK Universitas Diponegoro',
      avatarColor: Color(0xFFF4511E),
    ),
    const Doctor(
      id: 'doc7',
      name: 'dr. Cristian, Sp.KJ',
      specialization: 'Psikiatri',
      experience: 8,
      rating: 4.8,
      price: 160000,
      available: true,
      hospital: 'RS Jiwa Dr. Soeharto Heerdjan',
      bio:
          'Psikiater dengan pendekatan suportif untuk kecemasan, depresi, dan gangguan tidur.',
      education: 'FK Universitas Padjadjaran • PPDS Psikiatri UNPAD',
      avatarColor: Color(0xFF5E35B1),
    ),
    const Doctor(
      id: 'doc8',
      name: 'dr. William Bevan, Sp.DVE',
      specialization: 'Dermatologi',
      experience: 6,
      rating: 4.7,
      price: 135000,
      available: false,
      hospital: 'Klinik Estetika Nusantara',
      bio:
          'Dermatolog yang menangani masalah kulit, rambut, dan kuku termasuk perawatan estetika.',
      education: 'FK Universitas Brawijaya • PPDS Dermatologi UB',
      avatarColor: Color(0xFFD81B60),
    ),
  ];

  /// Daftar spesialisasi unik (data referensi/kategori untuk filter).
  List<String> get specializations {
    final source = _remoteCache.isNotEmpty ? _remoteCache : _doctors;
    final list = source.map((d) => d.specialization).toSet().toList();
    list.sort();
    return list;
  }

  Future<List<Doctor>> fetchAll({bool simulateError = false}) async {
    final db = _db;
    if (db == null) {
      return SimulatedApi.run(
        () => List<Doctor>.of(_doctors),
        simulateError: simulateError,
      );
    }

    final rows = await db.from('doctors').select().order('name');
    final doctors = rows.map(doctorFromRow).toList();
    _remoteCache = doctors;
    return doctors;
  }

  Future<Doctor?> findById(String id) async {
    final db = _db;
    if (db == null) {
      return SimulatedApi.run(() {
        final matches = _doctors.where((d) => d.id == id);
        return matches.isEmpty ? null : matches.first;
      });
    }

    final row = await db.from('doctors').select().eq('id', id).maybeSingle();
    return row == null ? null : doctorFromRow(row);
  }
}
