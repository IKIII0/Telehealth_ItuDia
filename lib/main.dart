import 'package:flutter/material.dart';

import 'app.dart';
import 'data/repositories/auth_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthRepository.instance.restoreSession();
  runApp(const TelehealthApp());
}
