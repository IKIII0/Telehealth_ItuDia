import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_config.dart';
import '../models/doctor_profile.dart';
import 'auth_repository.dart';

/// Pengaturan praktik dokter (preferensi + kuota harian).
class DoctorSettings {
  const DoctorSettings({
    this.acceptingConsultations = true,
    this.notifyNewRequest = true,
    this.notifyChatMessage = true,
    this.autoSummarize = true,
    this.dailyQuota = 12,
  });

  final bool acceptingConsultations;
  final bool notifyNewRequest;
  final bool notifyChatMessage;
  final bool autoSummarize;
  final int dailyQuota;
}

/// Repository profil & pengaturan dokter di Supabase.
///
/// `null` client berarti aplikasi memakai data lokal (mode simulasi).
class DoctorProfileRepository {
  DoctorProfileRepository._();
  static final DoctorProfileRepository instance = DoctorProfileRepository._();

  SupabaseClient? get _db =>
      SupabaseConfig.firebaseAuthClient ?? SupabaseConfig.client;

  bool get isRemote => _db != null;

  String? get _uid => AuthRepository.instance.currentUser?.id;

  static Map<String, String> _scheduleFrom(Object? raw) {
    if (raw is! Map) return const {};
    return raw.map((key, value) => MapEntry(key.toString(), value.toString()));
  }

  /// Ambil profil dokter milik akun yang login.
  Future<DoctorProfile?> fetchMine() async {
    final db = _db;
    final uid = _uid;
    if (db == null || uid == null) return null;

    final row = await db
        .from('doctor_profiles')
        .select()
        .eq('user_id', uid)
        .maybeSingle();
    if (row == null) return null;

    return DoctorProfile(
      doctorId: row['directory_doctor_id']?.toString() ?? '',
      specialization: row['specialization']?.toString() ?? '',
      strNumber: row['str_number']?.toString() ?? '',
      hospital: row['hospital']?.toString() ?? '',
      experienceYears: (row['experience_years'] as num?)?.toInt() ?? 0,
      bio: row['bio']?.toString() ?? '',
      practiceSchedule: _scheduleFrom(row['practice_schedule']),
      phone: '',
      verified: row['verified'] as bool? ?? false,
    );
  }

  /// Ambil preferensi praktik dokter.
  Future<DoctorSettings?> fetchSettings() async {
    final db = _db;
    final uid = _uid;
    if (db == null || uid == null) return null;

    final row = await db
        .from('doctor_profiles')
        .select(
          'accepting_consultations, notify_new_request, notify_chat_message, '
          'auto_summarize, daily_quota',
        )
        .eq('user_id', uid)
        .maybeSingle();
    if (row == null) return null;

    return DoctorSettings(
      acceptingConsultations: row['accepting_consultations'] as bool? ?? true,
      notifyNewRequest: row['notify_new_request'] as bool? ?? true,
      notifyChatMessage: row['notify_chat_message'] as bool? ?? true,
      autoSummarize: row['auto_summarize'] as bool? ?? true,
      dailyQuota: (row['daily_quota'] as num?)?.toInt() ?? 12,
    );
  }

  /// Simpan data profil (kredensial, bio, jadwal) dan nama/telepon akun.
  Future<void> saveProfile({
    required String name,
    required String phone,
    required String specialization,
    required String strNumber,
    required String hospital,
    required int experienceYears,
    required String bio,
    Map<String, String> practiceSchedule = const {},
  }) async {
    final db = _db;
    final uid = _uid;
    if (db == null || uid == null) return;

    await db.from('doctor_profiles').upsert({
      'user_id': uid,
      'specialization': specialization,
      'str_number': strNumber,
      'hospital': hospital,
      'experience_years': experienceYears,
      'bio': bio,
      'practice_schedule': practiceSchedule,
    }, onConflict: 'user_id');

    await db
        .from('profiles')
        .update({'full_name': name, 'phone': phone.isEmpty ? null : phone})
        .eq('id', uid);
  }

  /// Simpan jadwal praktik saja.
  Future<void> saveSchedule(Map<String, String> practiceSchedule) async {
    final db = _db;
    final uid = _uid;
    if (db == null || uid == null) return;

    await db
        .from('doctor_profiles')
        .update({'practice_schedule': practiceSchedule})
        .eq('user_id', uid);
  }

  /// Simpan preferensi praktik (status menerima pasien, notifikasi, kuota).
  Future<void> saveSettings({
    required bool acceptingConsultations,
    required bool notifyNewRequest,
    required bool notifyChatMessage,
    required bool autoSummarize,
    required int dailyQuota,
  }) async {
    final db = _db;
    final uid = _uid;
    if (db == null || uid == null) return;

    await db
        .from('doctor_profiles')
        .update({
          'accepting_consultations': acceptingConsultations,
          'notify_new_request': notifyNewRequest,
          'notify_chat_message': notifyChatMessage,
          'auto_summarize': autoSummarize,
          'daily_quota': dailyQuota,
        })
        .eq('user_id', uid);
  }
}
