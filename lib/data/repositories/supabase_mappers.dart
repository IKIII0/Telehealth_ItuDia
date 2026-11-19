import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../models/consultation_session.dart';
import '../models/consultation_summary.dart';
import '../models/conversation.dart';
import '../models/doctor.dart';
import '../models/medication.dart';

/// Konversi baris Supabase (Map) menjadi model aplikasi.
///
/// Warna disimpan sebagai `bigint` (nilai ARGB) dan ikon sebagai nama
/// supaya tidak bergantung pada `IconData` yang tidak bisa diserialisasi.

const Map<String, IconData> _icons = {
  'medication': Icons.medication_rounded,
  'medication_liquid': Icons.medication_liquid_rounded,
  'pharmacy': Icons.local_pharmacy_rounded,
  'favorite': Icons.favorite_rounded,
  'water_drop': Icons.water_drop_rounded,
  'air': Icons.air_rounded,
};

IconData iconFromDb(String? name) => _icons[name] ?? Icons.medication_rounded;

String iconToDb(IconData icon) {
  for (final entry in _icons.entries) {
    if (entry.value.codePoint == icon.codePoint) return entry.key;
  }
  return 'medication';
}

Color colorFromDb(Object? value, {Color fallback = const Color(0xFF1E88E5)}) {
  if (value is num) return Color(value.toInt());
  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null) return Color(parsed);
  }
  return fallback;
}

int colorToDb(Color color) => color.toARGB32();

