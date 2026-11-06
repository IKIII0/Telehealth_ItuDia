import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Telehealth/data/models/hospital_admin.dart';
import 'package:Telehealth/data/models/user.dart';
import 'package:Telehealth/data/repositories/auth_repository.dart';
import 'package:Telehealth/data/repositories/hospital_admin_repository.dart';
import 'package:Telehealth/features/hospital_admin/presentation/guards/hospital_admin_guard.dart';
import 'package:Telehealth/features/hospital_admin/presentation/pages/admin_dashboard_page.dart';
import 'package:Telehealth/features/hospital_admin/presentation/pages/admin_medication_verification_page.dart';
import 'package:Telehealth/features/hospital_admin/presentation/pages/admin_patient_monitoring_page.dart';

void main() {
  group('RBAC role hospital_admin', () {
    test('mengenali role hospital_admin dari Firebase', () {
      expect(
        AuthRepository.parseRole('hospital_admin'),
        UserRole.hospitalAdmin,
      );
      expect(
        AuthRepository.parseRole(' Hospital-Admin '),
        UserRole.hospitalAdmin,
      );
      expect(AuthRepository.parseRole('admin_rs'), UserRole.hospitalAdmin);
      expect(AuthRepository.parseRole('admin'), isNull);
    });

    test('role tersimpan dalam format snake_case Supabase', () {
      expect(UserRole.hospitalAdmin.storageValue, 'hospital_admin');
      expect(UserRole.hospitalAdmin.isHospitalAdmin, isTrue);
      expect(UserRole.patient.isHospitalAdmin, isFalse);
      expect(UserRole.doctor.isHospitalAdmin, isFalse);
    });
  });

  group('Model dashboard admin', () {
    test('PrescriptionStatus.fromDb memetakan status Supabase', () {
      expect(
        PrescriptionStatus.fromDb('pending_verification'),
        PrescriptionStatus.pendingVerification,
      );
      expect(
        PrescriptionStatus.fromDb('verified'),
        PrescriptionStatus.verified,
      );
      expect(
        PrescriptionStatus.fromDb('needs_clarification'),
        PrescriptionStatus.needsClarification,
      );
      expect(
        PrescriptionStatus.fromDb('tidak-dikenal'),
        PrescriptionStatus.pendingVerification,
      );
    });

    test('AdminPrescription.fromRow mengurutkan obat berdasarkan position', () {
      final prescription = AdminPrescription.fromRow({
        'id': 'rx-1',
        'status': 'needs_clarification',
        'doctor_name': 'dr. Rifki',
        'doctor_note': 'Pantau tensi',
        'admin_note': 'Mohon konfirmasi dosis',
        'created_at': '2025-01-02T03:04:05Z',
        'hospital_patients': {
          'id': 'patient-1',
          'full_name': 'Siti Aminah',
          'medical_record_no': 'RM-2024-0118',
        },
        'prescription_items': [
          {
            'position': 1,
            'medication_name': 'Obat B',
            'dose': '5 mg',
            'frequency_per_day': 2,
            'duration_days': 3,
          },
          {
            'position': 0,
            'medication_name': 'Obat A',
            'dose': '10 mg',
            'frequency_per_day': 1,
            'duration_days': 5,
          },
        ],
      });

      expect(prescription.patientName, 'Siti Aminah');
      expect(prescription.medicalRecordNo, 'RM-2024-0118');
      expect(prescription.status.isNeedsClarification, isTrue);
      expect(prescription.drugs.map((drug) => drug.name).toList(), [
        'Obat A',
        'Obat B',
      ]);
      expect(prescription.drugs.first.summary, contains('10 mg'));
    });

    test('MonitoredPatient.fromRow menghitung indikator tindak lanjut', () {
      final patient = MonitoredPatient.fromRow({
        'id': 'patient-1',
        'full_name': 'Budi Santoso',
        'medical_record_no': 'RM-2024-0117',
        'attending_doctor_name': 'dr. Rifki',
        'risk_level': 'high',
        'adherence_score': 42,
        'missed_doses_today': 2,
        'open_reports': 1,
        'pending_prescriptions': 0,
        'is_active': true,
      });

      expect(patient.riskLevel, RiskLevel.high);
      expect(patient.adherenceLabel, '42%');
      expect(patient.hasMissedDose, isTrue);
      expect(patient.hasOpenReport, isTrue);
      expect(patient.needsAttention, isTrue);
    });
  });

  group('HospitalAdminRepository (mode demo)', () {
    setUp(() {
      HospitalAdminRepository.forceDemoMode = true;
      HospitalAdminRepository.instance.resetDemoData();
    });

    tearDown(() {
      HospitalAdminRepository.forceDemoMode = false;
    });

    test('ringkasan konsisten dengan daftar pasien dan resep', () async {
      final repository = HospitalAdminRepository.instance;
      final summary = await repository.fetchSummary();
      final patients = await repository.fetchPatients();
      final pending = await repository.fetchPrescriptions(
        status: PrescriptionStatus.pendingVerification,
      );

      expect(summary.activePatients, patients.length);
      expect(summary.pendingPrescriptions, pending.length);
      expect(summary.adherenceScore, greaterThan(0));
      expect(summary.highRiskAlerts, greaterThan(0));
      expect(pending.every((item) => item.status.isPending), isTrue);
    });

    test('verifikasi resep menyimpan obat dan mengubah status', () async {
      final repository = HospitalAdminRepository.instance;
      final pending = await repository.fetchPrescriptions(
        status: PrescriptionStatus.pendingVerification,
      );
      final target = pending.first;

      await repository.verifyPrescription(
        prescription: target,
        drugs: const [
          PrescriptionDrug(
            name: 'Furosemide',
            dose: '20 mg',
            frequencyPerDay: 2,
            durationDays: 7,
            instructions: 'Sesudah makan',
          ),
        ],
        adminNote: 'Diverifikasi',
      );

      final updated = (await repository.fetchPrescriptions()).firstWhere(
        (item) => item.id == target.id,
      );

      expect(updated.status, PrescriptionStatus.verified);
      expect(updated.drugs.length, 1);
      expect(updated.drugs.single.name, 'Furosemide');
      expect(updated.drugs.single.frequencyPerDay, 2);
      expect(updated.adminNote, 'Diverifikasi');
    });

    test('minta klarifikasi mengubah status dan menyimpan pesan', () async {
      final repository = HospitalAdminRepository.instance;
      final pending = await repository.fetchPrescriptions(
        status: PrescriptionStatus.pendingVerification,
      );
      final target = pending.first;

      await repository.requestClarification(
        prescription: target,
        message: 'Mohon konfirmasi dosis untuk pasien lansia.',
      );

      final updated = (await repository.fetchPrescriptions()).firstWhere(
        (item) => item.id == target.id,
      );

      expect(updated.status, PrescriptionStatus.needsClarification);
      expect(updated.adminNote, contains('lansia'));
    });

    test('tindak lanjut menghapus peringatan pasien terkait', () async {
      final repository = HospitalAdminRepository.instance;
      final alerts = await repository.fetchAlerts();
      expect(alerts, isNotEmpty);

      final alert = alerts.first;
      await repository.recordFollowUp(
        patientId: alert.patientId,
        action: 'Telepon pasien',
        note: 'Pasien dihubungi dan diingatkan minum obat.',
        reportId: alert.type == AlertType.complaint ? alert.id : null,
      );

      final remaining = await repository.fetchAlerts();
      expect(remaining.length, lessThan(alerts.length));
    });

    test('watchAlerts mengirim snapshot awal', () async {
      final alerts = await HospitalAdminRepository.instance.watchAlerts().first;
      expect(alerts, isNotEmpty);
    });
  });

  group('Widget dashboard admin', () {
    setUp(() {
      HospitalAdminRepository.forceDemoMode = true;
      HospitalAdminRepository.instance.resetDemoData();
    });

    tearDown(() {
      HospitalAdminRepository.forceDemoMode = false;
    });

    testWidgets('menampilkan empat kartu ringkasan utama', (tester) async {
      tester.view.physicalSize = const Size(1440, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AdminDashboardPage())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ringkasan Dashboard'), findsOneWidget);
      expect(find.text('TOTAL PASIEN AKTIF'), findsOneWidget);
      expect(find.text('RESEP MENUNGGU VERIFIKASI'), findsOneWidget);
      expect(find.text('KEPATUHAN MINUM OBAT'), findsOneWidget);
      expect(find.text('PERINGATAN RISIKO TINGGI'), findsOneWidget);
    });

    testWidgets('guard menolak sesi tanpa role hospital_admin', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HospitalAdminGuard(child: Text('Konten rahasia')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Akses Ditolak'), findsOneWidget);
      expect(find.text('Konten rahasia'), findsNothing);
    });

    testWidgets('halaman verifikasi memuat resep menunggu verifikasi', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1600, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AdminMedicationVerificationPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Verifikasi Obat'), findsOneWidget);
      expect(find.text('Budi Santoso'), findsWidgets);
      expect(find.text('Verifikasi & Terbitkan Jadwal'), findsWidgets);
      expect(find.text('Minta Klarifikasi ke Dokter'), findsWidgets);
    });

    testWidgets('halaman pemantauan menampilkan tabel dan peringatan', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1600, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AdminPatientMonitoringPage())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pemantauan Pasien'), findsOneWidget);
      expect(find.text('Peringatan Real-time'), findsOneWidget);
      expect(find.text('Budi Santoso'), findsWidgets);
      expect(find.text('Tindak Lanjut'), findsWidgets);
    });
  });
}
