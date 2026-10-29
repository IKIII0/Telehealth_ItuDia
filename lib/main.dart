import 'package:flutter/material.dart';

import 'app.dart';
import 'core/supabase/supabase_config.dart';
import 'data/repositories/auth_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Menyiapkan koneksi Supabase; bila kredensial kosong aplikasi tetap
  // berjalan dengan data simulasi lokal.
  await SupabaseConfig.init();
  await AuthRepository.instance.restoreSession();
  runApp(const TelehealthApp());
}
