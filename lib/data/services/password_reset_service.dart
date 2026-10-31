import 'package:Telehealth/core/supabase/supabase_config.dart';
import 'package:Telehealth/data/models/reset_account.dart';
import 'package:Telehealth/data/services/auth_service.dart'
    show AuthException, AuthService;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Layanan reset password berbasis tautan email Firebase.
///
/// Tabel `profiles` hanya dipakai untuk mencari akun dan menampilkan email
/// resmi dalam bentuk tersamarkan. Pengiriman tautan dan perubahan kata sandi
/// sepenuhnya ditangani Firebase Authentication.
class PasswordResetService {
  PasswordResetService({
    FirebaseAuth? firebaseAuth,
    sb.SupabaseClient? supabase,
  }) : _firebaseAuthOverride = firebaseAuth,
       _supabaseOverride = supabase;

  final FirebaseAuth? _firebaseAuthOverride;
  final sb.SupabaseClient? _supabaseOverride;

  static final RegExp _emailPattern = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

  sb.SupabaseClient? get _supabase =>
      _supabaseOverride ?? SupabaseConfig.client;

  FirebaseAuth get _auth => _firebaseAuthOverride ?? FirebaseAuth.instance;

  static void _ensureFirebaseReady() {
    if (Firebase.apps.isEmpty) {
      throw const AuthException(
        'Firebase belum siap. Jalankan aplikasi di Android/iOS dengan '
        'konfigurasi Firebase yang valid.',
      );
    }
  }

  sb.SupabaseClient _requireSupabase() {
    final client = _supabase;
    if (client == null) {
      throw const AuthException(
        'Supabase belum dikonfigurasi. Isi SUPABASE_URL dan '
        'SUPABASE_ANON_KEY pada file .env terlebih dahulu.',
      );
    }
    return client;
  }

  /// Menyamarkan email, mis. `farhan@gmail.com` → `f***n@gmail.com`.
  static String maskEmail(String email) {
    final normalized = email.trim();
    final at = normalized.indexOf('@');
    if (at <= 0) return normalized;
    final local = normalized.substring(0, at);
    final domain = normalized.substring(at);
    if (local.length <= 2) {
      return '${local[0]}***$domain';
    }
    return '${local[0]}***${local[local.length - 1]}$domain';
  }

  /// Mencari akun berdasarkan email pada tabel `profiles`.
  ///
  /// Mengembalikan `null` bila email tidak terdaftar atau akun nonaktif.
  Future<ResetAccount?> findAccountByEmail(String input) async {
    final client = _requireSupabase();
    final email = input.trim().toLowerCase();
    if (email.isEmpty) {
      throw const AuthException('Email tidak boleh kosong.');
    }
    if (!_emailPattern.hasMatch(email)) {
      throw const AuthException('Format email tidak valid.');
    }

    try {
      // Escape wildcard LIKE agar input pengguna tidak menjadi pola pencarian.
      final pattern = email
          .replaceAll(r'\', r'\\')
          .replaceAll('%', r'\%')
          .replaceAll('_', r'\_');
      final rows = await client
          .from('profiles')
          .select('id,email,full_name,is_active')
          .ilike('email', pattern)
          .limit(2);

      if (rows.length > 1) {
        throw const AuthException(
          'Email terhubung ke lebih dari satu akun. Hubungi admin.',
        );
      }
      if (rows.isEmpty) return null;

      final row = rows.first;
      if (row['is_active'] == false) return null;

      final uid = (row['id'] as String?)?.trim() ?? '';
      final officialEmail = (row['email'] as String?)?.trim() ?? '';
      if (uid.isEmpty || officialEmail.isEmpty) return null;

      return ResetAccount(
        uid: uid,
        email: officialEmail,
        fullName: (row['full_name'] as String?)?.trim() ?? '',
      );
    } on sb.PostgrestException catch (error) {
      _logFailure('findAccountByEmail', error);
      throw const AuthException(
        'Gagal membaca data akun. Pastikan tabel profiles dapat diakses.',
      );
    } catch (error) {
      if (error is AuthException) rethrow;
      _logFailure('findAccountByEmail', error);
      throw const AuthException(
        'Gagal mencari akun. Periksa koneksi internet Anda lalu coba lagi.',
      );
    }
  }

  /// Mengirim tautan reset password resmi dari Firebase ke email akun.
  ///
  /// Pengguna membuka tautan, membuat kata sandi baru pada halaman Firebase,
  /// lalu kembali ke aplikasi untuk masuk. Tidak ada OTP yang dikelola client.
  Future<void> sendPasswordResetLink({required String email}) async {
    _ensureFirebaseReady();
    final normalized = email.trim().toLowerCase();
    if (!_emailPattern.hasMatch(normalized)) {
      throw const AuthException('Format email tidak valid.');
    }

    try {
      await _auth.sendPasswordResetEmail(email: normalized);
      debugPrint('[PasswordResetService] tautan reset dikirim ke $normalized');
    } on FirebaseAuthException catch (error) {
      _logFailure('sendPasswordResetLink', error);
      throw AuthException(AuthService.messageFor(error));
    } catch (error) {
      _logFailure('sendPasswordResetLink', error);
      throw const AuthException(
        'Gagal mengirim tautan reset. Periksa koneksi internet Anda.',
      );
    }
  }

  static void _logFailure(String operation, Object error) {
    if (error is FirebaseAuthException) {
      debugPrint(
        '[PasswordResetService] $operation gagal: ${error.code} — '
        '${error.message}',
      );
    } else {
      debugPrint('[PasswordResetService] $operation gagal: $error');
    }
  }
}
