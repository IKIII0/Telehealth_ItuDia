import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Telehealth/features/consultation/presentation/pages/patient_consultation_page.dart';

/// Regresi: pesan terlama harus tampil di atas, pesan terbaru di bawah.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ruang konsultasi mengurutkan pesan dari terlama ke terbaru', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(home: PatientConsultationRoomPage(sessionId: 'apt-d1')),
    );

    // Beri waktu dua panggilan SimulatedApi (sesi + pesan, masing-masing 600 ms).
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 100));

    const oldest =
        'Selamat pagi Dok, tekanan darah saya masih tinggi dan '
        'sering pusing.';
    const newest = 'Sekitar 3 minggu, Dok. Mual muncul terutama pagi hari.';

    final oldestY = tester.getTopLeft(find.text(oldest)).dy;
    final newestY = tester.getTopLeft(find.text(newest)).dy;

    expect(
      oldestY < newestY,
      isTrue,
      reason:
          'Pesan terlama harus berada di atas pesan terbaru '
          '(y lama=$oldestY, y baru=$newestY).',
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
