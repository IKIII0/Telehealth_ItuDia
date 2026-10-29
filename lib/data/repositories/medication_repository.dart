import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_config.dart';
import '../models/medication.dart';
import 'simulated_api.dart';
import 'supabase_mappers.dart';

/// Repository pengingat obat (modul CRUD 1).
///
/// Memakai Supabase bila kredensial tersedia; bila tidak, otomatis memakai
/// data simulasi lokal supaya aplikasi dan unit test tetap berjalan.
/// Penghapusan bersifat *soft delete*: baris ditandai `is_deleted` lalu
/// muncul di tab Riwayat.
class MedicationRepository {
  MedicationRepository._();
  static final MedicationRepository instance = MedicationRepository._();

  SupabaseClient? get _db => SupabaseConfig.client;

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

  List<Medication> get _active =>
      _medications.where((m) => !m.isDeleted).toList();
  List<Medication> get _history =>
      _medications.where((m) => m.isDeleted).toList();

  Future<List<Medication>> fetchAll({bool simulateError = false}) async {
    final db = _db;
    if (db == null) {
      return SimulatedApi.run(
        () => List<Medication>.of(_active),
        simulateError: simulateError,
      );
    }

    final rows = await db
        .from('medications')
        .select('*, medication_schedules(*)')
        .eq('is_deleted', false)
        .order('created_at', ascending: false);
    return rows.map(medicationFromRow).toList();
  }

  Future<List<Medication>> fetchHistory({bool simulateError = false}) async {
    final db = _db;
    if (db == null) {
      return SimulatedApi.run(
        () => List<Medication>.of(_history),
        simulateError: simulateError,
      );
    }

    final rows = await db
        .from('medications')
        .select('*, medication_schedules(*)')
        .eq('is_deleted', true)
        .order('deleted_at', ascending: false);
    return rows.map(medicationFromRow).toList();
  }

  Future<Medication> create({
    required String name,
    required String dose,
    required String frequency,
    required String note,
    required String doctorId,
    required List<MedicationSchedule> schedules,
  }) async {
    final db = _db;
    final today = _today();

    if (db == null) {
      return SimulatedApi.run(() {
        _counter++;
        final medication = Medication(
          id: 'med_new_$_counter',
          name: name,
          dose: dose,
          frequency: frequency,
          startDate: today,
          endDate: '-',
          note: note.isEmpty ? '-' : note,
          doctorId: doctorId,
          schedules: schedules,
        );
        _medications.insert(0, medication);
        return medication;
      });
    }

    final inserted = await db
        .from('medications')
        .insert({
          'name': name,
          'dose': dose,
          'frequency': frequency,
          'start_date': today,
          'end_date': '-',
          'note': note.isEmpty ? '-' : note,
          'doctor_id': doctorId,
          'color': colorToDb(const Color(0xFF1E88E5)),
          'icon': 'medication',
        })
        .select()
        .single();

    final medicationId = inserted['id'].toString();
    await _insertSchedules(db, medicationId, schedules);

    return Medication(
      id: medicationId,
      name: name,
      dose: dose,
      frequency: frequency,
      startDate: today,
      endDate: '-',
      note: note.isEmpty ? '-' : note,
      doctorId: doctorId,
      schedules: schedules,
    );
  }

  Future<Medication> update(Medication medication) async {
    final db = _db;
    if (db == null) {
      return SimulatedApi.run(() {
        final index = _medications.indexWhere((m) => m.id == medication.id);
        if (index != -1) _medications[index] = medication;
        return medication;
      });
    }

    await db
        .from('medications')
        .update({
          'name': medication.name,
          'dose': medication.dose,
          'frequency': medication.frequency,
          'start_date': medication.startDate,
          'end_date': medication.endDate,
          'note': medication.note,
          'doctor_id': medication.doctorId,
          'color': colorToDb(medication.color),
          'icon': iconToDb(medication.icon),
        })
        .eq('id', medication.id);

    // Jadwal diganti utuh agar status "taken" tetap sinkron.
    await db
        .from('medication_schedules')
        .delete()
        .eq('medication_id', medication.id);
    await _insertSchedules(db, medication.id, medication.schedules);

    return medication;
  }

  /// Soft delete: data tidak dihapus fisik agar riwayat konsumsi tetap utuh.
  Future<void> delete(String id) async {
    final db = _db;
    if (db == null) {
      await SimulatedApi.run(() {
        final index = _medications.indexWhere((m) => m.id == id);
        if (index != -1) {
          _medications[index] = _medications[index].copyWith(
            isDeleted: true,
            deletedAt: _today(),
          );
        }
      });
      return;
    }

    await db
        .from('medications')
        .update({
          'is_deleted': true,
          'deleted_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id);
  }

  /// Menandai satu jadwal minum obat sebagai sudah/belum diminum.
  Future<void> toggleTaken(String medicationId, int scheduleIndex) async {
    final db = _db;
    if (db == null) {
      await SimulatedApi.run(() {
        final index = _active.indexWhere((m) => m.id == medicationId);
        if (index == -1) return;
        final schedules = _active[index].schedules;
        if (scheduleIndex < 0 || scheduleIndex >= schedules.length) return;
        schedules[scheduleIndex].taken = !schedules[scheduleIndex].taken;
      });
      return;
    }

    final rows = await db
        .from('medication_schedules')
        .select('id, taken')
        .eq('medication_id', medicationId)
        .order('position', ascending: true);

    if (scheduleIndex < 0 || scheduleIndex >= rows.length) return;
    final row = rows[scheduleIndex];
    await db
        .from('medication_schedules')
        .update({'taken': !(row['taken'] as bool? ?? false)})
        .eq('id', row['id'].toString());
  }

  Future<void> _insertSchedules(
    SupabaseClient db,
    String medicationId,
    List<MedicationSchedule> schedules,
  ) async {
    if (schedules.isEmpty) return;
    await db.from('medication_schedules').insert([
      for (var i = 0; i < schedules.length; i++)
        {
          'medication_id': medicationId,
          'position': i,
          'period': schedules[i].time,
          'hour': schedules[i].hour,
          'taken': schedules[i].taken,
        },
    ]);
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
