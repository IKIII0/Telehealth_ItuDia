import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:Telehealth/core/routing/app_routes.dart';
import 'package:Telehealth/data/models/consultation_session.dart';
import 'package:Telehealth/data/models/doctor_profile.dart';
import 'package:Telehealth/data/models/user.dart';
import 'package:Telehealth/data/repositories/auth_repository.dart';
import 'package:Telehealth/data/repositories/consultation_repository.dart';
import 'package:Telehealth/features/consultation/presentation/pages/consultation_session_page.dart';
import 'package:Telehealth/features/doctor_dashboard/presentation/pages/doctor_dashboard_page.dart';

/// Memberi waktu bagi SimulatedApi (jeda 600 ms) tanpa pumpAndSettle,
/// karena timer durasi sesi berjalan terus selama sesi berlangsung.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(milliseconds: 100));
}

/// Melepas halaman agar timer dibatalkan sebelum test berakhir.
Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

void _useTallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConsultationStatus', () {
    test('memiliki label bahasa Indonesia', () {
      expect(ConsultationStatus.ongoing.label, 'Berlangsung');
      expect(ConsultationStatus.completed.label, 'Selesai');
      expect(ConsultationStatus.cancelled.label, 'Dibatalkan');
      expect(ConsultationStatus.scheduled.label, 'Terjadwal');
    });
  });

  group('ConsultationSession.copyWith', () {
    final base = ConsultationSession(
      sessionId: 's1',
      patientId: 'p1',
      patientName: 'Pasien Uji',
      patientAge: 30,
      patientGender: 'Laki-laki',
      patientBloodType: 'O+',
      patientAllergies: const ['Aspirin'],
      complaint: 'Pusing',
      scheduledTime: 'Hari ini',
      consultationType: 'Chat Dokter',
      status: ConsultationStatus.ongoing,
      startedAt: DateTime(2026, 11, 10, 9),
    );

    test('hanya mengubah field yang diberikan', () {
      final updated = base.copyWith(
        diagnosisSummary: 'Migrain',
        prescribedMedications: const ['Paracetamol'],
      );
      expect(updated.diagnosisSummary, 'Migrain');
      expect(updated.prescribedMedications, ['Paracetamol']);
      expect(updated.status, ConsultationStatus.ongoing);
      expect(updated.patientName, 'Pasien Uji');
      expect(updated.startedAt, base.startedAt);
    });
  });

  group('PatientVitalRecord', () {
    test('isAbnormal bernilai true bila status bukan Normal', () {
      PatientVitalRecord make(String status) => PatientVitalRecord(
        id: 'v',
        metricName: 'Tekanan Darah',
        value: 120,
        unit: 'mmHg',
        date: DateTime(2026),
        status: status,
      );
      expect(make('Normal').isAbnormal, isFalse);
      expect(make('Perhatian').isAbnormal, isTrue);
      expect(make('Kritis').isAbnormal, isTrue);
    });
  });

  group('ConsultationRepository', () {
    final repo = ConsultationRepository.instance;

    test('getAllSessions mengembalikan 3 sesi simulasi', () async {
      final sessions = await repo.getAllSessions();
      expect(sessions.map((s) => s.sessionId), ['apt-d1', 'apt-d2', 'apt-d3']);
    });

    test('getSession menemukan sesi dan null untuk ID tak dikenal', () async {
      final found = await repo.getSession('apt-d1');
      expect(found?.patientName, 'Ny. Ratna Dewi');
      expect(found?.status, ConsultationStatus.ongoing);
      expect(await repo.getSession('tidak-ada'), isNull);
    });

    test('getVitalRecords terurut dari yang terbaru', () async {
      final records = await repo.getVitalRecords('patient-ratna');
      expect(records, isNotEmpty);
      for (var i = 0; i < records.length - 1; i++) {
        expect(records[i].date.isBefore(records[i + 1].date), isFalse);
      }
    });

    test('getVitalRecords kosong untuk pasien tanpa data', () async {
      expect(await repo.getVitalRecords('patient-hendra'), isEmpty);
    });

    test('getLatestVitals memilih nilai terbaru per metrik', () async {
      final latest = await repo.getLatestVitals('patient-ratna');
      expect(latest['Tekanan Darah']?.value, 158);
      expect(latest['Tekanan Darah']?.secondaryValue, 98);
      expect(latest['Berat Badan']?.value, 68.5);
      expect(latest.keys, contains('Suhu Tubuh'));
    });

    test('getMedicationRecords memuat obat aktif dan nonaktif', () async {
      final meds = await repo.getMedicationRecords('patient-ratna');
      expect(meds.where((m) => m.isActive).map((m) => m.name), [
        'Amlodipine',
        'Candesartan',
      ]);
      expect(meds.where((m) => !m.isActive), isNotEmpty);
    });

    test('getConsultationHistory terurut dari yang terbaru', () async {
      final history = await repo.getConsultationHistory('patient-ratna');
      expect(history.length, 4);
      for (var i = 0; i < history.length - 1; i++) {
        expect(history[i].date.isAfter(history[i + 1].date), isTrue);
      }
      expect(await repo.getConsultationHistory('patient-kevin'), isEmpty);
    });

    test('saveSessionNotes menyimpan catatan tanpa mengubah status', () async {
      final updated = await repo.saveSessionNotes(
        sessionId: 'apt-d2',
        diagnosisSummary: 'Kontrol baik',
        doctorNotes: 'Lanjutkan obat',
        prescribedMedications: const ['Warfarin 2 mg'],
      );
      expect(updated.status, ConsultationStatus.scheduled);
      expect(updated.completedAt, isNull);

      final reloaded = await repo.getSession('apt-d2');
      expect(reloaded?.diagnosisSummary, 'Kontrol baik');
      expect(reloaded?.doctorNotes, 'Lanjutkan obat');
      expect(reloaded?.prescribedMedications, ['Warfarin 2 mg']);
    });

    test('startSession mengubah sesi terjadwal menjadi berlangsung', () async {
      final started = await repo.startSession('apt-d3');
      expect(started.status, ConsultationStatus.ongoing);
      expect(
        DateTime.now().difference(started.startedAt).inSeconds < 5,
        isTrue,
      );
    });

    test(
      'startSession menolak sesi yang bukan terjadwal / tak dikenal',
      () async {
        await expectLater(repo.startSession('apt-d3'), throwsStateError);
        await expectLater(repo.startSession('tidak-ada'), throwsStateError);
      },
    );

    test('saveSessionNotes(complete: true) menyelesaikan sesi', () async {
      final updated = await repo.saveSessionNotes(
        sessionId: 'apt-d3',
        diagnosisSummary: 'Palpitasi benigna',
        doctorNotes: 'Hindari kafein',
        prescribedMedications: const [],
        complete: true,
      );
      expect(updated.status, ConsultationStatus.completed);
      expect(updated.completedAt, isNotNull);
    });

    test(
      'getMessages memuat chat awal sesi aktif, kosong untuk lainnya',
      () async {
        final messages = await repo.getMessages('apt-d1');
        expect(messages.length, 3);
        expect(messages.first.fromDoctor, isFalse);
        expect(messages[1].fromDoctor, isTrue);
        expect(await repo.getMessages('apt-d2'), isEmpty);
      },
    );

    test('sendDoctorMessage menambah pesan dokter pada sesi aktif', () async {
      final sent = await repo.sendDoctorMessage(
        'apt-d1',
        '  Minum obat teratur ya  ',
      );
      expect(sent.text, 'Minum obat teratur ya');
      expect(sent.fromDoctor, isTrue);
      final messages = await repo.getMessages('apt-d1');
      expect(messages.last.id, sent.id);
    });

    test(
      'sendDoctorMessage menolak sesi tidak aktif dan pesan kosong',
      () async {
        await expectLater(
          repo.sendDoctorMessage('apt-d2', 'Halo'),
          throwsStateError,
        );
        await expectLater(
          repo.sendDoctorMessage('apt-d1', '   '),
          throwsArgumentError,
        );
      },
    );

    test('simulatePatientReply hanya membalas pada sesi aktif', () async {
      final reply = await repo.simulatePatientReply('apt-d1');
      expect(reply?.fromDoctor, isFalse);
      expect(await repo.simulatePatientReply('apt-d2'), isNull);
    });

    test('saveSessionNotes melempar StateError untuk sesi tak dikenal', () {
      expect(
        repo.saveSessionNotes(
          sessionId: 'tidak-ada',
          diagnosisSummary: '',
          doctorNotes: '',
          prescribedMedications: const [],
        ),
        throwsStateError,
      );
    });
  });

  group('ConsultationSessionPage', () {
    testWidgets('menampilkan info pasien, 4 tab, dan aksi untuk sesi aktif', (
      tester,
    ) async {
      _useTallView(tester);
      await tester.pumpWidget(
        const MaterialApp(home: ConsultationSessionPage(sessionId: 'apt-d1')),
      );
      expect(find.text('Memuat Sesi...'), findsOneWidget);
      await _settle(tester);

      expect(find.text('Sesi Konsultasi'), findsOneWidget);
      expect(find.text('Ny. Ratna Dewi'), findsOneWidget);
      expect(find.text('Berlangsung'), findsOneWidget);
      expect(find.text('Percakapan'), findsOneWidget);
      expect(find.text('Riwayat Medis'), findsOneWidget);
      expect(find.text('Riwayat Obat'), findsOneWidget);
      expect(find.text('Kunjungan'), findsOneWidget);
      expect(find.text('Catatan Dokter'), findsOneWidget);
      expect(find.text('Selesai Sesi'), findsOneWidget);
      expect(find.text('Tambah Catatan'), findsOneWidget);

      await _dispose(tester);
    });

    testWidgets('timer durasi berjalan dan berhenti saat halaman dilepas', (
      tester,
    ) async {
      _useTallView(tester);
      await tester.pumpWidget(
        const MaterialApp(home: ConsultationSessionPage(sessionId: 'apt-d1')),
      );
      await _settle(tester);
      expect(find.byIcon(Icons.timer), findsOneWidget);

      await _dispose(tester);
      // Tidak ada timer tertinggal: test selesai tanpa "Timer is still pending".
    });

    testWidgets('sesi terjadwal tidak menampilkan tombol Selesai Sesi', (
      tester,
    ) async {
      _useTallView(tester);
      await tester.pumpWidget(
        const MaterialApp(home: ConsultationSessionPage(sessionId: 'apt-d2')),
      );
      await _settle(tester);

      expect(find.text('Tn. Hendra Wijaya'), findsOneWidget);
      expect(find.text('Terjadwal'), findsOneWidget);
      expect(find.text('Selesai Sesi'), findsNothing);
      expect(find.byIcon(Icons.timer), findsNothing);

      await _dispose(tester);
    });

    testWidgets('menampilkan pesan error bila sesi tidak ditemukan', (
      tester,
    ) async {
      _useTallView(tester);
      await tester.pumpWidget(
        const MaterialApp(home: ConsultationSessionPage(sessionId: 'x')),
      );
      await _settle(tester);

      expect(find.text('Sesi konsultasi tidak ditemukan.'), findsOneWidget);
      expect(find.text('Kembali'), findsOneWidget);
    });

    testWidgets('Selesai Sesi meminta konfirmasi lalu menutup halaman', (
      tester,
    ) async {
      _useTallView(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          const ConsultationSessionPage(sessionId: 'apt-d1'),
                    ),
                  ),
                  child: const Text('Buka'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Buka'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await _settle(tester);

      await tester.tap(find.text('Selesai Sesi'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Akhiri Sesi Konsultasi'), findsOneWidget);

      await tester.tap(find.text('Akhiri Sesi'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Sesi Konsultasi'), findsNothing);
      expect(find.text('Buka'), findsOneWidget);

      final session = await tester.runAsync(
        () => ConsultationRepository.instance.getSession('apt-d1'),
      );
      expect(session?.status, ConsultationStatus.completed);

      await _dispose(tester);
    });
  });

  group('Dashboard dokter → sesi konsultasi', () {
    setUp(() {
      AuthRepository.instance.updateCurrentUser(
        AppUser(
          id: 'doc-test-1',
          name: 'dr. Rifki Al Sauqy, Sp.JP',
          email: 'dokter@gmail.com',
          role: UserRole.doctor,
          doctorProfile: DoctorProfile.simulatedDefault(),
        ),
      );
    });

    testWidgets('tombol pada jadwal sesi membuka halaman sesi yang sesuai', (
      tester,
    ) async {
      _useTallView(tester);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const DoctorDashboardPage(showNavBar: false),
          ),
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
      await tester.pumpAndSettle();

      // Sesi pertama (apt-d1) berstatus aktif sehingga tombolnya "Mulai Chat".
      final startButton = find.text('Mulai Chat');
      expect(startButton, findsOneWidget);
      await tester.ensureVisible(startButton);
      await tester.tap(startButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await _settle(tester);

      expect(find.text('Sesi Konsultasi'), findsOneWidget);
      expect(find.text('Tn. Hendra Wijaya'), findsNothing);
      expect(find.text('Ny. Ratna Dewi'), findsOneWidget);

      await _dispose(tester);
    });
  });
}
