import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MissingPluginException;

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
  AuthService({FirebaseAuth? auth}) : _authOverride = auth;

  final FirebaseAuth? _authOverride;

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
  }) async {
    try {
      _ensureInitialized();

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthException('Pendaftaran gagal. Silakan coba lagi.');
      }

      final name = displayName?.trim();
      if (name != null && name.isNotEmpty) {
        // Akun sudah terbuat pada titik ini. Kegagalan menyimpan nama tampilan
        // tidak boleh membuat pendaftaran terlihat gagal.
        try {
          await user.updateDisplayName(name);
          await user.reload();
          return _auth.currentUser ?? user;
        } catch (error) {
          _logFailure('updateDisplayName', error);
        }
      }
      return user;
    } catch (error) {
      _logFailure('signUpWithEmail', error);
      throw AuthException(messageFor(error));
    }
  }

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
