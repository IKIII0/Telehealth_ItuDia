import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Telehealth/core/widgets/doctor_nav_bar.dart';
import 'package:Telehealth/data/models/doctor_profile.dart';
import 'package:Telehealth/data/models/user.dart';
import 'package:Telehealth/data/repositories/auth_repository.dart';
import 'package:Telehealth/features/doctor_dashboard/presentation/pages/doctor_dashboard_page.dart';
import 'package:Telehealth/features/doctor_dashboard/presentation/pages/doctor_profile_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Siapkan dokter template akun untuk tes
    final testDoctor = AppUser(
      id: 'doc-test-1',
      name: 'dr. Rifki Al Sauqy, Sp.JP',
      email: 'dokter@gmail.com',
      role: UserRole.doctor,
      doctorProfile: DoctorProfile.simulatedDefault(),
    );
    AuthRepository.instance.updateCurrentUser(testDoctor);
  });

  group('DoctorNavBar Widget Tests', () {
    testWidgets('menampilkan 2 navigasi: Dashboard dan Profil Dokter', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(bottomNavigationBar: DoctorNavBar(currentIndex: 0)),
        ),
      );
      await tester.pump();

      expect(find.byType(DoctorNavBar), findsOneWidget);
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Profil Dokter'), findsOneWidget);
    });

    testWidgets('menandai indeks aktif sesuai currentIndex', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(bottomNavigationBar: DoctorNavBar(currentIndex: 1)),
        ),
      );
      await tester.pump();

      final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 1);
    });
  });

  group('DoctorDashboardPage Tests', () {
    testWidgets(
      'menampilkan header dokter, jadwal kerja, dan daftar permintaan konsultasi pasien',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          const MaterialApp(home: DoctorDashboardPage(showNavBar: true)),
        );
        await tester.pumpAndSettle();

        // 1. Header dokter
        expect(find.text('Portal Dokter'), findsOneWidget);
        expect(find.text('dr. Rifki Al Sauqy, Sp.JP'), findsWidgets);
        expect(find.text('Selamat Bertugas,'), findsOneWidget);

        // 2. Jadwal kerja dokter
        expect(find.text('Jadwal Kerja & Praktik Dokter'), findsOneWidget);
        expect(find.text('Shift Praktik Hari Ini'), findsOneWidget);
        expect(find.text('Sedang Bertugas'), findsOneWidget);
        expect(find.text('Kapasitas Antrean Konsultasi'), findsOneWidget);

        // 3. Daftar permintaan konsultasi pasien
        expect(find.text('Permintaan Konsultasi Pasien'), findsOneWidget);
        expect(find.textContaining('Budi Santoso'), findsOneWidget);
        expect(find.textContaining('Siti Aminah'), findsOneWidget);
        expect(find.textContaining('Rudi Hermawan'), findsOneWidget);

        // 4. Jadwal sesi hari ini
        expect(find.text('Jadwal Sesi Pasien Hari Ini'), findsOneWidget);

        // 5. Aksi cepat dokter
        expect(find.text('Aksi Cepat Dokter'), findsOneWidget);
        expect(find.textContaining('Resep Obat'), findsOneWidget);
      },
    );

    testWidgets(
      'dapat menerima permintaan konsultasi pasien dengan tombol Terima Sesi',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          const MaterialApp(home: DoctorDashboardPage(showNavBar: true)),
        );
        await tester.pumpAndSettle();

        // Cari tombol 'Terima Sesi' pertama (untuk Budi Santoso)
        final terimaButtons = find.text('Terima Sesi');
        expect(terimaButtons, findsWidgets);

        await tester.tap(terimaButtons.first);
        await tester.pumpAndSettle();

        // SnackBar konfirmasi muncul
        expect(
          find.textContaining('diterima. Sesi telah dijadwalkan.'),
          findsOneWidget,
        );
      },
    );
  });

  group('DoctorProfilePage Tests', () {
    testWidgets(
      'menampilkan data simulasi kredensial dokter dan tombol ubah data',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          const MaterialApp(home: DoctorProfilePage(showNavBar: true)),
        );
        await tester.pumpAndSettle();

        // Header profil
        expect(find.text('Profil Dokter'), findsWidgets);
        expect(find.text('Dokter Spesialis'), findsOneWidget);
        expect(find.text('Kredensial Terverifikasi'), findsOneWidget);

        // Banner data simulasi
        expect(find.text('Data Simulasi Dokter & Kredensial'), findsOneWidget);

        // Kartu kredensial dokter
        expect(find.text('Informasi Kredensial Dokter'), findsOneWidget);
        expect(find.text('Rumah Sakit Praktik'), findsOneWidget);
        expect(find.text('RS Jantung Harapan Kita'), findsWidgets);
        expect(find.text('Nomor STR (Surat Tanda Registrasi)'), findsOneWidget);
        expect(find.text('STR-2024-16284'), findsOneWidget);

        // Jadwal praktik
        expect(find.text('Jadwal Praktik & Konsultasi'), findsOneWidget);
        expect(find.text('Senin - Jumat'), findsOneWidget);

        // Preferensi dokter
        expect(find.text('Preferensi Praktik & Pasien'), findsOneWidget);
        expect(find.text('Notifikasi Permintaan Baru'), findsOneWidget);
        expect(find.text('Status Menerima Pasien'), findsOneWidget);

        // Tombol Ubah Data di appbar
        expect(find.byKey(const Key('appbar_edit_doctor_button')), findsOneWidget);
      },
    );

    testWidgets('dapat membuka dialog ubah data dokter dan menyimpannya', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(home: DoctorProfilePage(showNavBar: true)),
      );
      await tester.pumpAndSettle();

      // Tap tombol 'Ubah Data' di AppBar
      final ubahDataBtn = find.byKey(const Key('appbar_edit_doctor_button'));
      await tester.tap(ubahDataBtn);
      await tester.pumpAndSettle();

      // Dialog ubah data muncul
      expect(find.text('Ubah Data Profil Dokter'), findsWidgets);
      expect(find.byKey(const Key('save_doctor_profile_button')), findsOneWidget);

      // Ubah nama dokter di dialog
      final nameField = find.byKey(const Key('edit_doctor_name_field'));
      await tester.enterText(nameField, 'dr. Rifki Al Sauqy, Sp.JP (K)');

      // Tap Simpan
      await tester.tap(find.byKey(const Key('save_doctor_profile_button')));
      await tester.pumpAndSettle();

      // Pastikan nama baru tampil di profil dokter
      expect(find.text('dr. Rifki Al Sauqy, Sp.JP (K)'), findsWidgets);
      expect(
        find.text('Data profil dokter berhasil diperbarui'),
        findsOneWidget,
      );
    });
  });

  group('DoctorProfile Model Tests', () {
    test('copyWith memperbarui nilai spesifik dan mempertahankan nilai lain', () {
      final original = DoctorProfile.simulatedDefault();
      final updated = original.copyWith(
        specialization: 'Spesialis Bedah Toraks',
        experienceYears: 15,
      );

      expect(updated.specialization, 'Spesialis Bedah Toraks');
      expect(updated.experienceYears, 15);
      expect(updated.strNumber, original.strNumber);
      expect(updated.hospital, original.hospital);
      expect(updated.phone, original.phone);
    });
  });
}
