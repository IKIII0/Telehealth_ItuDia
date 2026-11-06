import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
/// Untuk **Flutter Web** (dipakai Web Dashboard Admin Rumah Sakit), Firebase
/// memerlukan opsi eksplisit. Opsi dibaca dari `.env` agar tidak perlu
/// menaruh kredensial di repository:
///
/// ```env
/// FIREBASE_WEB_API_KEY=...
/// FIREBASE_WEB_APP_ID=1:1234567890:web:abcdef
/// FIREBASE_WEB_MESSAGING_SENDER_ID=1234567890
/// FIREBASE_WEB_PROJECT_ID=nama-project
/// FIREBASE_WEB_AUTH_DOMAIN=nama-project.firebaseapp.com   # opsional
/// FIREBASE_WEB_STORAGE_BUCKET=nama-project.appspot.com    # opsional
/// ```
///
/// Bila variabel tersebut kosong (mis. di Android/iOS), inisialisasi tetap
/// memakai konfigurasi native seperti sebelumnya.
///
/// Kegagalan inisialisasi tidak boleh membuat aplikasi gagal dibuka; halaman
/// login akan menampilkan pesan error Firebase saat pengguna mencoba masuk.
Future<void> _initializeFirebase() async {
  try {
    final webOptions = kIsWeb ? _firebaseWebOptions() : null;
    if (webOptions != null) {
      await Firebase.initializeApp(options: webOptions);
      return;
    }

    await Firebase.initializeApp();
  } catch (error) {
    debugPrint(
      'Firebase gagal diinisialisasi: $error\n'
      'Pastikan aplikasi dijalankan di Android/iOS dan file konfigurasi '
      '(google-services.json / GoogleService-Info.plist) tersedia. Untuk web, '
      'isi variabel FIREBASE_WEB_* pada .env.',
    );
  }
}

/// Opsi Firebase untuk web, atau `null` bila `.env` belum lengkap.
FirebaseOptions? _firebaseWebOptions() {
  String read(String key) => (dotenv.maybeGet(key) ?? '').trim();

  final apiKey = read('FIREBASE_WEB_API_KEY');
  final appId = read('FIREBASE_WEB_APP_ID');
  final senderId = read('FIREBASE_WEB_MESSAGING_SENDER_ID');
  final projectId = read('FIREBASE_WEB_PROJECT_ID');

  if (apiKey.isEmpty ||
      appId.isEmpty ||
      senderId.isEmpty ||
      projectId.isEmpty) {
    return null;
  }

  final authDomain = read('FIREBASE_WEB_AUTH_DOMAIN');
  final storageBucket = read('FIREBASE_WEB_STORAGE_BUCKET');
  final measurementId = read('FIREBASE_WEB_MEASUREMENT_ID');

  return FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: senderId,
    projectId: projectId,
    authDomain: authDomain.isEmpty ? null : authDomain,
    storageBucket: storageBucket.isEmpty ? null : storageBucket,
    measurementId: measurementId.isEmpty ? null : measurementId,
  );
}
