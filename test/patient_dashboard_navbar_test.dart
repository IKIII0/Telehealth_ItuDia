import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Telehealth/core/widgets/patient_nav_bar.dart';
import 'package:Telehealth/features/dashboard/presentation/pages/dashboard_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PatientNavBar Widget Tests', () {
    testWidgets(
      'menampilkan 4 navigasi: Home, Cek Gejala, Chat Dokter, Profil',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(bottomNavigationBar: PatientNavBar(currentIndex: 0)),
          ),
        );
        await tester.pump();

        expect(find.byType(PatientNavBar), findsOneWidget);
        expect(find.text('Home'), findsOneWidget);
        expect(find.text('Cek Gejala'), findsOneWidget);
        expect(find.text('Chat Dokter'), findsOneWidget);
        expect(find.text('Profil'), findsOneWidget);
      },
    );

    testWidgets('menandai indeks aktif sesuai currentIndex', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(bottomNavigationBar: PatientNavBar(currentIndex: 1)),
        ),
      );
      await tester.pump();

      final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 1);
    });
  });

  group('DashboardPage Layout & Summary Tests', () {
    testWidgets('menampilkan navbar pasien di bagian bawah dashboard', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const MaterialApp(home: DashboardPage()));
      // Tunggu load async dari repository selesai
      await tester.pumpAndSettle();

      expect(find.byType(PatientNavBar), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Cek Gejala'), findsOneWidget);
      expect(find.text('Chat Dokter'), findsOneWidget);
      expect(find.text('Profil'), findsOneWidget);
    });

    testWidgets(
      'tidak ada lagi tombol Aksi Cepat lama (Cek Gejala & Chat dokter telah dipindah ke navbar)',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(const MaterialApp(home: DashboardPage()));
        await tester.pumpAndSettle();

        // Judul section lama 'Aksi Cepat' tidak lagi ada
        expect(find.text('Aksi Cepat'), findsNothing);
        expect(find.text('Cek\nGejala'), findsNothing);
        expect(find.text('Chat\nDokter'), findsNothing);
      },
    );

    testWidgets(
      'menampilkan ringkasan Jurnal Kesehatan berupa grafik rekam medis dan tombol panah detail',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(const MaterialApp(home: DashboardPage()));
        await tester.pumpAndSettle();

        expect(find.text('Jurnal Kesehatan'), findsOneWidget);
        expect(find.text('Grafik rekam medis & kondisi fisik'), findsOneWidget);

        // Menampilkan tombol panah ke halaman jurnal kesehatan
        expect(
          find.byKey(const Key('journal_detail_arrow_button')),
          findsOneWidget,
        );

        // Menampilkan chip kategori grafik rekam medis
        expect(find.text('Tekanan Darah'), findsWidgets);
        expect(find.text('Gula Darah'), findsWidgets);
        expect(find.text('Berat Badan'), findsWidgets);

        // Menampilkan legenda grafik sistolik & diastolik
        expect(find.text('Sistolik'), findsOneWidget);
        expect(find.text('Diastolik'), findsOneWidget);
      },
    );

    testWidgets(
      'menampilkan ringkasan Pengingat Obat dengan jadwal konsumsi terdekat dan tombol panah detail',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(const MaterialApp(home: DashboardPage()));
        await tester.pumpAndSettle();

        expect(find.text('Pengingat Obat'), findsOneWidget);
        expect(
          find.text('Jadwal konsumsi terdekat & kepatuhan'),
          findsOneWidget,
        );

        // Menampilkan tombol panah ke halaman pengingat obat
        expect(
          find.byKey(const Key('medication_detail_arrow_button')),
          findsOneWidget,
        );

        // Menampilkan progress kepatuhan dan jadwal konsumsi terdekat
        expect(find.text('Kepatuhan Hari Ini'), findsOneWidget);
        expect(find.text('Jadwal Konsumsi Terdekat'), findsOneWidget);
      },
    );
  });
}
