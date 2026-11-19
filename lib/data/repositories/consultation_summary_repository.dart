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

  /// Penyimpanan lokal saat Supabase belum dikonfigurasi.
  /// Tidak diisi data contoh: resume hanya dibuat oleh dokter sungguhan.
  final List<ConsultationSummary> _local = [];

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