const List<String> _months = [
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

/// Format tanggal ringkas yang dipakai model, mis. "20 Sep 2024".
String formatShortDate(DateTime date) =>
    '${date.day} ${_months[date.month - 1]} ${date.year}';

Medication medicationFromRow(Map<String, dynamic> row) {
  final rawSchedules = row['medication_schedules'];
  final schedules = <MedicationSchedule>[];

  if (rawSchedules is List) {
    final sorted = rawSchedules.whereType<Map<String, dynamic>>().toList()
      ..sort(
        (a, b) => ((a['position'] as num?)?.toInt() ?? 0).compareTo(
          (b['position'] as num?)?.toInt() ?? 0,
        ),
      );
    for (final item in sorted) {
      schedules.add(
        MedicationSchedule(
          time: item['period'] as String? ?? 'Pagi',
          hour: item['hour'] as String? ?? '08:00',
          taken: item['taken'] as bool? ?? false,
        ),
      );
    }
  }

  final deletedAt = row['deleted_at'] == null
      ? null
      : DateTime.tryParse(row['deleted_at'].toString());

  return Medication(
    id: row['id'].toString(),
    name: row['name'] as String? ?? '',
    dose: row['dose'] as String? ?? '',
    frequency: row['frequency'] as String? ?? '',
    startDate: row['start_date'] as String? ?? '-',
    endDate: row['end_date'] as String? ?? '-',
    note: row['note'] as String? ?? '-',
    doctorId: row['doctor_id'] as String? ?? '',
    schedules: schedules,
    color: colorFromDb(row['color']),
    icon: iconFromDb(row['icon'] as String?),
    isDeleted: row['is_deleted'] as bool? ?? deletedAt != null,
    deletedAt: deletedAt == null ? null : formatShortDate(deletedAt),
  );
}

Doctor doctorFromRow(Map<String, dynamic> row) {
  return Doctor(
    id: row['id'].toString(),
    name: row['name'] as String? ?? '',
    specialization: row['specialization'] as String? ?? '',
    experience: (row['experience'] as num?)?.toInt() ?? 0,
    rating: (row['rating'] as num?)?.toDouble() ?? 0,
    price: (row['price'] as num?)?.toInt() ?? 0,
    available: row['available'] as bool? ?? false,
    hospital: row['hospital'] as String? ?? '',
    bio: row['bio'] as String? ?? '',
    education: row['education'] as String? ?? '',
    avatarColor: colorFromDb(row['avatar_color']),
  );
}

Conversation conversationFromRow(Map<String, dynamic> row) {
  return Conversation(
    id: row['id'].toString(),
    name: row['name'] as String? ?? '',
    role: row['role'] as String? ?? '',
    type: row['type'] as String? ?? '',
    lastMessage: row['last_message'] as String? ?? '',
    time: row['time_label'] as String? ?? '',
    unreadCount: (row['unread_count'] as num?)?.toInt() ?? 0,
    isOnline: row['is_online'] as bool? ?? false,
    initials: row['initials'] as String? ?? '',
    color: colorFromDb(row['color'], fallback: const Color(0xFF1E88E5)),
  );
}

ChatMessage chatMessageFromRow(Map<String, dynamic> row) {
  return ChatMessage(
    id: row['id'].toString(),
    conversationId: row['conversation_id'].toString(),
    text: row['body'] as String? ?? '',
    sender: ChatMessage.parseSender(
      row['sender'] as String?,
      fallbackIsMe: row['is_me'] as bool? ?? false,
    ),
    time: row['time_label'] as String? ?? '',
  );
}

ConsultationSummary consultationSummaryFromRow(Map<String, dynamic> row) {
  final rawPrescriptions = row['prescriptions'];
  final prescriptions = rawPrescriptions is List
      ? rawPrescriptions.map((e) => e.toString()).toList()
      : <String>[];

  return ConsultationSummary(
    id: row['id'].toString(),
    conversationId: row['conversation_id']?.toString(),
    patientName: row['patient_name'] as String? ?? '',
    doctorId: row['doctor_id']?.toString() ?? '',
    doctorName: row['doctor_name'] as String? ?? '',
    specialization: row['specialization'] as String? ?? '',
    diagnosis: row['diagnosis'] as String? ?? '',
    notes: row['notes'] as String? ?? '',
    prescriptions: prescriptions,
    advice: row['advice'] as String? ?? '',
    createdAt:
        DateTime.tryParse(row['created_at']?.toString() ?? '') ??
        DateTime.now(),
  );
}

// ── Sesi konsultasi dokter (tabel consultation_sessions) ─────────────────────

const Map<String, String> _vitalMetricNames = {
  'blood_pressure': 'Tekanan Darah',
  'blood_sugar': 'Gula Darah',
  'weight': 'Berat Badan',
  'heart_rate': 'Detak Jantung',
  'body_temperature': 'Suhu Tubuh',
};

const Map<String, String> _vitalStatusLabels = {
  'normal': 'Normal',
  'warning': 'Perhatian',
  'critical': 'Kritis',
};

String vitalMetricName(String metric) =>
    _vitalMetricNames[metric] ?? metric;

String vitalMetricToDb(String name) {
  for (final entry in _vitalMetricNames.entries) {
    if (entry.value == name) return entry.key;
  }
  return 'blood_pressure';
}

String vitalStatusToDb(String label) => switch (label) {
  'Kritis' => 'critical',
  'Perhatian' => 'warning',
  _ => 'normal',
};

DateTime? _parseDateTime(Object? value) =>
    value == null ? null : DateTime.tryParse(value.toString())?.toLocal();

String _twoDigits(int value) => value.toString().padLeft(2, '0');

/// Label waktu ringkas yang dipakai model, mis. "Hari ini, 09:30 WIB".
String _whenLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final label = switch (today.difference(day).inDays) {
    0 => 'Hari ini',
    1 => 'Kemarin',
    _ => '${date.day} ${_months[date.month - 1]}',
  };
  return '$label, ${_twoDigits(date.hour)}:${_twoDigits(date.minute)} WIB';
}

String _dateOnly(Object? value) {
  final parsed = _parseDateTime(value);
  return parsed == null ? '-' : formatShortDate(parsed);
}

