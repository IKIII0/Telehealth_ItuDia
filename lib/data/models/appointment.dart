/// Jadwal konsultasi pada beranda.
///
/// `doctorId` adalah relasi ke [Doctor].
class Appointment {
  const Appointment({
    required this.id,
    required this.doctorId,
    required this.doctorName,
    required this.specialization,
    required this.date,
    required this.time,
  });

  final String id;
  final String doctorId;
  final String doctorName;
  final String specialization;
  final String date;
  final String time;
}
