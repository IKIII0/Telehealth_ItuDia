import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/material.dart';

import 'package:Telehealth/data/models/doctor_profile.dart';
import 'package:Telehealth/data/models/user.dart';
import 'package:Telehealth/data/services/auth_service.dart';

export 'package:Telehealth/data/services/auth_service.dart' show AuthException;

/// Status inisialisasi sesi autentikasi.
enum AuthStatus { unknown, unauthenticated, authenticated }

/// Pengelola sesi autentikasi berbasis Firebase Authentication.
///
/// [AuthService] menangani kredensial, sedangkan role pengguna disimpan di
/// Cloud Firestore pada koleksi `users/{uid}`:
///
/// ```json
/// { "uid": "...", "email": "...", "name": "...", "role": "doctor" }
/// ```
///
/// Nilai `role` yang dikenali adalah `patient` atau `doctor` (alias `pasien`
/// dan `dokter` juga diterima). Role dapat diubah langsung dari Firebase
/// Console tanpa mengubah kode. Bila dokumen atau field role belum ada,
/// aplikasi memakai role template akun demo (bila email cocok) atau `patient`.
class AuthRepository extends ChangeNotifier {
  AuthRepository._() : _authService = AuthService();

  static final AuthRepository instance = AuthRepository._();

  static const String _usersCollection = 'users';

  /// Batas waktu baca/tulis Firestore saat pemulihan sesi agar aplikasi tidak
  /// tertahan ketika jaringan atau Firestore tidak tersedia.
  static const Duration _firestoreTimeout = Duration(seconds: 5);

