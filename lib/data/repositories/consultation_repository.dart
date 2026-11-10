import 'package:flutter/material.dart';

import '../models/consultation_session.dart';
import 'simulated_api.dart';

/// Repository sesi konsultasi dan rekam medis pasien (data simulasi).
///
/// Menyediakan data sesi aktif, riwayat medis pasien (vital signs),
/// riwayat obat, dan riwayat konsultasi dari dokter lain.
class ConsultationRepository {
  ConsultationRepository._() {
    _seed();
  }

  static final ConsultationRepository instance = ConsultationRepository._();

  final List<ConsultationSession> _sessions = [];
  final Map<String, List<PatientVitalRecord>> _vitalRecords = {};
  final Map<String, List<PatientMedicationRecord>> _medicationRecords = {};
  final Map<String, List<PastConsultationRecord>> _consultationHistory = {};
  final Map<String, List<ConsultationMessage>> _messages = {};
  int _messageCounter = 0;

  // ── Seed data simulasi ─────────────────────────────────────────────────────
  void _seed() {
    // Session aktif: Ny. Ratna Dewi
    final ratnaSesId = 'apt-d1';
    final ratnaPatientId = 'patient-ratna';
    _sessions.add(
      ConsultationSession(
        sessionId: ratnaSesId,
        patientId: ratnaPatientId,
        patientName: 'Ny. Ratna Dewi',
        patientAge: 42,
        patientGender: 'Perempuan',
        patientBloodType: 'A+',
        patientAllergies: ['Penisilin', 'Sulfonamide'],
        complaint:
            'Tekanan darah tinggi tidak terkontrol, pusing, dan mual. '
            'Sudah mengonsumsi Amlodipine selama 3 minggu.',
        scheduledTime: 'Hari ini, 09:30 WIB',
        consultationType: 'Chat Dokter',
        status: ConsultationStatus.ongoing,
        startedAt: DateTime.now().subtract(const Duration(minutes: 15)),
      ),
    );

    // Session terjadwal: Tn. Hendra
    _sessions.add(
      ConsultationSession(
        sessionId: 'apt-d2',
        patientId: 'patient-hendra',
        patientName: 'Tn. Hendra Wijaya',
        patientAge: 50,
        patientGender: 'Laki-laki',
        patientBloodType: 'O+',
        patientAllergies: ['Aspirin'],
        complaint: 'Kontrol rutin pasca operasi katup jantung 6 bulan lalu.',
        scheduledTime: 'Hari ini, 14:00 WIB',
        consultationType: 'Video Call',
        status: ConsultationStatus.scheduled,
        startedAt: DateTime.now().add(const Duration(hours: 4)),
      ),
    );

    // Session terjadwal: Sdr. Kevin
    _sessions.add(
      ConsultationSession(
        sessionId: 'apt-d3',
        patientId: 'patient-kevin',
        patientName: 'Sdr. Kevin Pratama',
        patientAge: 27,
        patientGender: 'Laki-laki',
        patientBloodType: 'B+',
        patientAllergies: [],
        complaint: 'Detak jantung berdebar tidak teratur saat berolahraga.',
        scheduledTime: 'Hari ini, 15:30 WIB',
        consultationType: 'Chat Dokter',
        status: ConsultationStatus.scheduled,
        startedAt: DateTime.now().add(const Duration(hours: 6)),
      ),
    );

    // ── Chat awal sesi ──────────────────────────────────────────────────────
    _addMessage(
      ratnaSesId,
      'Selamat pagi Dok, tekanan darah saya masih tinggi dan sering pusing.',
      fromDoctor: false,
      sentAt: DateTime.now().subtract(const Duration(minutes: 14)),
    );
    _addMessage(
      ratnaSesId,
      'Selamat pagi Bu Ratna. Sudah berapa lama keluhan ini, dan apakah ada mual?',
      fromDoctor: true,
      sentAt: DateTime.now().subtract(const Duration(minutes: 13)),
    );
    _addMessage(
      ratnaSesId,
      'Sekitar 3 minggu, Dok. Mual muncul terutama pagi hari.',
      fromDoctor: false,
      sentAt: DateTime.now().subtract(const Duration(minutes: 12)),
    );

    // ── Vital records untuk Ny. Ratna Dewi ──────────────────────────────────
    _vitalRecords[ratnaPatientId] = [
      // Tekanan darah (7 entri terakhir)
      PatientVitalRecord(
        id: 'vr1',
        metricName: 'Tekanan Darah',
        value: 158,
        unit: 'mmHg',
        date: DateTime.now().subtract(const Duration(days: 1)),
        status: 'Kritis',
        secondaryValue: 98,
        note: 'Malam hari, setelah aktivitas',
      ),
      PatientVitalRecord(
        id: 'vr2',
        metricName: 'Tekanan Darah',
        value: 150,
        unit: 'mmHg',
        date: DateTime.now().subtract(const Duration(days: 3)),
        status: 'Perhatian',
        secondaryValue: 95,
        note: 'Pagi hari',
      ),
      PatientVitalRecord(
        id: 'vr3',
        metricName: 'Tekanan Darah',
        value: 145,
        unit: 'mmHg',
        date: DateTime.now().subtract(const Duration(days: 5)),
        status: 'Perhatian',
        secondaryValue: 92,
        note: 'Setelah istirahat',
      ),
      PatientVitalRecord(
        id: 'vr4',
        metricName: 'Tekanan Darah',
        value: 142,
        unit: 'mmHg',
        date: DateTime.now().subtract(const Duration(days: 7)),
        status: 'Perhatian',
        secondaryValue: 90,
        note: 'Pagi hari',
      ),
      PatientVitalRecord(
        id: 'vr5',
        metricName: 'Tekanan Darah',
        value: 138,
        unit: 'mmHg',
        date: DateTime.now().subtract(const Duration(days: 10)),
        status: 'Perhatian',
        secondaryValue: 88,
        note: 'Sebelum minum obat',
      ),
      PatientVitalRecord(
        id: 'vr6',
        metricName: 'Tekanan Darah',
        value: 130,
        unit: 'mmHg',
        date: DateTime.now().subtract(const Duration(days: 14)),
        status: 'Normal',
        secondaryValue: 85,
        note: 'Setelah istirahat cukup',
      ),
      PatientVitalRecord(
        id: 'vr7',
        metricName: 'Tekanan Darah',
        value: 128,
        unit: 'mmHg',
        date: DateTime.now().subtract(const Duration(days: 21)),
        status: 'Normal',
        secondaryValue: 82,
        note: 'Sebelum mulai obat Amlodipine',
      ),
      // Berat badan
      PatientVitalRecord(
        id: 'vr8',
        metricName: 'Berat Badan',
        value: 68.5,
        unit: 'kg',
        date: DateTime.now().subtract(const Duration(days: 2)),
        status: 'Normal',
        note: 'Pagi hari',
      ),
      PatientVitalRecord(
        id: 'vr9',
        metricName: 'Berat Badan',
        value: 68.8,
        unit: 'kg',
        date: DateTime.now().subtract(const Duration(days: 9)),
        status: 'Normal',
        note: 'Pagi hari',
      ),
      PatientVitalRecord(
        id: 'vr10',
        metricName: 'Berat Badan',
        value: 69.2,
        unit: 'kg',
        date: DateTime.now().subtract(const Duration(days: 16)),
        status: 'Normal',
        note: 'Pagi hari',
      ),
      // Gula darah
      PatientVitalRecord(
        id: 'vr11',
        metricName: 'Gula Darah',
        value: 115,
        unit: 'mg/dL',
        date: DateTime.now().subtract(const Duration(days: 2)),
        status: 'Normal',
        note: 'Puasa pagi',
      ),
      PatientVitalRecord(
        id: 'vr12',
        metricName: 'Gula Darah',
        value: 142,
        unit: 'mg/dL',
        date: DateTime.now().subtract(const Duration(days: 5)),
        status: 'Perhatian',
        note: '2 jam setelah makan',
      ),
      PatientVitalRecord(
        id: 'vr13',
        metricName: 'Gula Darah',
        value: 108,
        unit: 'mg/dL',
        date: DateTime.now().subtract(const Duration(days: 9)),
        status: 'Normal',
        note: 'Puasa pagi',
      ),
      // Detak jantung
      PatientVitalRecord(
        id: 'vr14',
        metricName: 'Detak Jantung',
        value: 88,
        unit: 'BPM',
        date: DateTime.now().subtract(const Duration(days: 1)),
        status: 'Normal',
        note: 'Istirahat',
      ),
      PatientVitalRecord(
        id: 'vr15',
        metricName: 'Detak Jantung',
        value: 94,
        unit: 'BPM',
        date: DateTime.now().subtract(const Duration(days: 4)),
        status: 'Perhatian',
        note: 'Setelah aktivitas ringan',
      ),
      // Suhu tubuh
      PatientVitalRecord(
        id: 'vr16',
        metricName: 'Suhu Tubuh',
        value: 36.8,
        unit: '°C',
        date: DateTime.now().subtract(const Duration(days: 1)),
        status: 'Normal',
        note: 'Pagi hari',
      ),
    ];

    // ── Medication records untuk Ny. Ratna Dewi ──────────────────────────────
    _medicationRecords[ratnaPatientId] = [
      // Obat aktif
      const PatientMedicationRecord(
        id: 'pmr1',
        name: 'Amlodipine',
        dose: '10 mg',
        frequency: '1x sehari',
        startDate: '20 Okt 2026',
        endDate: '20 Nov 2026',
        prescribedBy: 'dr. Rifki Al Sauqy, Sp.JP',
        indication: 'Hipertensi (antihipertensi)',
        isActive: true,
        color: Color(0xFF43A047),
      ),
      const PatientMedicationRecord(
        id: 'pmr2',
        name: 'Candesartan',
        dose: '8 mg',
        frequency: '1x sehari',
        startDate: '01 Nov 2026',
        endDate: '01 Des 2026',
        prescribedBy: 'dr. Susi Kartini, Sp.PD',
        indication: 'Hipertensi dengan risiko gagal jantung',
        isActive: true,
        color: Color(0xFF1E88E5),
      ),
      // Riwayat obat (tidak aktif)
      const PatientMedicationRecord(
        id: 'pmr3',
        name: 'Nifedipine',
        dose: '30 mg',
        frequency: '1x sehari',
        startDate: '10 Jul 2026',
        endDate: '10 Okt 2026',
        prescribedBy: 'dr. Susi Kartini, Sp.PD',
        indication: 'Hipertensi (diganti Amlodipine karena efek samping)',
        isActive: false,
        color: Color(0xFFFF8F00),
      ),
      const PatientMedicationRecord(
        id: 'pmr4',
        name: 'Hydrochlorothiazide',
        dose: '12.5 mg',
        frequency: '1x sehari',
        startDate: '05 Jan 2026',
        endDate: '05 Apr 2026',
        prescribedBy: 'dr. Bambang Santoso, Sp.JP',
        indication: 'Hipertensi ringan (dihentikan karena kadar kalium rendah)',
        isActive: false,
        color: Color(0xFF8E24AA),
      ),
      const PatientMedicationRecord(
        id: 'pmr5',
        name: 'Metoprolol',
        dose: '50 mg',
        frequency: '2x sehari',
        startDate: '15 Mar 2025',
        endDate: '15 Jun 2025',
        prescribedBy: 'dr. Bambang Santoso, Sp.JP',
        indication: 'Hipertensi + takikardia (dihentikan karena bradikardia)',
        isActive: false,
        color: Color(0xFFE53935),
      ),
    ];

    // ── Riwayat konsultasi Ny. Ratna Dewi ───────────────────────────────────
    _consultationHistory[ratnaPatientId] = [
      PastConsultationRecord(
        id: 'pcr1',
        doctorName: 'dr. Susi Kartini, Sp.PD',
        specialization: 'Spesialis Penyakit Dalam',
        hospital: 'RSUD Fatmawati',
        date: DateTime.now().subtract(const Duration(days: 14)),
        complaint:
            'Tekanan darah tidak terkontrol meski sudah konsumsi Nifedipine',
        diagnosis: 'Hipertensi Stage II – ganti obat ke Amlodipine',
        notes:
            'Disarankan pola diet rendah garam, olahraga ringan 30 menit/hari. '
            'Pantau tekanan darah harian. Rujuk ke Sp.JP bila tekanan tidak membaik.',
        prescribedMedications: [
          'Amlodipine 10 mg 1x sehari',
          'Candesartan 8 mg 1x sehari',
        ],
        followUpDate: DateTime.now().add(const Duration(days: 14)),
      ),
      PastConsultationRecord(
        id: 'pcr2',
        doctorName: 'dr. Bambang Santoso, Sp.JP',
        specialization: 'Spesialis Jantung & Pembuluh Darah',
        hospital: 'RS Jantung Harapan Kita',
        date: DateTime.now().subtract(const Duration(days: 45)),
        complaint: 'Palpitasi dan sesak napas saat naik tangga',
        diagnosis: 'Hipertensi dengan takikardia sinus – observasi',
        notes:
            'EKG: ritme sinus, tidak ada tanda iskemia. '
            'Disarankan Holter monitor 24 jam. Pemberian Metoprolol dihentikan karena bradikardia.',
        prescribedMedications: ['Nifedipine 30 mg 1x sehari (dilanjutkan)'],
      ),
      PastConsultationRecord(
        id: 'pcr3',
        doctorName: 'dr. Rina Hastuti, Sp.PD',
        specialization: 'Spesialis Penyakit Dalam',
        hospital: 'Klinik Sejahtera',
        date: DateTime.now().subtract(const Duration(days: 90)),
        complaint: 'Rutin kontrol hipertensi, pusing dan kelelahan',
        diagnosis: 'Hipertensi Stage I terkontrol sebagian',
        notes:
            'Lab: kadar kalium rendah (3.3 mEq/L) akibat HCT. Hentikan HCT. '
            'Lanjutkan dengan suplemen kalium dan ganti ke golongan CCB.',
        prescribedMedications: [
          'Suplemen Kalium (KSR) 600 mg 2x sehari',
          'Nifedipine 30 mg 1x sehari',
        ],
      ),
      PastConsultationRecord(
        id: 'pcr4',
        doctorName: 'dr. Rina Hastuti, Sp.PD',
        specialization: 'Spesialis Penyakit Dalam',
        hospital: 'Klinik Sejahtera',
        date: DateTime.now().subtract(const Duration(days: 180)),
        complaint:
            'Sakit kepala berulang, tengkuk kaku, diagnosis awal hipertensi',
        diagnosis: 'Hipertensi primer – mulai terapi farmakologis',
        notes:
            'TD: 162/105 mmHg. Mulai terapi antihipertensi. '
            'Anjuran perubahan gaya hidup: hentikan merokok, kurangi alkohol, diet DASH.',
        prescribedMedications: ['Hydrochlorothiazide 12.5 mg 1x sehari'],
      ),
    ];
  }

