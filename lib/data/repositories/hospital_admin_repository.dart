import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:firebase_core/firebase_core.dart' show Firebase;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:Telehealth/core/supabase/supabase_config.dart';
import 'package:Telehealth/data/models/hospital_admin.dart';
import 'package:Telehealth/data/repositories/auth_repository.dart';

/// Kesalahan yang pesannya aman ditampilkan di UI admin.
class HospitalAdminException implements Exception {
  const HospitalAdminException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Repository Web Dashboard Admin Rumah Sakit.
///
/// Semua query memakai [SupabaseConfig.firebaseAuthClient] sehingga RLS
/// Supabase dapat membaca Firebase UID dari `auth.jwt() ->> 'sub'` dan
/// membatasi data ke rumah sakit si admin.
///
/// Bila Supabase belum dikonfigurasi (atau `forceDemoMode` aktif untuk unit
/// test), repository memakai data demo lokal supaya dashboard tetap dapat
/// dijalankan tanpa kredensial — pola yang sama dengan repository lain di
/// proyek ini.
class HospitalAdminRepository {
  HospitalAdminRepository._();

  static final HospitalAdminRepository instance = HospitalAdminRepository._();

  /// Dipakai unit test agar tidak pernah menyentuh jaringan.
  @visibleForTesting
  static bool forceDemoMode = false;

  SupabaseClient? get _db =>
      forceDemoMode ? null : SupabaseConfig.firebaseAuthClient;

  /// `true` bila dashboard sedang menampilkan data demo lokal.
  bool get isDemoMode => _db == null;

  String? _hospitalId;
  Future<HospitalAdminProfile>? _profileFuture;

  // ─── Profil admin ───────────────────────────────────────────────────────────

  /// Profil admin + rumah sakit. Hasilnya di-cache selama sesi.
  Future<HospitalAdminProfile> profile({bool refresh = false}) async {
    final db = _db;
    if (db == null) return _demoProfile();

    if (_profileFuture == null || refresh) {
      _profileFuture = _loadProfile(db);
    }

    try {
      return await _profileFuture!;
    } catch (_) {
      // Izinkan percobaan ulang setelah error (mis. policy belum siap).
      _profileFuture = null;
      rethrow;
    }
  }

  Future<HospitalAdminProfile> _loadProfile(SupabaseClient db) async {
    final user = AuthRepository.instance.currentUser;
    final uid = user?.id ?? _firebaseUid();
    if (uid == null || uid.isEmpty) {
      throw const HospitalAdminException(
        'Sesi admin tidak ditemukan. Silakan masuk kembali.',
      );
    }

    final row = await db
        .from('user_roles')
        .select('user_id, role, hospital_id, hospitals(name, city)')
        .eq('user_id', uid)
        .eq('role', 'hospital_admin')
        .eq('is_active', true)
        .maybeSingle();

    if (row == null) {
      throw const HospitalAdminException(
        'Akun ini belum terdaftar sebagai admin rumah sakit. Hubungi '
        'super admin untuk menambahkan role hospital_admin.',
      );
    }

    final stored = HospitalAdminProfile.fromRow(row);
    _hospitalId = stored.hospitalId;
    return stored.copyWith(
      adminName: user?.name.isNotEmpty == true
          ? user!.name
          : 'Admin Rumah Sakit',
      email: user?.email ?? stored.email,
    );
  }

