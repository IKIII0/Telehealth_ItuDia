/// Resume/catatan medis hasil konsultasi dengan seorang dokter.
///
/// Dipakai agar dokter berikutnya dapat melihat apa yang sudah diberikan
/// (diagnosis, tindakan, dan obat) pada konsultasi sebelumnya.
class ConsultationSummary {
  const ConsultationSummary({
    required this.id,
    required this.patientName,
    required this.doctorId,
    required this.doctorName,
    required this.specialization,
    required this.diagnosis,
    required this.createdAt,
    this.conversationId,
    this.notes = '',
    this.prescriptions = const [],
    this.advice = '',
  });

  final String id;
  final String? conversationId;
  final String patientName;
  final String doctorId;
  final String doctorName;
  final String specialization;
  final String diagnosis;
  final String notes;
  final List<String> prescriptions;
  final String advice;
  final DateTime createdAt;

  /// Tanggal ringkas, mis. "17 Nov 2026".
  String get dateLabel {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${createdAt.day} ${months[createdAt.month - 1]} ${createdAt.year}';
  }
}