  ConsultationMessage _addMessage(
    String sessionId,
    String text, {
    required bool fromDoctor,
    DateTime? sentAt,
  }) {
    _messageCounter++;
    final message = ConsultationMessage(
      id: 'cmsg_$_messageCounter',
      sessionId: sessionId,
      text: text,
      fromDoctor: fromDoctor,
      sentAt: sentAt ?? DateTime.now(),
    );
    _messages.putIfAbsent(sessionId, () => []).add(message);
    return message;
  }

  // ── API Publik ─────────────────────────────────────────────────────────────

  /// Mulai sesi terjadwal: status menjadi berlangsung dan waktu mulai dicatat.
  Future<ConsultationSession> startSession(String sessionId) {
    return SimulatedApi.run(() {
      final idx = _sessions.indexWhere((s) => s.sessionId == sessionId);
      if (idx == -1) throw StateError('Sesi tidak ditemukan: $sessionId');
      final current = _sessions[idx];
      if (current.status != ConsultationStatus.scheduled) {
        throw StateError('Hanya sesi terjadwal yang dapat dimulai.');
      }
      final updated = current.copyWith(
        status: ConsultationStatus.ongoing,
        startedAt: DateTime.now(),
      );
      _sessions[idx] = updated;
      return updated;
    });
  }

