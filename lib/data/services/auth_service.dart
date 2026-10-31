import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import 'package:Telehealth/core/supabase/supabase_config.dart';
import 'package:Telehealth/data/models/registration_data.dart';
import 'package:Telehealth/data/models/user.dart';

/// Kesalahan autentikasi dengan pesan yang siap ditampilkan ke pengguna.
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Pembungkus Firebase Authentication untuk masuk/daftar dengan email dan
/// kata sandi.
///
/// Seluruh kegagalan Firebase diterjemahkan menjadi [AuthException] dengan
/// pesan berbahasa Indonesia agar lapisan UI tidak perlu mengetahui kode error
/// Firebase.
class AuthService {
  AuthService({FirebaseAuth? auth, SupabaseClient? supabase})
    : _authOverride = auth,
      _supabaseOverride = supabase;

  final FirebaseAuth? _authOverride;
  final SupabaseClient? _supabaseOverride;

  /// Batas waktu tulis ke Supabase agar pendaftaran tidak menggantung ketika
  /// jaringan lambat. Kegagalan sinkronisasi tidak membatalkan akun Firebase.
  static const Duration _supabaseTimeout = Duration(seconds: 8);

  SupabaseClient? get _supabase => _supabaseOverride ?? SupabaseConfig.client;

  /// Diakses secara lazy agar objek ini aman dibuat sebelum
  /// `Firebase.initializeApp()` selesai (misalnya pada unit test).
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  /// Akun Firebase yang sedang masuk, atau `null` bila belum ada sesi.
  User? get currentUser => _auth.currentUser;

  /// Memastikan `Firebase.initializeApp()` sudah berhasil.
  ///
  /// Tanpa pengecekan ini pengguna hanya melihat pesan generik ketika
  /// aplikasi dijalankan di platform yang belum dikonfigurasi (mis. desktop).
  static void _ensureInitialized() {
    if (Firebase.apps.isEmpty) {
      throw const AuthException(
        'Firebase belum siap. Jalankan aplikasi di Android/iOS dengan '
        'konfigurasi Firebase yang valid.',
      );
    }
  }

