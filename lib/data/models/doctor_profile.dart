/// Profil kredensial dokter yang sedang login.
///
/// `doctorId` menghubungkan profil ini dengan data direktori [Doctor].
class DoctorProfile {
  const DoctorProfile({
    required this.doctorId,
    required this.specialization,
    required this.strNumber,
    required this.hospital,
    required this.experienceYears,
    required this.bio,
    required this.practiceSchedule,
    required this.phone,
    this.verified = false,
  });

  final String doctorId;
  final String specialization;
  final String strNumber;
  final String hospital;
  final int experienceYears;
  final String bio;

  /// Jadwal praktik: nama hari → rentang jam.
  final Map<String, String> practiceSchedule;
  final String phone;

  /// Status verifikasi kredensial. Default `false` karena belum ada mekanisme
  /// verifikasi nyata.
  final bool verified;
}