ConsultationSession consultationSessionFromRow(Map<String, dynamic> row) {
  final status = switch (row['status']?.toString()) {
    'ongoing' => ConsultationStatus.ongoing,
    'completed' => ConsultationStatus.completed,
    'cancelled' || 'rejected' => ConsultationStatus.cancelled,
    'scheduled' => ConsultationStatus.scheduled,
    _ => ConsultationStatus.requested,
  };

  final requestedAt = _parseDateTime(row['requested_at']);
  final scheduledAt = _parseDateTime(row['scheduled_at']);
  final startedAt = _parseDateTime(row['started_at']);
  final shownAt = scheduledAt ?? requestedAt ?? startedAt ?? DateTime.now();

  final rawAllergies = row['patient_allergies'];
  final allergies = rawAllergies is List
      ? rawAllergies.map((e) => e.toString()).toList()
      : const <String>[];

  return ConsultationSession(
    sessionId: row['id'].toString(),
    patientId: row['patient_user_id']?.toString() ?? '',
    patientName: row['patient_name']?.toString() ?? 'Pasien',
    patientAge: (row['patient_age'] as num?)?.toInt() ?? 0,
    patientGender: switch (row['patient_gender']?.toString()) {
      'male' => 'Laki-laki',
      'female' => 'Perempuan',
      _ => '-',
    },
    patientBloodType: row['patient_blood_type']?.toString() ?? '-',
    patientAllergies: allergies,
    complaint: row['complaint']?.toString() ?? '',
    scheduledTime: _whenLabel(shownAt),
    consultationType: row['consultation_type'] == 'video'
        ? 'Video Call'
        : 'Chat Dokter',
    status: status,
    startedAt: startedAt ?? requestedAt ?? shownAt,
    completedAt: _parseDateTime(row['completed_at']),
    doctorNotes: row['doctor_notes']?.toString() ?? '',
    diagnosisSummary: row['diagnosis']?.toString() ?? '',
    priority: row['priority']?.toString() ?? '',
  );
}

ConsultationMessage consultationMessageFromRow(Map<String, dynamic> row) {
  return ConsultationMessage(
    id: row['id'].toString(),
    sessionId: row['session_id'].toString(),
    text: row['body']?.toString() ?? '',
    fromDoctor: row['sender_role'] == 'doctor',
    sentAt: _parseDateTime(row['created_at']) ?? DateTime.now(),
  );
}

/// Baris `patient_vital_records` → [PatientVitalRecord].
PatientVitalRecord vitalRecordFromRow(Map<String, dynamic> row) {
  return PatientVitalRecord(
    id: row['id'].toString(),
    metricName: vitalMetricName(row['metric']?.toString() ?? ''),
    value: (row['value'] as num?)?.toDouble() ?? 0,
    unit: row['unit']?.toString() ?? '',
    date: _parseDateTime(row['recorded_at']) ?? DateTime.now(),
    status: _vitalStatusLabels[row['status']?.toString()] ?? 'Normal',
    secondaryValue: (row['secondary_value'] as num?)?.toDouble(),
    note: row['note']?.toString() ?? '',
  );
}

/// Baris RPC `doctor_patient_consultation_history` → [PastConsultationRecord].
PastConsultationRecord pastConsultationFromRow(Map<String, dynamic> row) {
  final rawMeds = row['prescribed_medications'];
  final meds = rawMeds is List
      ? rawMeds.map((e) => e.toString()).toList()
      : const <String>[];

  return PastConsultationRecord(
    id: row['id'].toString(),
    doctorName: row['doctor_name']?.toString() ?? 'Dokter',
    specialization: row['specialization']?.toString() ?? '',
    hospital: row['hospital']?.toString() ?? '',
    date: _parseDateTime(row['consulted_at']) ?? DateTime.now(),
    complaint: row['complaint']?.toString() ?? '',
    diagnosis: row['diagnosis']?.toString() ?? '',
    notes: row['notes']?.toString() ?? '',
    prescribedMedications: meds,
    followUpDate: _parseDateTime(row['follow_up_date']),
  );
}

const List<Color> _medicationPalette = [
  Color(0xFF43A047),
  Color(0xFF1E88E5),
  Color(0xFFFF8F00),
  Color(0xFF8E24AA),
  Color(0xFFE53935),
];

/// Baris RPC `doctor_patient_medications` → [PatientMedicationRecord].
PatientMedicationRecord patientMedicationFromRow(
  Map<String, dynamic> row, {
  int index = 0,
}) {
  final frequency = (row['frequency_per_day'] as num?)?.toInt() ?? 1;
  return PatientMedicationRecord(
    id: row['id'].toString(),
    name: row['medication_name']?.toString() ?? '',
    dose: row['dose']?.toString() ?? '',
    frequency: '${frequency}x sehari',
    startDate: _dateOnly(row['start_date']),
    endDate: _dateOnly(row['end_date']),
    prescribedBy: row['prescribed_by']?.toString() ?? '',
    indication: row['indication']?.toString() ?? '',
    isActive: row['is_active'] as bool? ?? false,
    color: _medicationPalette[index % _medicationPalette.length],
  );
}
