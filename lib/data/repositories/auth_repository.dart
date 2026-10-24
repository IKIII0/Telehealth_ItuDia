import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:Telehealth/data/models/doctor_profile.dart';
import 'package:Telehealth/data/models/user.dart';
import 'package:Telehealth/data/repositories/simulated_api.dart';

/// Status inisialisasi sesi autentikasi.
enum AuthStatus { unknown, unauthenticated, authenticated }

/// Kesalahan autentikasi yang dapat ditampilkan ke pengguna.
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Pengelola sesi autentikasi simulasi.
///
/// Akun demo menjadi sumber role. Hanya email yang disimpan di penyimpanan
/// aman; data akun lainnya dibaca ulang dari daftar akun demo saat aplikasi
/// dimulai. Tidak ada operasi jaringan di sini.
class AuthRepository extends ChangeNotifier {
  AuthRepository._();

  static final AuthRepository instance = AuthRepository._();

  static const String _storageKey = 'auth_email';

  static const List<_DemoAccount> _accounts = [
    _DemoAccount(
      password: '123456',
      user: AppUser(
        id: 'user-patient',
        name: 'ItuDia',
        email: 'pasien@gmail.com',
        role: UserRole.patient,
        avatarColor: Color(0xFF36618E),
      ),
    ),
    _DemoAccount(
      password: '123456',
      user: AppUser(
        id: 'user-doctor',
        name: 'dr. Rifki Al Sauqy, Sp.JP',
        email: 'dokter@gmail.com',
        role: UserRole.doctor,
        avatarColor: Color(0xFFE53935),
        doctorProfile: DoctorProfile(
          doctorId: 'doc1',
          specialization: 'Spesialis Jantung',
          strNumber: 'STR-2024-16284',
          hospital: 'RS Jantung Harapan Kita',
          experienceYears: 12,
          bio:
              'Spesialis jantung berpengalaman dalam penanganan penyakit '
              'jantung koroner, aritmia, dan gagal jantung.',
          practiceSchedule: {
            'Senin - Jumat': '09:00 - 15:00',
            'Sabtu': '09:00 - 12:00',
          },
          phone: '+62 812 9000 1122',
        ),
      ),
    ),
  ];

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  AuthStatus _status = AuthStatus.unknown;
  AppUser? _currentUser;

  AuthStatus get status => _status;

  AppUser? get currentUser => _currentUser;

  bool get isAuthenticated =>
      _status == AuthStatus.authenticated && _currentUser != null;

  /// Memulihkan sesi dari penyimpanan aman. Dipanggil sekali saat startup.
  Future<void> restoreSession() async {
    String? email;
    try {
      email = await _storage.read(key: _storageKey);
    } catch (_) {
      email = null;
    }

    final account = _findByEmail(email);
    if (account != null) {
      _currentUser = account.user;
      _status = AuthStatus.authenticated;
    } else {
      _currentUser = null;
      _status = AuthStatus.unauthenticated;
      if (email != null) {
        try {
          await _storage.delete(key: _storageKey);
        } catch (_) {
          // Penyimpanan tidak tersedia; sesi tetap dianggap berakhir.
        }
      }
    }
    notifyListeners();
  }

  /// Login memakai akun demo. [persist] menentukan apakah sesi disimpan
  /// untuk dipulihkan saat aplikasi dibuka kembali.
  Future<AppUser> signIn({
    required String email,
    required String password,
    bool persist = true,
  }) async {
    await SimulatedApi.run(() => true);

    final account = _findByEmail(email);
    if (account == null || account.password != password) {
      throw const AuthException('Email atau password salah.');
    }

    _currentUser = account.user;
    _status = AuthStatus.authenticated;

    if (persist) {
      try {
        await _storage.write(key: _storageKey, value: account.user.email);
      } catch (_) {
        // Gagal menyimpan sesi tidak menghalangi login pada sesi berjalan.
      }
    }

    // Tidak memanggil notifyListeners di sini: navigasi setelah login
    // dilakukan eksplisit oleh halaman login agar tujuan awal (`from`)
    // tidak tertimpa redirect otomatis router.
    return account.user;
  }

  Future<void> signOut() async {
    try {
      await _storage.delete(key: _storageKey);
    } catch (_) {
      // Tetap lanjutkan logout di memori.
    }
    _currentUser = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  static _DemoAccount? _findByEmail(String? email) {
    if (email == null) return null;
    final normalized = email.trim().toLowerCase();
    for (final account in _accounts) {
      if (account.user.email.toLowerCase() == normalized) {
        return account;
      }
    }
    return null;
  }
}

class _DemoAccount {
  const _DemoAccount({required this.user, required this.password});

  final AppUser user;
  final String password;
}