  String? _firebaseUid() {
    try {
      if (Firebase.apps.isEmpty) return null;
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  Future<String> _resolveHospitalId() async {
    final cached = _hospitalId;
    if (cached != null && cached.isNotEmpty) return cached;
    final loaded = await profile();
    if (loaded.hospitalId.isEmpty) {
      throw const HospitalAdminException(
        'Rumah sakit admin belum terhubung. Periksa tabel user_roles.',
      );
    }
    return loaded.hospitalId;
  }

  // ─── Ringkasan dashboard ────────────────────────────────────────────────────

  Future<HospitalAdminSummary> fetchSummary() async {
    final db = _db;
    if (db == null) return _demoSummary();

    try {
      final raw = await db.rpc<dynamic>('hospital_admin_summary');
      if (raw is Map<String, dynamic>) {
        return HospitalAdminSummary.fromJson(raw);
      }
      if (raw is Map) {
        return HospitalAdminSummary.fromJson(Map<String, dynamic>.from(raw));
      }
      return const HospitalAdminSummary();
    } catch (error) {
      throw HospitalAdminException(_readableError(error));
    }
  }

  // ─── Resep ──────────────────────────────────────────────────────────────────

  /// Resep rumah sakit, diurutkan terbaru. Filter status bersifat opsional.
  Future<List<AdminPrescription>> fetchPrescriptions({
    PrescriptionStatus? status,
  }) async {
    final db = _db;
    if (db == null) {
      return _demoPrescriptions
          .where((item) => status == null || item.status == status)
          .toList()
        ..sort((a, b) {
          final left = a.createdAt;
          final right = b.createdAt;
          if (left == null && right == null) return 0;
          if (left == null) return 1;
          if (right == null) return -1;
          return right.compareTo(left);
        });
    }

    try {
      final builder = db
          .from('prescriptions')
          .select(
            'id, status, doctor_name, doctor_note, admin_note, created_at, '
            'hospital_patients(id, full_name, medical_record_no), '
            'prescription_items(position, medication_name, dose, '
            'frequency_per_day, duration_days, special_instructions)',
          );

      final rows = status == null
          ? await builder.order('created_at', ascending: false)
          : await builder
                .eq('status', status.dbValue)
                .order('created_at', ascending: false);

      return rows.map(AdminPrescription.fromRow).toList(growable: false);
    } catch (error) {
      throw HospitalAdminException(_readableError(error));
    }
  }

  /// Verifikasi resep dan terbitkan jadwal minum obat.
  ///
  /// Server (RPC `hospital_verify_prescription`) mengganti seluruh item resep
  /// dan mengubah status menjadi `verified` dalam satu transaksi.
  Future<void> verifyPrescription({
    required AdminPrescription prescription,
    required List<PrescriptionDrug> drugs,
    String adminNote = '',
  }) async {
    if (drugs.isEmpty) {
      throw const HospitalAdminException('Minimal satu obat harus diisi.');
    }

    final db = _db;
    if (db == null) {
      _demoVerifyPrescription(prescription.id, drugs, adminNote);
      return;
    }

    try {
      await db.rpc<dynamic>(
        'hospital_verify_prescription',
        params: {
          'p_prescription_id': prescription.id,
          'p_items': drugs.map((drug) => drug.toRow()).toList(),
          'p_admin_note': adminNote,
        },
      );
    } catch (error) {
      throw HospitalAdminException(_readableError(error));
    }
  }

  /// Kirim permintaan klarifikasi ke dokter penulis resep.
  Future<void> requestClarification({
    required AdminPrescription prescription,
    required String message,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      throw const HospitalAdminException('Pesan klarifikasi wajib diisi.');
    }

    final db = _db;
    if (db == null) {
      _demoRequestClarification(prescription.id, trimmed);
      return;
    }

    try {
      await db.rpc<dynamic>(
        'hospital_request_clarification',
        params: {'p_prescription_id': prescription.id, 'p_message': trimmed},
      );
    } catch (error) {
      throw HospitalAdminException(_readableError(error));
    }
  }

  // ─── Pemantauan pasien ──────────────────────────────────────────────────────

  Future<List<MonitoredPatient>> fetchPatients() async {
    final db = _db;
    if (db == null) return _sortedPatients(_demoPatients);

    try {
      final rows = await db
          .from('hospital_patient_monitoring')
          .select()
          .eq('is_active', true);

      return _sortedPatients(rows.map(MonitoredPatient.fromRow).toList());
    } catch (error) {
      throw HospitalAdminException(_readableError(error));
    }
  }

  /// Peringatan aktif (dosis terlewat + keluhan pasien).
  Future<List<AdherenceAlert>> fetchAlerts() async {
    final db = _db;
    if (db == null) return _sortedAlerts(_demoAlerts);

    try {
      final rows = await db
          .from('hospital_alerts')
          .select()
          .order('created_at', ascending: false)
          .limit(50);

      return _sortedAlerts(rows.map(AdherenceAlert.fromRow).toList());
    } catch (error) {
      throw HospitalAdminException(_readableError(error));
    }
  }

  /// Stream peringatan realtime.
  ///
  /// Di mode Supabase, channel Realtime berlangganan perubahan
  /// `medication_adherence` dan `patient_reports` yang difilter per
  /// `hospital_id`. Ada polling 30 detik sebagai cadangan bila websocket
  /// diblokir jaringan rumah sakit.
  Stream<List<AdherenceAlert>> watchAlerts() {
    final db = _db;
    if (db == null) return _demoWatchAlerts();
    return _supabaseWatchAlerts(db);
  }

  Stream<List<AdherenceAlert>> _supabaseWatchAlerts(SupabaseClient db) {
    var cancelled = false;
    final channels = <RealtimeChannel>[];
    Timer? pollTimer;
    late final StreamController<List<AdherenceAlert>> controller;

    Future<void> refresh() async {
      if (cancelled) return;
      try {
        final alerts = await fetchAlerts();
        if (!cancelled && !controller.isClosed) controller.add(alerts);
      } catch (error) {
        debugPrint(
          '[HospitalAdminRepository] gagal memperbarui peringatan: $error',
        );
      }
    }

    Future<void> start() async {
      try {
        final hospitalId = await _resolveHospitalId();
        await _ensureRealtimeAuth(db);
        if (cancelled) return;

        for (final table in const ['medication_adherence', 'patient_reports']) {
          final channel =
              db.channel(
                'hospital-admin-$table-${DateTime.now().microsecondsSinceEpoch}',
              )..onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: table,
                filter: PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'hospital_id',
                  value: hospitalId,
                ),
                callback: (_) => refresh(),
              );
          channel.subscribe();
          channels.add(channel);
        }

        await refresh();
        pollTimer = Timer.periodic(
          const Duration(seconds: 30),
          (_) => refresh(),
        );
      } catch (error) {
        debugPrint(
          '[HospitalAdminRepository] realtime tidak tersedia, memakai polling: '
          '$error',
        );
        pollTimer ??= Timer.periodic(
          const Duration(seconds: 30),
          (_) => refresh(),
        );
        await refresh();
      }
    }

    controller = StreamController<List<AdherenceAlert>>(
      onListen: () {
        unawaited(start());
      },
      onCancel: () async {
        cancelled = true;
        pollTimer?.cancel();
        for (final channel in channels) {
          await db.removeChannel(channel);
        }
        channels.clear();
        if (!controller.isClosed) {
          await controller.close();
        }
      },
    );

    return controller.stream;
  }