  /// Pesan chat sesi, urut dari yang terlama.
  Future<List<ConsultationMessage>> getMessages(String sessionId) {
    return SimulatedApi.run(
      () => List<ConsultationMessage>.of(_messages[sessionId] ?? const []),
    );
  }

  /// Kirim pesan dokter. Hanya diizinkan pada sesi yang sedang berlangsung.
  Future<ConsultationMessage> sendDoctorMessage(String sessionId, String text) {
    return SimulatedApi.run(() {
      final session = _sessions
          .where((s) => s.sessionId == sessionId)
          .firstOrNull;
      if (session == null) throw StateError('Sesi tidak ditemukan: $sessionId');
      if (session.status != ConsultationStatus.ongoing) {
        throw StateError('Chat hanya dapat dikirim saat sesi berlangsung.');
      }
      final trimmed = text.trim();
      if (trimmed.isEmpty) throw ArgumentError('Pesan tidak boleh kosong.');
      return _addMessage(sessionId, trimmed, fromDoctor: true);
    });
  }

  /// Balasan pasien otomatis (simulasi untuk demo).
  Future<ConsultationMessage?> simulatePatientReply(String sessionId) {
    return SimulatedApi.run(() {
      final session = _sessions
          .where((s) => s.sessionId == sessionId)
          .firstOrNull;
      if (session == null || session.status != ConsultationStatus.ongoing) {
        return null;
      }
      return _addMessage(
        sessionId,
        'Baik Dok, terima kasih. Saya akan ikuti arahannya.',
        fromDoctor: false,
      );
    });
  }

