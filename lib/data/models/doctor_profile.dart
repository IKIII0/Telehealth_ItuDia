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

  DoctorProfile copyWith({
    String? doctorId,
    String? specialization,
    String? strNumber,
    String? hospital,
    int? experienceYears,
    String? bio,
    Map<String, String>? practiceSchedule,
    String? phone,
    bool? verified,
  }) {
    return DoctorProfile(
      doctorId: doctorId ?? this.doctorId,
      specialization: specialization ?? this.specialization,
      strNumber: strNumber ?? this.strNumber,
      hospital: hospital ?? this.hospital,
      experienceYears: experienceYears ?? this.experienceYears,
      bio: bio ?? this.bio,
      practiceSchedule: practiceSchedule ?? Map.from(this.practiceSchedule),
      phone: phone ?? this.phone,
      verified: verified ?? this.verified,
    );
  }

  /// Profil simulasi default untuk dokter yang login.
  static DoctorProfile simulatedDefault() {
    return const DoctorProfile(
      doctorId: 'doc1',
      specialization: 'Spesialis Jantung & Pembuluh Darah',
      strNumber: 'STR-2024-16284',
      hospital: 'RS Jantung Harapan Kita',
      experienceYears: 12,
      bio:
          'Spesialis jantung berpengalaman dalam penanganan penyakit '
          'jantung koroner, aritmia, dan gagal jantung. Melayani '
          'konsultasi telemedisin dan edukasi pencegahan kardiovaskular.',
      practiceSchedule: {
        'Senin - Jumat': '09:00 - 15:00',
        'Sabtu': '09:00 - 12:00',
        'Minggu': 'Libur / On Call',
      },
      phone: '+62 812 9000 1122',
      verified: true,
    );
  }
}
