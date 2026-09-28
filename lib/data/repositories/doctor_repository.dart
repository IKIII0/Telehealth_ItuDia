import 'package:flutter/material.dart';

import '../models/doctor.dart';
import 'simulated_api.dart';

/// Repository dokter dengan data simulasi.
///
/// Data disimpan di memori sehingga perubahan (bila ada) bertahan
/// selama sesi aplikasi berjalan.
class DoctorRepository {
  DoctorRepository._();
  static final DoctorRepository instance = DoctorRepository._();

  final List<Doctor> _doctors = [
    const Doctor(
      id: 'doc1',
      name: 'Dr. Ahmad Fauzi, Sp.JP',
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
      name: 'Dr. Siti Rahma, Sp.A',
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
      name: 'Dr. Budi Santoso',
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
      name: 'Dr. Dewi Kusuma, Sp.KK',
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
      name: 'Dr. Rizky Pratama, Sp.PD',
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
      name: 'Dr. Maya Indah',
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
      name: 'Dr. Reza Fauzan, Sp.KJ',
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
      name: 'Dr. Laila Nurfitri, Sp.DVE',
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
    final list = _doctors.map((d) => d.specialization).toSet().toList();
    list.sort();
    return list;
  }

  Future<List<Doctor>> fetchAll({bool simulateError = false}) {
    return SimulatedApi.run(
      () => List<Doctor>.of(_doctors),
      simulateError: simulateError,
    );
  }

  Future<Doctor?> findById(String id) {
    return SimulatedApi.run(() {
      final matches = _doctors.where((d) => d.id == id);
      return matches.isEmpty ? null : matches.first;
    });
  }
}
