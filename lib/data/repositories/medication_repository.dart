import 'package:flutter/material.dart';

import '../models/medication.dart';
import 'simulated_api.dart';

/// Repository pengingat obat (modul CRUD 1) dengan data simulasi.
///
/// Setiap obat memiliki `doctorId` sebagai relasi ke data dokter.
class MedicationRepository {
  MedicationRepository._();
  static final MedicationRepository instance = MedicationRepository._();

  int _counter = 0;

  final List<Medication> _medications = [
    Medication(
      id: 'med1',
      name: 'Paracetamol',
      dose: '500 mg',
      frequency: '3x sehari',
      startDate: '20 Sep 2024',
      endDate: '27 Sep 2024',
      note: 'Sesudah makan',
      doctorId: 'doc5',
      color: const Color(0xFF1E88E5),
      icon: Icons.medication_rounded,
      schedules: [
        MedicationSchedule(time: 'Pagi', hour: '08:00', taken: true),
        MedicationSchedule(time: 'Siang', hour: '14:00', taken: true),
        MedicationSchedule(time: 'Malam', hour: '20:00'),
      ],
    ),
    Medication(
      id: 'med2',
      name: 'Amoxicillin',
      dose: '500 mg',
      frequency: '3x sehari',
      startDate: '22 Sep 2024',
      endDate: '29 Sep 2024',
      note: 'Sebelum makan',
      doctorId: 'doc3',
      color: const Color(0xFFE53935),
      icon: Icons.medication_liquid_rounded,
      schedules: [
        MedicationSchedule(time: 'Pagi', hour: '08:00', taken: true),
        MedicationSchedule(time: 'Siang', hour: '14:00'),
        MedicationSchedule(time: 'Malam', hour: '20:00'),
      ],
    ),
    Medication(
      id: 'med3',
      name: 'Vitamin C',
      dose: '1000 mg',
      frequency: '1x sehari',
      startDate: '01 Sep 2024',
      endDate: '30 Sep 2024',
      note: 'Sesudah makan',
      doctorId: 'doc1',
      color: const Color(0xFFFF8F00),
      icon: Icons.local_pharmacy_rounded,
      schedules: [MedicationSchedule(time: 'Pagi', hour: '08:00', taken: true)],
    ),
    Medication(
      id: 'med4',
      name: 'Amlodipine',
      dose: '10 mg',
      frequency: '1x sehari',
      startDate: '15 Sep 2024',
      endDate: '15 Okt 2024',
      note: 'Sebelum tidur',
      doctorId: 'doc1',
      color: const Color(0xFF43A047),
      icon: Icons.favorite_rounded,
      schedules: [MedicationSchedule(time: 'Malam', hour: '21:00')],
    ),
    Medication(
      id: 'med5',
      name: 'Metformin',
      dose: '500 mg',
      frequency: '2x sehari',
      startDate: '10 Sep 2024',
      endDate: '10 Okt 2024',
      note: 'Sesudah makan',
      doctorId: 'doc5',
      color: const Color(0xFF5E35B1),
      icon: Icons.water_drop_rounded,
      schedules: [
        MedicationSchedule(time: 'Pagi', hour: '08:00', taken: true),
        MedicationSchedule(time: 'Malam', hour: '20:00'),
      ],
    ),
    Medication(
      id: 'med6',
      name: 'Cetirizine',
      dose: '10 mg',
      frequency: '1x sehari',
      startDate: '18 Sep 2024',
      endDate: '25 Sep 2024',
      note: 'Malam hari',
      doctorId: 'doc4',
      color: const Color(0xFF8E24AA),
      icon: Icons.air_rounded,
      schedules: [
        MedicationSchedule(time: 'Malam', hour: '21:00', taken: true),
      ],
    ),
  ];

  List<Medication> get _all => _medications;

  Future<List<Medication>> fetchAll({bool simulateError = false}) {
    return SimulatedApi.run(
      () => List<Medication>.of(_all),
      simulateError: simulateError,
    );
  }

  Future<Medication> create({
    required String name,
    required String dose,
    required String frequency,
    required String note,
    required String doctorId,
    required List<MedicationSchedule> schedules,
  }) {
    return SimulatedApi.run(() {
      _counter++;
      final medication = Medication(
        id: 'med_new_$_counter',
        name: name,
        dose: dose,
        frequency: frequency,
        startDate: _today(),
        endDate: '-',
        note: note.isEmpty ? '-' : note,
        doctorId: doctorId,
        schedules: schedules,
      );
      _all.insert(0, medication);
      return medication;
    });
  }

  Future<Medication> update(Medication medication) {
    return SimulatedApi.run(() {
      final index = _all.indexWhere((m) => m.id == medication.id);
      if (index != -1) _all[index] = medication;
      return medication;
    });
  }

  Future<void> delete(String id) {
    return SimulatedApi.run(() => _all.removeWhere((m) => m.id == id));
  }

  /// Menandai satu jadwal minum obat sebagai sudah/belum diminum.
  Future<void> toggleTaken(String medicationId, int scheduleIndex) {
    return SimulatedApi.run(() {
      final index = _all.indexWhere((m) => m.id == medicationId);
      if (index == -1) return;
      final schedules = _all[index].schedules;
      if (scheduleIndex < 0 || scheduleIndex >= schedules.length) return;
      schedules[scheduleIndex].taken = !schedules[scheduleIndex].taken;
    });
  }

  String _today() {
    final now = DateTime.now();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${now.day} ${months[now.month - 1]} ${now.year}';
  }
}
