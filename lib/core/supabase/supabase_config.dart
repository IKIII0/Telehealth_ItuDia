import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Inisialisasi koneksi Supabase.
///
/// Kredensial dibaca dari `.env` di root project (lihat `.env` lokal —
/// file ini tidak di-commit). Bila `.env` tidak ada atau kosong, aplikasi
/// tetap berjalan memakai data simulasi lokal.
class SupabaseConfig {
  SupabaseConfig._();

  static bool _ready = false;
  static SupabaseClient? _firebaseClient;

  /// `true` bila Supabase berhasil diinisialisasi dan siap dipakai.
  static bool get isReady => _ready;

  /// Client aktif, atau `null` bila Supabase tidak dikonfigurasi.
  static SupabaseClient? get client {
    if (!_ready) return null;
    return Supabase.instance.client;
  }

  /// Client Supabase yang memakai Firebase ID token sebagai bearer token
  /// (Supabase Third-Party Auth).
  ///
  /// Dipakai khusus modul Web Dashboard Admin Rumah Sakit agar RLS Supabase
  /// mengenali `auth.jwt() ->> 'sub'` sebagai Firebase UID. Client utama
  /// ([client]) tidak diubah supaya modul pasien dan dokter tetap berjalan
  /// seperti sebelumnya.
  ///
  /// Mengembalikan `null` bila Supabase belum dikonfigurasi; pemanggil
  /// sebaiknya memakai data demo lokal.
  static SupabaseClient? get firebaseAuthClient {
    if (!_ready) return null;

    final url = dotenv.maybeGet('SUPABASE_URL') ?? '';
    final anonKey = dotenv.maybeGet('SUPABASE_ANON_KEY') ?? '';
    if (url.isEmpty || anonKey.isEmpty) return null;

    return _firebaseClient ??= SupabaseClient(
      url,
      anonKey,
      accessToken: _firebaseIdToken,
    );
  }

  /// Token yang dikirim ke Supabase. `getIdToken()` otomatis memperbarui
  /// token bila sudah kedaluwarsa.
  static Future<String?> _firebaseIdToken() async {
    try {
      if (Firebase.apps.isEmpty) return null;
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      return await user.getIdToken();
    } catch (error) {
      debugPrint('[SupabaseConfig] gagal mengambil Firebase ID token: $error');
      return null;
    }
  }

  /// Dipanggil sekali di `main()` sebelum `runApp`.
  static Future<void> init() async {
    if (_ready) return;

    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // `.env` belum dibuat; lanjut ke pemeriksaan nilai kosong.
    }

    final url = dotenv.maybeGet('SUPABASE_URL') ?? '';
    final anonKey = dotenv.maybeGet('SUPABASE_ANON_KEY') ?? '';

    if (url.isEmpty || anonKey.isEmpty) return;

    await Supabase.initialize(url: url, anonKey: anonKey);
    _ready = true;
  }
}