  Future<void> _ensureRealtimeAuth(SupabaseClient db) async {
    try {
      if (Firebase.apps.isEmpty) return;
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token != null && token.isNotEmpty) {
        await db.realtime.setAuth(token);
      }
    } catch (error) {
      debugPrint('[HospitalAdminRepository] gagal set auth realtime: $error');
    }
  }

  /// Catat tindakan tindak lanjut admin. Bila [reportId] diisi, laporan pasien
  /// terkait ikut ditutup oleh RPC.
  Future<void> recordFollowUp({
    required String patientId,
    required String action,
    String note = '',
    String? reportId,
    String? prescriptionId,
  }) async {
    final db = _db;
    if (db == null) {
      _demoRecordFollowUp(patientId: patientId, reportId: reportId);
      return;
    }

    try {
      await db.rpc<dynamic>(
        'hospital_record_follow_up',
        params: {
          'p_patient_id': patientId,
          'p_action': action,
          'p_note': note,
          'p_report_id': reportId,
          'p_prescription_id': prescriptionId,
        },
      );
    } catch (error) {
      throw HospitalAdminException(_readableError(error));
    }
  }

  // ─── Helper ─────────────────────────────────────────────────────────────────

  List<MonitoredPatient> _sortedPatients(List<MonitoredPatient> source) {
    final copy = List<MonitoredPatient>.of(source);
    copy.sort((a, b) {
      final byRisk = b.riskLevel.weight.compareTo(a.riskLevel.weight);
      if (byRisk != 0) return byRisk;
      return a.adherenceScore.compareTo(b.adherenceScore);
    });
    return copy;
  }

  List<AdherenceAlert> _sortedAlerts(List<AdherenceAlert> source) {
    final copy = List<AdherenceAlert>.of(source);
    copy.sort((a, b) {
      final bySeverity = b.severity.weight.compareTo(a.severity.weight);
      if (bySeverity != 0) return bySeverity;
      final left = a.createdAt;
      final right = b.createdAt;
      if (left == null || right == null) return 0;
      return right.compareTo(left);
    });
    return copy;
  }

