import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/supabase/supabase_config.dart';
import 'data/repositories/auth_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Menyiapkan koneksi Supabase; bila kredensial kosong aplikasi tetap
  // berjalan dengan data simulasi lokal.
  await SupabaseConfig.init();

  // Firebase menangani autentikasi email & kata sandi. Inisialisasi harus
  // selesai sebelum sesi pengguna dipulihkan.
  await _initializeFirebase();

  await AuthRepository.instance.restoreSession();
  runApp(const TelehealthApp());
}

/// Firebase membaca konfigurasi native (`google-services.json` pada Android,
/// `GoogleService-Info.plist` pada iOS).
///
/// Kegagalan inisialisasi tidak boleh membuat aplikasi gagal dibuka; halaman
/// login akan menampilkan pesan error Firebase saat pengguna mencoba masuk.
Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp();
  } catch (error) {
    debugPrint(
      'Firebase gagal diinisialisasi: $error\n'
      'Pastikan aplikasi dijalankan di Android/iOS dan file konfigurasi '
      '(google-services.json / GoogleService-Info.plist) tersedia.',
    );
  }
}
