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

  /// `true` bila Supabase berhasil diinisialisasi dan siap dipakai.
  static bool get isReady => _ready;

  /// Client aktif, atau `null` bila Supabase tidak dikonfigurasi.
  static SupabaseClient? get client {
    if (!_ready) return null;
    return Supabase.instance.client;
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
