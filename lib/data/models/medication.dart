import 'package:flutter/material.dart';

/// Satu jadwal minum obat dalam sehari.
class MedicationSchedule {
  MedicationSchedule({
    required this.time,
    required this.hour,
    this.taken = false,
  });

  final String time; // 'Pagi' / 'Siang' / 'Malam'
  final String hour; // '08:00'
  bool taken;
}

/// Model pengingat obat.
///
/// `doctorId` adalah relasi ke [Doctor] (dokter yang meresepkan).
class Medication {
  Medication({
    required this.id,
    required this.name,
    required this.dose,
    required this.frequency,
    required this.startDate,
    required this.endDate,
    required this.note,
    required this.doctorId,
    required this.schedules,
    this.color = const Color(0xFF1E88E5),
    this.icon = Icons.medication_rounded,
  });

  final String id;
  final String name;
  final String dose;
  final String frequency;
  final String startDate;
  final String endDate;
  final String note;
  final String doctorId;
  final List<MedicationSchedule> schedules;
  final Color color;
  final IconData icon;

  int get totalSchedules => schedules.length;
  int get takenSchedules => schedules.where((s) => s.taken).length;

  Medication copyWith({
    String? name,
    String? dose,
    String? frequency,
    String? startDate,
    String? endDate,
    String? note,
    String? doctorId,
    List<MedicationSchedule>? schedules,
    Color? color,
    IconData? icon,
  }) {
    return Medication(
      id: id,
      name: name ?? this.name,
      dose: dose ?? this.dose,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      note: note ?? this.note,
      doctorId: doctorId ?? this.doctorId,
      schedules: schedules ?? this.schedules,
      color: color ?? this.color,
      icon: icon ?? this.icon,
    );
  }
}
