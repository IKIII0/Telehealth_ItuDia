/// Exception yang dilempar saat simulasi pemuatan data gagal.
class SimulatedFailure implements Exception {
  SimulatedFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Helper untuk mensimulasikan jeda jaringan pada repository data dummy.
///
/// Pola pemakaian:
/// ```dart
/// final data = await SimulatedApi.run(() => List.of(_items));
/// // lempar SimulatedFailure bila simulateError bernilai true
/// final data = await SimulatedApi.run(() => List.of(_items), simulateError: true);
/// ```
class SimulatedApi {
  SimulatedApi._();

  /// Jeda buatan supaya indikator loading sempat terlihat.
  static const Duration delay = Duration(milliseconds: 600);

  static Future<T> run<T>(
    T Function() action, {
    bool simulateError = false,
  }) async {
    await Future<void>.delayed(delay);
    if (simulateError) {
      throw SimulatedFailure('Simulasi gagal memuat data. Silakan coba lagi.');
    }
    return action();
  }
}