  String _readableError(Object error) {
    if (error is HospitalAdminException) return error.message;
    if (error is PostgrestException) {
      return switch (error.code) {
        '42501' =>
          'Akses ditolak. Akun ini tidak terhubung ke rumah sakit '
              'yang diminta.',
        'P0002' => 'Data tidak ditemukan.',
        '22023' => 'Data yang dikirim belum lengkap.',
        _ => error.message,
      };
    }
    return 'Tidak dapat menghubungi server. Periksa koneksi lalu coba lagi.';
  }

  // ─── Data demo ──────────────────────────────────────────────────────────────

  // Controller hidup selama aplikasi berjalan (singleton demo).
  // ignore: close_sinks
  final StreamController<List<AdherenceAlert>> _demoAlertController =
      StreamController<List<AdherenceAlert>>.broadcast();

  final List<MonitoredPatient> _demoPatients = [
    const MonitoredPatient(
      id: 'a2000000-0000-4000-8000-000000000001',
      name: 'Budi Santoso',
      medicalRecordNo: 'RM-2024-0117',
      doctorName: 'dr. Rifki Al Sauqy, Sp.JP',
      diagnosis: 'Gagal jantung kongestif (NYHA II)',
      riskLevel: RiskLevel.high,
      adherenceScore: 42,
      missedDosesToday: 2,
      openReports: 1,
      pendingPrescriptions: 1,
    ),
    const MonitoredPatient(
      id: 'a2000000-0000-4000-8000-000000000002',
      name: 'Siti Aminah',
      medicalRecordNo: 'RM-2024-0118',
      doctorName: 'dr. Daffa Afdhillah, Sp.PD',
      diagnosis: 'Diabetes melitus tipe 2',
      riskLevel: RiskLevel.medium,
      adherenceScore: 68,
      missedDosesToday: 1,
      pendingPrescriptions: 1,
    ),
    const MonitoredPatient(
      id: 'a2000000-0000-4000-8000-000000000005',
      name: 'Dewi Lestari',
      medicalRecordNo: 'RM-2024-0121',
      doctorName: 'dr. Daffa Afdhillah, Sp.PD',
      diagnosis: 'Hipertensi dengan komplikasi ginjal',
      riskLevel: RiskLevel.medium,
      adherenceScore: 78,
      missedDosesToday: 1,
      openReports: 1,
      pendingPrescriptions: 1,
    ),
    const MonitoredPatient(
      id: 'a2000000-0000-4000-8000-000000000004',
      name: 'Ahmad Hidayat',
      medicalRecordNo: 'RM-2024-0120',
      doctorName: 'dr. Cristian, Sp.KJ',
      diagnosis: 'Stroke iskemik ringan',
      riskLevel: RiskLevel.low,
      adherenceScore: 88,
    ),
    const MonitoredPatient(
      id: 'a2000000-0000-4000-8000-000000000003',
      name: 'Rina Wulandari',
      medicalRecordNo: 'RM-2024-0119',
      doctorName: 'dr. Farhan Prasetyo',
      diagnosis: 'Pneumonia komunitas (resolusi)',
      riskLevel: RiskLevel.low,
      adherenceScore: 96,
    ),
  ];

  late List<AdminPrescription> _demoPrescriptions = _seedDemoPrescriptions();