  /// Perubahan sesi dari Firebase (login, logout, token diperbarui).
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Mendaftarkan akun baru. Firebase otomatis membuat sesi untuk akun baru,
  /// sehingga pengguna langsung dianggap masuk setelah pendaftaran berhasil.
  Future<User> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
    RegistrationData? profile,
  }) async {
    try {
      _ensureInitialized();

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final createdUser = credential.user;
      if (createdUser == null) {
        throw const AuthException('Pendaftaran gagal. Silakan coba lagi.');
      }
      var user = createdUser;

      final name = displayName?.trim();
      if (name != null && name.isNotEmpty) {
        // Akun sudah terbuat pada titik ini. Kegagalan menyimpan nama tampilan
        // tidak boleh membuat pendaftaran terlihat gagal.
        try {
          await user.updateDisplayName(name);
          await user.reload();
          user = _auth.currentUser ?? user;
        } catch (error) {
          _logFailure('updateDisplayName', error);
        }
      }

      // Salin profil ke Supabase setelah akun Firebase pasti ada. Kegagalan di
      // sini tidak melempar exception karena akun Firebase sudah terlanjur
      // dibuat; repository hanya perlu memberi tahu bahwa sinkronisasi gagal.
      if (profile != null) {
        final synced = await syncProfileToSupabase(user: user, data: profile);
        if (!synced) {
          debugPrint(
            '[AuthService] akun Firebase dibuat, tetapi profil Supabase belum '
            'tersinkronisasi. Panggil syncProfileToSupabase() lagi (mis. dari '
            'halaman edit profil) untuk menyusul.',
          );
        }
      }
      return user;
    } catch (error) {
      _logFailure('signUpWithEmail', error);
      throw AuthException(messageFor(error));
    }
  }

  /// Menyimpan profil pengguna ke Supabase secara idempoten.
  ///
  /// [profiles] adalah tabel induk; tabel role-specific hanya disentuh sesuai
  /// role sehingga akun pasien tidak pernah membuat baris dokter (dan
  /// sebaliknya). Semua pemanggilan memakai `upsert` agar aman dijalankan
  /// ulang tanpa duplikasi.
  ///
  /// Mengembalikan `true` bila seluruh penulisan berhasil. Method ini tidak
  /// melempar exception agar kegagalan Supabase tidak membatalkan pendaftaran
  /// Firebase yang sudah berhasil.
  Future<bool> syncProfileToSupabase({
    required User user,
    required RegistrationData data,
  }) async {
    final db = _supabase;
    if (db == null) {
      debugPrint(
        '[AuthService] Supabase belum dikonfigurasi; profil hanya tersimpan '
        'di Firebase.',
      );
      return false;
    }

    final role = data.role ?? UserRole.patient;
    try {
      await db
          .from('profiles')
          .upsert(_profileRow(user, data, role), onConflict: 'id')
          .timeout(_supabaseTimeout);

      switch (role) {
        case UserRole.doctor:
          await db
              .from('doctor_profiles')
              .upsert(_doctorRow(user.uid, data), onConflict: 'user_id')
              .timeout(_supabaseTimeout);
        case UserRole.patient:
          await db
              .from('patient_profiles')
              .upsert(_patientRow(user.uid, data), onConflict: 'user_id')
              .timeout(_supabaseTimeout);
      }
      return true;
    } catch (error) {
      _logFailure('syncProfileToSupabase', error);
      return false;
    }
  }

  static Map<String, dynamic> _profileRow(
    User user,
    RegistrationData data,
    UserRole role,
  ) {
    final phone = _clean(data.phone);
    final address = _clean(data.address);
    final bloodType = _clean(data.bloodType);
    final gender = _genderToDb(data.gender);

    return {
      'id': user.uid,
      'email': _firstNonEmpty([data.email, user.email]),
      'full_name': _firstNonEmpty([data.name, user.displayName]),
      'role': role.name,
      if (phone != null) 'phone': phone,
      if (data.birthDate != null) 'birth_date': _dateOnly(data.birthDate!),
      if (gender != null) 'gender': gender,
      if (address != null) 'address': address,
      if (bloodType != null) 'blood_type': bloodType,
      'updated_at': _nowIso(),
    };
  }

  static Map<String, dynamic> _doctorRow(String uid, RegistrationData data) {
    final specialization = _clean(data.specialization);
    final strNumber = _clean(data.strNumber);
    final hospital = _clean(data.hospital);
    final bio = _clean(data.bio);
    final directoryId = _clean(data.directoryDoctorId);

    final schedule = <String, String>{};
    for (final entry in data.practiceSchedule.entries) {
      final day = _clean(entry.key);
      final hours = _clean(entry.value);
      if (day != null && hours != null) schedule[day] = hours;
    }

    return {
      'user_id': uid,
      if (specialization != null) 'specialization': specialization,
      if (strNumber != null) 'str_number': strNumber,
      if (hospital != null) 'hospital': hospital,
      if (data.experienceYears != null)
        'experience_years': data.experienceYears,
      if (bio != null) 'bio': bio,
      if (schedule.isNotEmpty) 'practice_schedule': schedule,
      if (directoryId != null) 'directory_doctor_id': directoryId,
      'updated_at': _nowIso(),
    };
  }

  static Map<String, dynamic> _patientRow(String uid, RegistrationData data) {
    final history = _clean(data.medicalHistory);
    final contactName = _clean(data.emergencyContactName);
    final contactPhone = _clean(data.emergencyContactPhone);

    return {
      'user_id': uid,
      'allergies': _cleanList(data.allergies),
      'chronic_conditions': _cleanList(data.chronicConditions),
      if (history != null) 'medical_history': history,
      if (contactName != null) 'emergency_contact_name': contactName,
      if (contactPhone != null) 'emergency_contact_phone': contactPhone,
      'updated_at': _nowIso(),
    };
  }

  static String? _clean(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static List<String> _cleanList(List<String> values) {
    final result = <String>[];
    for (final value in values) {
      final cleaned = _clean(value);
      if (cleaned != null) result.add(cleaned);
    }
    return result;
  }

  static String _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final cleaned = _clean(value);
      if (cleaned != null) return cleaned;
    }
    return '';
  }

  static String? _genderToDb(String? value) {
    final normalized = _clean(value)?.toLowerCase();
    return switch (normalized) {
      null => null,
      'laki-laki' || 'male' || 'pria' => 'male',
      'perempuan' || 'female' || 'wanita' => 'female',
      _ => 'other',
    };
  }

  static String _dateOnly(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static String _nowIso() => DateTime.now().toUtc().toIso8601String();

  /// Masuk dengan akun yang sudah terdaftar.
  ///
  /// [persist] hanya berpengaruh di web; di Android/iOS sesi Firebase selalu
  /// disimpan secara lokal oleh SDK.
  Future<User> signInWithEmail({
    required String email,
    required String password,
    bool persist = true,
  }) async {
    try {
      _ensureInitialized();

      if (kIsWeb) {
        await _auth.setPersistence(
          persist ? Persistence.LOCAL : Persistence.SESSION,
        );
      }

      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthException('Login gagal. Silakan coba lagi.');
      }
      return user;
    } catch (error) {
      _logFailure('signInWithEmail', error);
      throw AuthException(messageFor(error));
    }
  }

  /// Mengakhiri sesi Firebase pada perangkat ini.
  Future<void> signOut() async {
    try {
      _ensureInitialized();
      await _auth.signOut();
    } catch (error) {
      _logFailure('signOut', error);
      throw AuthException(messageFor(error));
    }
  }

  /// Menulis kode error asli ke konsol agar penyebab kegagalan mudah dilacak
  /// (`flutter run` → tab Logs/Debug Console).
  static void _logFailure(String operation, Object error) {
    if (error is FirebaseAuthException) {
      debugPrint(
        '[AuthService] $operation gagal: ${error.code} — ${error.message}',
      );
    } else {
      debugPrint('[AuthService] $operation gagal: $error');
    }
  }

  /// Mengubah error Firebase menjadi pesan yang ramah pengguna.
  static String messageFor(Object error) {
    if (error is AuthException) {
      return error.message;
    }

    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'email-already-in-use' => 'Email sudah terdaftar. Silakan masuk.',
        'invalid-email' => 'Format email tidak valid.',
        'weak-password' =>
          'Kata sandi terlalu lemah. Gunakan minimal 6 karakter.',
        'wrong-password' ||
        'invalid-credential' => 'Email atau kata sandi salah.',
        'user-not-found' => 'Akun dengan email tersebut tidak ditemukan.',
        'user-disabled' => 'Akun ini telah dinonaktifkan.',
        'too-many-requests' =>
          'Terlalu banyak percobaan. Silakan coba lagi nanti.',
        'network-request-failed' =>
          'Tidak ada koneksi internet. Periksa jaringan Anda.',
        'operation-not-allowed' ||
        'configuration-not-found' ||
        'admin-restricted-operation' =>
          'Metode Email/Password belum diaktifkan. Aktifkan di Firebase '
              'Console → Authentication → Sign-in method.',
        'api-key-not-valid' || 'invalid-api-key' =>
          'Konfigurasi Firebase tidak valid (API key). Periksa ulang '
              'google-services.json.',
        'app-not-authorized' =>
          'Aplikasi ini tidak diizinkan memakai Firebase Authentication. '
              'Periksa paket aplikasi dan SHA-1 di Firebase Console.',
        'channel-error' || 'internal-error' =>
          'Layanan autentikasi tidak dapat dihubungi. Pastikan perangkat '
              'memiliki Google Play Services dan koneksi internet.',
        'invalid-phone-number' || 'missing-phone-number' =>
          'Nomor telepon tidak valid. Gunakan format internasional, '
              'mis. +628123456789.',
        'invalid-verification-code' || 'code-expired' =>
          'Kode OTP salah atau sudah kedaluwarsa. Periksa kembali atau minta '
              'kode baru.',
        'invalid-verification-id' || 'session-expired' =>
          'Sesi verifikasi sudah berakhir. Silakan minta kode OTP baru.',
        'quota-exceeded' =>
          'Kuota pengiriman OTP habis. Coba lagi beberapa saat lagi.',
        'captcha-check-failed' =>
          'Verifikasi keamanan gagal. Muat ulang aplikasi lalu coba lagi.',
        'requires-recent-login' =>
          'Sesi verifikasi sudah terlalu lama. Lakukan verifikasi ulang.',
        'credential-already-in-use' || 'provider-already-linked' =>
          'Nomor telepon ini sudah tertaut ke akun lain.',
        _ => 'Terjadi kesalahan saat autentikasi. Silakan coba lagi.',
      };
    }

    if (error is FirebaseException) {
      return switch (error.code) {
        'no-app' || 'not-initialized' =>
          'Firebase belum diinisialisasi. Jalankan ulang aplikasi setelah '
              'konfigurasi Firebase terpasang.',
        _ => 'Terjadi kesalahan pada layanan Firebase. Silakan coba lagi.',
      };
    }

    if (error is MissingPluginException) {
      return 'Plugin Firebase Auth belum terpasang. Hentikan aplikasi, lalu '
          'jalankan ulang (bukan hot reload) agar build baru terpasang.';
    }

    return 'Terjadi kesalahan saat autentikasi. Silakan coba lagi.';
  }
}
