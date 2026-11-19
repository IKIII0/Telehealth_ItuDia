import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_config.dart';
import '../models/consultation_summary.dart';
import 'simulated_api.dart';
import 'supabase_mappers.dart';

/// Repository catatan medis / resume konsultasi.
///
/// Dokter menyimpan resume setelah sesi; dokter berikutnya dapat membacanya
/// agar riwayat penanganan pasien tetap terbawa.
class ConsultationSummaryRepository {
  ConsultationSummaryRepository._();
  static final ConsultationSummaryRepository instance =
      ConsultationSummaryRepository._();

  SupabaseClient? get _db => SupabaseConfig.client;

  final List<ConsultationSummary> _local = [
    ConsultationSummary(
      id: 'sum1',
      conversationId: 'conv1',
      patientName: 'ItuDia',
      doctorId: 'doc1',
      doctorName: 'dr. Rifki Al Sauqy, Sp.JP',
      specialization: 'Spesialis Jantung',
      diagnosis: 'Hipertensi stadium 1',
      notes:
          'Tensi 140/90. Keluhan pusing ringan saat aktivitas berat. '
          'Tidak ada riwayat serangan jantung.',
      prescriptions: const [
        'Amlodipine 10 mg — 1x sehari malam',
        'Paracetamol 500 mg — bila pusing',
      ],
      advice: 'Kurangi garam, kontrol tensi tiap pagi, kontrol ulang 1 minggu.',
      createdAt: DateTime(2026, 11, 17, 10, 30),
    ),
    ConsultationSummary(
      id: 'sum2',
      conversationId: 'conv2',
      patientName: 'ItuDia',
      doctorId: 'doc2',
      doctorName: 'dr. Yehezkiel Sitanggang, Sp.A',
      specialization: 'Spesialis Anak',
      diagnosis: 'Demam viral, hasil laboratorium normal',
      notes:
          'Suhu 38,2°C selama 2 hari, hasil darah lengkap dalam batas normal.',
      prescriptions: const ['Paracetamol sirup — 3x sehari'],
      advice:
          'Cukup cairan dan istirahat, kembali bila demam lebih dari 3 hari.',
      createdAt: DateTime(2026, 11, 14, 9, 15),
    ),
  ];

  Future<List<ConsultationSummary>> fetchAll({
    bool simulateError = false,
  }) async {
    final db = _db;
    if (db == null) {
      return SimulatedApi.run(
        () =>
            List<ConsultationSummary>.of(_local)
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        simulateError: simulateError,
      );
    }

    final rows = await db
        .from('consultation_summaries')
        .select()
        .order('created_at', ascending: false);
    return rows.map(consultationSummaryFromRow).toList();
  }

  Future<List<ConsultationSummary>> fetchByPatient(
    String patientName, {
    bool simulateError = false,
  }) async {
    final db = _db;
    if (db == null) {
      return SimulatedApi.run(
        () =>
            _local.where((s) => s.patientName == patientName).toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        simulateError: simulateError,
      );
    }

    final rows = await db
        .from('consultation_summaries')
        .select()
        .eq('patient_name', patientName)
        .order('created_at', ascending: false);
    return rows.map(consultationSummaryFromRow).toList();
  }

  Future<List<ConsultationSummary>> fetchByConversation(
    String conversationId,
  ) async {
    final db = _db;
    if (db == null) {
      return SimulatedApi.run(
        () => _local.where((s) => s.conversationId == conversationId).toList(),
      );
    }

    final rows = await db
        .from('consultation_summaries')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false);
    return rows.map(consultationSummaryFromRow).toList();
  }

  /// Menyimpan resume baru. Dipakai dokter setelah sesi konsultasi selesai.
  Future<ConsultationSummary> create(ConsultationSummary summary) async {
    final db = _db;
    if (db == null) {
      return SimulatedApi.run(() {
        final saved = ConsultationSummary(
          id: 'sum_${_local.length + 1}',
          conversationId: summary.conversationId,
          patientName: summary.patientName,
          doctorId: summary.doctorId,
          doctorName: summary.doctorName,
          specialization: summary.specialization,
          diagnosis: summary.diagnosis,
          notes: summary.notes,
          prescriptions: summary.prescriptions,
          advice: summary.advice,
          createdAt: summary.createdAt,
        );
        _local.insert(0, saved);
        return saved;
      });
    }

    final row = await db
        .from('consultation_summaries')
        .insert({
          'conversation_id': summary.conversationId,
          'patient_name': summary.patientName,
          'doctor_id': summary.doctorId,
          'doctor_name': summary.doctorName,
          'specialization': summary.specialization,
          'diagnosis': summary.diagnosis,
          'notes': summary.notes,
          'prescriptions': summary.prescriptions,
          'advice': summary.advice,
          'created_at': summary.createdAt.toUtc().toIso8601String(),
        })
        .select()
        .single();
    return consultationSummaryFromRow(row);
  }
}