  List<AdminPrescription> _seedDemoPrescriptions() => [
    AdminPrescription(
      id: 'a3000000-0000-4000-8000-000000000001',
      patientId: 'a2000000-0000-4000-8000-000000000001',
      patientName: 'Budi Santoso',
      medicalRecordNo: 'RM-2024-0117',
      doctorName: 'dr. Rifki Al Sauqy, Sp.JP',
      doctorNote: 'Kontrol ulang 2 minggu, pantau tekanan darah harian.',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      drugs: const [
        PrescriptionDrug(
          name: 'Furosemide',
          dose: '40 mg',
          frequencyPerDay: 1,
          durationDays: 30,
          instructions: 'Pagi hari setelah makan',
        ),
        PrescriptionDrug(
          name: 'Spironolakton',
          dose: '25 mg',
          frequencyPerDay: 1,
          durationDays: 30,
          instructions: 'Setelah makan pagi',
        ),
        PrescriptionDrug(
          name: 'Bisoprolol',
          dose: '5 mg',
          frequencyPerDay: 1,
          durationDays: 30,
          instructions: 'Malam hari sebelum tidur',
        ),
      ],
    ),
    AdminPrescription(
      id: 'a3000000-0000-4000-8000-000000000002',
      patientId: 'a2000000-0000-4000-8000-000000000002',
      patientName: 'Siti Aminah',
      medicalRecordNo: 'RM-2024-0118',
      doctorName: 'dr. Daffa Afdhillah, Sp.PD',
      doctorNote: 'Periksa gula darah puasa setiap pagi.',
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      drugs: const [
        PrescriptionDrug(
          name: 'Metformin',
          dose: '500 mg',
          frequencyPerDay: 2,
          durationDays: 30,
          instructions: 'Sesudah makan pagi dan malam',
        ),
        PrescriptionDrug(
          name: 'Glibenklamid',
          dose: '5 mg',
          frequencyPerDay: 1,
          durationDays: 30,
          instructions: 'Pagi hari sebelum makan',
        ),
      ],
    ),
    AdminPrescription(
      id: 'a3000000-0000-4000-8000-000000000003',
      patientId: 'a2000000-0000-4000-8000-000000000005',
      patientName: 'Dewi Lestari',
      medicalRecordNo: 'RM-2024-0121',
      doctorName: 'dr. Daffa Afdhillah, Sp.PD',
      doctorNote: 'Batasi cairan 1.5 L per hari.',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      drugs: const [
        PrescriptionDrug(
          name: 'Amlodipine',
          dose: '10 mg',
          frequencyPerDay: 1,
          durationDays: 14,
          instructions: 'Malam hari',
        ),
        PrescriptionDrug(
          name: 'Ramipril',
          dose: '5 mg',
          frequencyPerDay: 1,
          durationDays: 14,
          instructions: 'Pagi hari',
        ),
      ],
    ),
    AdminPrescription(
      id: 'a3000000-0000-4000-8000-000000000004',
      patientId: 'a2000000-0000-4000-8000-000000000003',
      patientName: 'Rina Wulandari',
      medicalRecordNo: 'RM-2024-0119',
      doctorName: 'dr. Farhan Prasetyo',
      status: PrescriptionStatus.verified,
      doctorNote: 'Lanjutkan antibiotik sampai habis.',
      adminNote: 'Jadwal diverifikasi oleh admin.',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      drugs: const [
        PrescriptionDrug(
          name: 'Amoxicillin',
          dose: '500 mg',
          frequencyPerDay: 3,
          durationDays: 5,
          instructions: 'Sebelum makan',
        ),
        PrescriptionDrug(
          name: 'Paracetamol',
          dose: '500 mg',
          frequencyPerDay: 3,
          durationDays: 5,
          instructions: 'Hanya bila demam',
        ),
      ],
    ),
    AdminPrescription(
      id: 'a3000000-0000-4000-8000-000000000005',
      patientId: 'a2000000-0000-4000-8000-000000000004',
      patientName: 'Ahmad Hidayat',
      medicalRecordNo: 'RM-2024-0120',
      doctorName: 'dr. Cristian, Sp.KJ',
      status: PrescriptionStatus.needsClarification,
      doctorNote: 'Antiplatelet dosis rendah.',
      adminNote: 'Mohon konfirmasi apakah perlu tambahan gastroprotektor.',
      createdAt: DateTime.now().subtract(const Duration(days: 4)),
      drugs: const [
        PrescriptionDrug(
          name: 'Clopidogrel',
          dose: '75 mg',
          frequencyPerDay: 1,
          durationDays: 30,
          instructions: 'Setelah makan pagi',
        ),
      ],
    ),
  ];

  late List<AdherenceAlert> _demoAlerts = _seedDemoAlerts();