  /// Template akun demo untuk nama dan profil dokter.
  ///
  /// Role yang dipakai aplikasi berasal dari Firestore. Template ini hanya
  /// menyediakan role awal saat dokumen role pertama kali dibuat, serta data
  /// profil dokter (spesialisasi, STR, rumah sakit) yang tidak disimpan di
  /// Firestore.
  static const List<_AccountTemplate> _accounts = [
    _AccountTemplate(
      user: AppUser(
        id: 'user-patient',
        name: 'ItuDia',
        email: 'pasien@gmail.com',
        role: UserRole.patient,
        avatarColor: Color(0xFF36618E),
      ),
    ),
    _AccountTemplate(
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

  final AuthService _authService;

  AuthStatus _status = AuthStatus.unknown;
  AppUser? _currentUser;

  AuthStatus get status => _status;

  AppUser? get currentUser => _currentUser;

  bool get isAuthenticated =>
      _status == AuthStatus.authenticated && _currentUser != null;

  /// Diakses secara lazy agar aman sebelum `Firebase.initializeApp()`.
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  /// Memulihkan sesi dari Firebase. Dipanggil sekali saat startup.
  Future<void> restoreSession() async {
    try {
      final firebaseUser = _authService.currentUser;
      if (firebaseUser == null) {
        _currentUser = null;
        _status = AuthStatus.unauthenticated;
      } else {
        _currentUser = await _resolveUser(firebaseUser);
        _status = AuthStatus.authenticated;
      }
    } catch (error) {
      debugPrint('[AuthRepository] gagal memulihkan sesi: $error');
      _currentUser = null;
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  /// Masuk dengan akun Firebase yang sudah terdaftar.
  Future<AppUser> signIn({
    required String email,
    required String password,
    bool persist = true,
  }) async {
    final firebaseUser = await _authService.signInWithEmail(
      email: email,
      password: password,
      persist: persist,
    );

    final user = await _resolveUser(firebaseUser);
    _currentUser = user;
    _status = AuthStatus.authenticated;

    // Tidak memanggil notifyListeners di sini: navigasi setelah login
    // dilakukan eksplisit oleh halaman login agar tujuan awal (`from`)
    // tidak tertimpa redirect otomatis router.
    return user;
  }

  /// Mendaftarkan akun baru. Firebase langsung membuat sesi untuk akun baru,
  /// lalu dokumen role dibuat di Firestore.
  Future<AppUser> register({
    required String email,
    required String password,
    String? name,
  }) async {
    final firebaseUser = await _authService.signUpWithEmail(
      email: email,
      password: password,
      displayName: name,
    );

    final role = _fallbackRole(firebaseUser.email);
    await _writeUserDocument(firebaseUser, role: role);

    final user = _buildAppUser(firebaseUser, role);
    _currentUser = user;
    _status = AuthStatus.authenticated;

    return user;
  }

  Future<void> signOut() async {
    try {
      await _authService.signOut();
    } catch (_) {
      // Sesi lokal tetap diakhiri meskipun Firebase gagal dihubungi.
    }
    _currentUser = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// Menentukan role dari Firestore. Dokumen dibuat otomatis bila belum ada
  /// (mis. akun yang dibuat lewat Firebase Console) agar role-nya dapat diubah
  /// dari Console.
  Future<AppUser> _resolveUser(User firebaseUser) async {
    final data = await _readUserDocument(firebaseUser.uid);
    final storedRole = parseRole(data?['role']);
    if (storedRole != null) {
      return _buildAppUser(firebaseUser, storedRole);
    }

    final role = _fallbackRole(firebaseUser.email);
    await _writeUserDocument(firebaseUser, role: role);
    return _buildAppUser(firebaseUser, role);
  }

  Future<Map<String, dynamic>?> _readUserDocument(String uid) async {
    try {
      final snapshot = await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .get()
          .timeout(_firestoreTimeout);
      return snapshot.data();
    } catch (error) {
      debugPrint('[AuthRepository] gagal membaca role dari Firestore: $error');
      return null;
    }
  }

  Future<void> _writeUserDocument(User user, {required UserRole role}) async {
    final email = user.email ?? '';
    final displayName = user.displayName?.trim();
    final name =
        _findByEmail(email)?.user.name ??
        ((displayName == null || displayName.isEmpty)
            ? _nameFromEmail(email)
            : displayName);

    try {
      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .set({
            'uid': user.uid,
            'email': email,
            'name': name,
            'role': role.name,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(_firestoreTimeout);
    } catch (error) {
      // Pendaftaran/login tetap berhasil; role akan memakai nilai template
      // sampai dokumen Firestore berhasil dibuat.
      debugPrint('[AuthRepository] gagal menyimpan role ke Firestore: $error');
    }
  }

  static AppUser _buildAppUser(User firebaseUser, UserRole role) {
    final template = _findByEmail(firebaseUser.email)?.user;
    final email = firebaseUser.email ?? template?.email ?? '';
    final displayName = firebaseUser.displayName?.trim();

    return AppUser(
      id: firebaseUser.uid,
      name:
          template?.name ??
          ((displayName == null || displayName.isEmpty)
              ? _nameFromEmail(email)
              : displayName),
      email: email,
      role: role,
      avatarColor: template?.avatarColor ?? const Color(0xFF1E88E5),
      doctorProfile: role == UserRole.doctor ? template?.doctorProfile : null,
    );
  }

  /// Role awal saat dokumen Firestore pertama kali dibuat.
  static UserRole _fallbackRole(String? email) =>
      _findByEmail(email)?.user.role ?? UserRole.patient;

  /// Membaca nilai `role` dari Firestore. Mengembalikan `null` bila kosong
  /// atau tidak dikenali sehingga pemanggil dapat memakai role awal.
  @visibleForTesting
  static UserRole? parseRole(Object? value) {
    if (value is! String) return null;
    return switch (value.trim().toLowerCase()) {
      'doctor' || 'dokter' => UserRole.doctor,
      'patient' || 'pasien' => UserRole.patient,
      _ => null,
    };
  }

  /// Nama tampilan awal dari bagian lokal email, mis. `budi@mail.com` → `Budi`.
  static String _nameFromEmail(String email) {
    final localPart = email.split('@').first;
    if (localPart.isEmpty) return 'Pengguna';
    return localPart[0].toUpperCase() + localPart.substring(1);
  }

  static _AccountTemplate? _findByEmail(String? email) {
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

class _AccountTemplate {
  const _AccountTemplate({required this.user});

  final AppUser user;
}
