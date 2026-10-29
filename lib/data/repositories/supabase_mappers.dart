import 'package:flutter/material.dart';

import '../models/chat_message.dart';
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
    isMe: row['is_me'] as bool? ?? false,
    time: row['time_label'] as String? ?? '',
  );
}