  /// Ambil sesi berdasarkan sessionId.
  Future<ConsultationSession?> getSession(String sessionId) {
    return SimulatedApi.run(
      () => _sessions.where((s) => s.sessionId == sessionId).firstOrNull,
    );
  }

  /// Ambil semua sesi untuk tampilan daftar dokter.
  Future<List<ConsultationSession>> getAllSessions() {
    return SimulatedApi.run(() => List.unmodifiable(_sessions));
  }

  /// Ambil vital records pasien, diurutkan terbaru dulu per metrik.
  Future<List<PatientVitalRecord>> getVitalRecords(String patientId) {
    return SimulatedApi.run(() {
      final records = _vitalRecords[patientId] ?? [];
      final sorted = List<PatientVitalRecord>.from(records)
        ..sort((a, b) => b.date.compareTo(a.date));
      return sorted;
    });
  }

  /// Ambil rekam obat pasien.
  Future<List<PatientMedicationRecord>> getMedicationRecords(String patientId) {
    return SimulatedApi.run(
      () => List.unmodifiable(_medicationRecords[patientId] ?? []),
    );
  }

  /// Ambil riwayat konsultasi pasien dengan dokter lain.
  Future<List<PastConsultationRecord>> getConsultationHistory(
    String patientId,
  ) {
    return SimulatedApi.run(() {
      final records = _consultationHistory[patientId] ?? [];
      final sorted = List<PastConsultationRecord>.from(records)
        ..sort((a, b) => b.date.compareTo(a.date));
      return sorted;
    });
  }

