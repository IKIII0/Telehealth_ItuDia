import 'package:flutter/foundation.dart';

/// Event lintas fitur yang ringan.
///
/// Dipakai agar daftar Chat memuat ulang ketika data konsultasi berubah
/// (mis. sesi baru dibuat setelah pembayaran), tanpa perlu me-restart tab.
class AppEvents extends ChangeNotifier {
  AppEvents._();

  static final AppEvents instance = AppEvents._();

  /// Dipanggil setelah permintaan konsultasi baru dibuat.
  void consultationsChanged() => notifyListeners();
}