  List<AdherenceAlert> _seedDemoAlerts() => [
    AdherenceAlert(
      id: 'alert-1',
      patientId: 'a2000000-0000-4000-8000-000000000001',
      patientName: 'Budi Santoso',
      type: AlertType.complaint,
      severity: RiskLevel.high,
      message: 'Sesak napas memberat saat berbaring, kaki bengkak.',
      createdAt: DateTime.now().subtract(const Duration(minutes: 40)),
    ),
    AdherenceAlert(
      id: 'alert-2',
      patientId: 'a2000000-0000-4000-8000-000000000001',
      patientName: 'Budi Santoso',
      type: AlertType.missedDose,
      severity: RiskLevel.high,
      message: 'Melewatkan 2 dari 3 dosis pada hari ini.',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    AdherenceAlert(
      id: 'alert-3',
      patientId: 'a2000000-0000-4000-8000-000000000005',
      patientName: 'Dewi Lestari',
      type: AlertType.complaint,
      severity: RiskLevel.medium,
      message: 'Lupa meminum obat malam, apakah boleh diminum sekarang?',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    AdherenceAlert(
      id: 'alert-4',
      patientId: 'a2000000-0000-4000-8000-000000000002',
      patientName: 'Siti Aminah',
      type: AlertType.missedDose,
      severity: RiskLevel.medium,
      message: 'Melewatkan 1 dari 2 dosis pada hari ini.',
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
  ];

  /// Mengembalikan data demo ke kondisi awal (dipakai unit test).
  @visibleForTesting
  void resetDemoData() {
    _demoPrescriptions = _seedDemoPrescriptions();
    _demoAlerts = _seedDemoAlerts();
    _profileFuture = null;
    _hospitalId = null;
  }

  HospitalAdminProfile _demoProfile() {
    final user = AuthRepository.instance.currentUser;
    return HospitalAdminProfile(
      adminName: user?.name ?? 'Admin RS Sehat Sentosa',
      email: user?.email ?? 'admin@rssehatsentosa.id',
      hospitalId: 'a1000000-0000-4000-8000-000000000001',
      hospitalName: 'RS Sehat Sentosa',
      hospitalCity: 'Jakarta Selatan',
    );
  }

  HospitalAdminSummary _demoSummary() {
    final pending = _demoPrescriptions
        .where((item) => item.status.isPending)
        .length;
    final verified = _demoPrescriptions
        .where((item) => item.status.isVerified)
        .length;
    final adherence = _demoPatients.isEmpty
        ? 0.0
        : _demoPatients
                  .map((patient) => patient.adherenceScore)
                  .reduce((a, b) => a + b) /
              _demoPatients.length;

    return HospitalAdminSummary(
      hospitalName: _demoProfile().hospitalName,
      activePatients: _demoPatients.length,
      pendingPrescriptions: pending,
      verifiedPrescriptions: verified,
      adherenceScore: double.parse(adherence.toStringAsFixed(1)),
      highRiskAlerts: _demoAlerts
          .where((alert) => alert.severity.isHigh)
          .length,
      openAlerts: _demoAlerts.length,
    );
  }

  Stream<List<AdherenceAlert>> _demoWatchAlerts() async* {
    yield _sortedAlerts(_demoAlerts);
    yield* _demoAlertController.stream;
  }

  void _demoVerifyPrescription(
    String prescriptionId,
    List<PrescriptionDrug> drugs,
    String adminNote,
  ) {
    final index = _demoPrescriptions.indexWhere(
      (item) => item.id == prescriptionId,
    );
    if (index == -1) {
      throw const HospitalAdminException('Resep tidak ditemukan.');
    }

    _demoPrescriptions[index] = _demoPrescriptions[index].copyWith(
      status: PrescriptionStatus.verified,
      drugs: List<PrescriptionDrug>.of(drugs),
      adminNote: adminNote.trim().isEmpty
          ? _demoPrescriptions[index].adminNote
          : adminNote.trim(),
    );
  }

  void _demoRequestClarification(String prescriptionId, String message) {
    final index = _demoPrescriptions.indexWhere(
      (item) => item.id == prescriptionId,
    );
    if (index == -1) {
      throw const HospitalAdminException('Resep tidak ditemukan.');
    }

    _demoPrescriptions[index] = _demoPrescriptions[index].copyWith(
      status: PrescriptionStatus.needsClarification,
      adminNote: message,
    );
  }

  void _demoRecordFollowUp({required String patientId, String? reportId}) {
    final before = _demoAlerts.length;
    if (reportId != null) {
      _demoAlerts.removeWhere((alert) => alert.id == reportId);
    } else {
      final index = _demoAlerts.indexWhere(
        (alert) => alert.patientId == patientId,
      );
      if (index != -1) _demoAlerts.removeAt(index);
    }

    if (_demoAlerts.length != before && !_demoAlertController.isClosed) {
      _demoAlertController.add(_sortedAlerts(_demoAlerts));
    }
  }
}
