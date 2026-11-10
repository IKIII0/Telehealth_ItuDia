import 'package:flutter/material.dart';

/// Status sesi konsultasi.
enum ConsultationStatus {
  ongoing,
  completed,
  cancelled,
  scheduled;

  String get label => switch (this) {
    ConsultationStatus.ongoing => 'Berlangsung',
    ConsultationStatus.completed => 'Selesai',
    ConsultationStatus.cancelled => 'Dibatalkan',
    ConsultationStatus.scheduled => 'Terjadwal',
  };

  Color get color => switch (this) {
    ConsultationStatus.ongoing => const Color(0xFF4CAF50),
    ConsultationStatus.completed => const Color(0xFF1E88E5),
    ConsultationStatus.cancelled => const Color(0xFFE53935),
    ConsultationStatus.scheduled => const Color(0xFFFF8F00),
  };
}

/// Satu sesi konsultasi antara dokter dan pasien.
class ConsultationSession {
  const ConsultationSession({
    required this.sessionId,
    required this.patientId,
    required this.patientName,
    required this.patientAge,
    required this.patientGender,
    required this.patientBloodType,
    required this.patientAllergies,
    required this.complaint,
    required this.scheduledTime,
    required this.consultationType,
    required this.status,
    required this.startedAt,
    this.completedAt,
    this.doctorNotes = '',
    this.diagnosisSummary = '',
    this.prescribedMedications = const [],
  });

  final String sessionId;
  final String patientId;
  final String patientName;
  final int patientAge;
  final String patientGender;
  final String patientBloodType;
  final List<String> patientAllergies;
  final String complaint;
  final String scheduledTime;
  final String consultationType; // 'Chat Online' | 'Video Call'
  final ConsultationStatus status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final String doctorNotes;
  final String diagnosisSummary;
  final List<String> prescribedMedications;

  ConsultationSession copyWith({
    ConsultationStatus? status,
    DateTime? startedAt,
    DateTime? completedAt,
    String? doctorNotes,
    String? diagnosisSummary,
    List<String>? prescribedMedications,
  }) {
    return ConsultationSession(
      sessionId: sessionId,
      patientId: patientId,
      patientName: patientName,
      patientAge: patientAge,
      patientGender: patientGender,
      patientBloodType: patientBloodType,
      patientAllergies: patientAllergies,
      complaint: complaint,
      scheduledTime: scheduledTime,
      consultationType: consultationType,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      doctorNotes: doctorNotes ?? this.doctorNotes,
      diagnosisSummary: diagnosisSummary ?? this.diagnosisSummary,
      prescribedMedications:
          prescribedMedications ?? this.prescribedMedications,
    );
  }
}

/// Satu pesan chat di dalam sesi konsultasi dokter–pasien.
class ConsultationMessage {
  const ConsultationMessage({
    required this.id,
    required this.sessionId,
    required this.text,
    required this.fromDoctor,
    required this.sentAt,
  });

  final String id;
  final String sessionId;
  final String text;

  /// `true` bila dikirim oleh dokter, `false` bila dari pasien.
  final bool fromDoctor;
  final DateTime sentAt;
}

/// Riwayat satu kunjungan konsultasi pasien ke dokter (bisa dokter lain).
class PastConsultationRecord {
  const PastConsultationRecord({
    required this.id,
    required this.doctorName,
    required this.specialization,
    required this.hospital,
    required this.date,
    required this.complaint,
    required this.diagnosis,
    required this.notes,
    required this.prescribedMedications,
    this.followUpDate,
  });

  final String id;
  final String doctorName;
  final String specialization;
  final String hospital;
  final DateTime date;
  final String complaint;
  final String diagnosis;
  final String notes;
  final List<String> prescribedMedications;
  final DateTime? followUpDate;
}

/// Obat historis (sudah selesai / dihentikan) pasien yang terlihat oleh dokter.
class PatientMedicationRecord {
  const PatientMedicationRecord({
    required this.id,
    required this.name,
    required this.dose,
    required this.frequency,
    required this.startDate,
    required this.endDate,
    required this.prescribedBy,
    required this.indication,
    required this.isActive,
    required this.color,
  });

  final String id;
  final String name;
  final String dose;
  final String frequency;
  final String startDate;
  final String endDate;
  final String prescribedBy; // nama dokter penulis resep
  final String indication; // indikasi / diagnosis terkait
  final bool isActive;
  final Color color;
}

/// Satu metrik rekam medis pasien (tekanan darah, berat badan, dll.).
class PatientVitalRecord {
  const PatientVitalRecord({
    required this.id,
    required this.metricName,
    required this.value,
    required this.unit,
    required this.date,
    required this.status,
    this.secondaryValue,
    this.note = '',
  });

  final String id;
  final String metricName;
  final double value;
  final String unit;
  final DateTime date;
  final String status; // 'Normal' | 'Perhatian' | 'Kritis'
  final double? secondaryValue; // diastolic untuk tekanan darah
  final String note;

  bool get isAbnormal => status != 'Normal';
}
