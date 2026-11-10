import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:Telehealth/core/routing/app_routes.dart';
import 'package:Telehealth/features/consultation/presentation/pages/consultation_list_page.dart';
import 'package:Telehealth/features/consultation/presentation/pages/consultation_session_page.dart';

/// Memajukan waktu bertahap (tanpa pumpAndSettle) karena timer durasi sesi
/// yang berlangsung terus berjalan.
Future<void> _advance(WidgetTester tester, {int ms = 1500}) async {
  for (var elapsed = 0; elapsed < ms; elapsed += 100) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Melepas halaman agar semua timer berhenti sebelum test berakhir.
Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await _advance(tester, ms: 2000);
}

void _useTallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 3200);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pumpApp(WidgetTester tester) async {
  _useTallView(tester);
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const ConsultationListPage()),
      GoRoute(
        name: AppRoutes.doctorConsultationName,
        path: AppRoutes.doctorConsultationPath,
        builder: (_, state) => ConsultationSessionPage(
          sessionId: state.pathParameters['sessionId']!,
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await _advance(tester, ms: 1000);
}

Future<void> _openCard(WidgetTester tester, String sessionId) async {
  final card = find.byKey(Key('consultation_card_$sessionId'));
  await tester.ensureVisible(card);
  await tester.tap(card);
  await _advance(tester, ms: 2500);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConsultationListPage', () {
    testWidgets('menampilkan semua konsultasi beserta detail pasien', (
      tester,
    ) async {
      await _pumpApp(tester);

      expect(find.text('Daftar Konsultasi'), findsOneWidget);
      expect(find.text('Ny. Ratna Dewi'), findsOneWidget);
      expect(find.text('Tn. Hendra Wijaya'), findsOneWidget);
      expect(find.text('Sdr. Kevin Pratama'), findsOneWidget);

      // Detail: usia/gender/gol. darah, keluhan, alergi, tipe konsultasi.
      expect(
        find.text('42 th \u2022 Perempuan \u2022 Gol. Darah A+'),
        findsOneWidget,
      );
      expect(find.textContaining('Tekanan darah tinggi'), findsOneWidget);
      expect(find.text('Alergi: Penisilin, Sulfonamide'), findsOneWidget);
      expect(find.text('Tidak ada alergi tercatat'), findsOneWidget);
      expect(find.text('Video Call'), findsOneWidget);

      // Tombol aksi sesuai status.
      expect(find.text('Lanjutkan Konsultasi'), findsOneWidget);
      expect(find.text('Buka & Mulai Konsultasi'), findsNWidgets(2));

      await _teardown(tester);
    });

    testWidgets('filter status menyaring daftar dan menampilkan jumlah', (
      tester,
    ) async {
      await _pumpApp(tester);

      expect(find.text('Semua (3)'), findsOneWidget);
      expect(find.text('Berlangsung (1)'), findsOneWidget);
      expect(find.text('Terjadwal (2)'), findsOneWidget);

      // Baris filter dapat di-scroll horizontal; geser agar chip terakhir terbangun.
      final completedChip = find.byKey(
        const Key('consultation_filter_completed'),
      );
      await tester.scrollUntilVisible(
        completedChip,
        100,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Selesai (0)'), findsOneWidget);

      await tester.tap(find.byKey(const Key('consultation_filter_scheduled')));
      await tester.pump();
      expect(find.text('Ny. Ratna Dewi'), findsNothing);
      expect(find.text('Tn. Hendra Wijaya'), findsOneWidget);
      expect(find.text('Sdr. Kevin Pratama'), findsOneWidget);

      await tester.tap(find.byKey(const Key('consultation_filter_completed')));
      await tester.pump();
      expect(
        find.text('Tidak ada konsultasi pada kategori ini.'),
        findsOneWidget,
      );

      await _teardown(tester);
    });

    testWidgets('mengetuk kartu membuka sesi konsultasi pasien tersebut', (
      tester,
    ) async {
      await _pumpApp(tester);
      await _openCard(tester, 'apt-d1');

      expect(find.text('Sesi Konsultasi'), findsOneWidget);
      expect(find.text('Percakapan'), findsOneWidget);
      expect(find.text('Ny. Ratna Dewi'), findsOneWidget);

      await _teardown(tester);
    });
  });

  group('Chat konsultasi', () {
    testWidgets('menampilkan riwayat chat dan dokter dapat mengirim pesan', (
      tester,
    ) async {
      await _pumpApp(tester);
      await _openCard(tester, 'apt-d1');

      // Pesan awal dari seed.
      expect(
        find.textContaining('tekanan darah saya masih tinggi'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Sudah berapa lama keluhan ini'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('consultation_chat_input')),
        'Mohon cek tekanan darah pagi ini',
      );
      await tester.tap(find.byKey(const Key('consultation_chat_send')));
      await _advance(tester, ms: 700);

      // Pesan dokter muncul, pasien sedang mengetik.
      expect(find.text('Mohon cek tekanan darah pagi ini'), findsOneWidget);
      expect(find.textContaining('sedang mengetik'), findsOneWidget);

      await _advance(tester, ms: 700);
      expect(find.textContaining('sedang mengetik'), findsNothing);
      expect(
        find.text('Baik Dok, terima kasih. Saya akan ikuti arahannya.'),
        findsOneWidget,
      );

      await _teardown(tester);
    });

    testWidgets('pesan kosong tidak terkirim', (tester) async {
      await _pumpApp(tester);
      await _openCard(tester, 'apt-d1');

      final before = find.byType(ListTile).evaluate().length;
      await tester.enterText(
        find.byKey(const Key('consultation_chat_input')),
        '   ',
      );
      await tester.tap(find.byKey(const Key('consultation_chat_send')));
      await _advance(tester, ms: 700);

      expect(find.textContaining('sedang mengetik'), findsNothing);
      expect(find.byType(ListTile).evaluate().length, before);

      await _teardown(tester);
    });
  });

  group('Mulai konsultasi', () {
    testWidgets('sesi terjadwal: input chat nonaktif sampai dimulai', (
      tester,
    ) async {
      await _pumpApp(tester);
      await _openCard(tester, 'apt-d2');

      expect(find.text('Terjadwal'), findsWidgets);
      expect(
        find.byKey(const Key('start_consultation_button')),
        findsOneWidget,
      );
      expect(find.text('Selesai Sesi'), findsNothing);

      final input = tester.widget<TextField>(
        find.byKey(const Key('consultation_chat_input')),
      );
      expect(input.enabled, isFalse);
      final send = tester.widget<IconButton>(
        find.byKey(const Key('consultation_chat_send')),
      );
      expect(send.onPressed, isNull);

      await tester.tap(find.byKey(const Key('start_consultation_button')));
      await _advance(tester, ms: 1000);

      expect(find.text('Konsultasi dimulai'), findsOneWidget);
      expect(find.text('Berlangsung'), findsOneWidget);
      expect(find.text('Selesai Sesi'), findsOneWidget);
      expect(find.byKey(const Key('start_consultation_button')), findsNothing);
      expect(find.byIcon(Icons.timer), findsOneWidget);

      final inputAfter = tester.widget<TextField>(
        find.byKey(const Key('consultation_chat_input')),
      );
      expect(inputAfter.enabled, isTrue);

      await _teardown(tester);
    });
  });
}