  /// Simpan catatan dokter dan perbarui status sesi.
  Future<ConsultationSession> saveSessionNotes({
    required String sessionId,
    required String diagnosisSummary,
    required String doctorNotes,
    required List<String> prescribedMedications,
    bool complete = false,
  }) {
    return SimulatedApi.run(() {
      final idx = _sessions.indexWhere((s) => s.sessionId == sessionId);
      if (idx == -1) throw StateError('Sesi tidak ditemukan: $sessionId');
      final updated = _sessions[idx].copyWith(
        diagnosisSummary: diagnosisSummary,
        doctorNotes: doctorNotes,
        prescribedMedications: prescribedMedications,
        status: complete ? ConsultationStatus.completed : _sessions[idx].status,
        completedAt: complete ? DateTime.now() : null,
      );
      _sessions[idx] = updated;
      return updated;
    });
  }

  /// Hitung ringkasan vital terkini per metrik (nilai terakhir per nama metrik).
  Future<Map<String, PatientVitalRecord>> getLatestVitals(String patientId) {
    return SimulatedApi.run(() {
      final records = _vitalRecords[patientId] ?? [];
      final Map<String, PatientVitalRecord> latest = {};
      for (final r in records) {
        if (!latest.containsKey(r.metricName) ||
            r.date.isAfter(latest[r.metricName]!.date)) {
          latest[r.metricName] = r;
        }
      }
      return Map.unmodifiable(latest);
    });
  }
}
