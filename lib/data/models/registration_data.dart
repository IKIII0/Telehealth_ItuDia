import 'user.dart';

/// Seluruh data yang dikumpulkan dari form registrasi.
///
/// Model ini menjadi kontrak tunggal antara UI registrasi, Firebase, dan
/// Supabase sehingga penambahan field cukup dilakukan di satu tempat.
/// Semua field selain [email] dan [name] bersifat opsional agar aman bila
/// form belum mengumpulkannya.
class RegistrationData {
  const RegistrationData({
    required this.email,
    required this.name,
    this.phone,
    this.birthDate,
    this.gender,
    this.address,
    this.bloodType,
    this.role,
    this.specialization,
    this.strNumber,
    this.hospital,
    this.experienceYears,
    this.bio,
    this.practiceSchedule = const {},
    this.directoryDoctorId,
    this.allergies = const [],
    this.chronicConditions = const [],
    this.medicalHistory,
    this.emergencyContactName,
    this.emergencyContactPhone,
  });

  final String email;
  final String name;

  // ── Data umum ───────────────────────────────────────────────────────────────
  final String? phone;

  /// Disimpan ke kolom `date` Supabase (tanpa jam).
  final DateTime? birthDate;

  /// Nilai mentah dari form ('Laki-laki' / 'Perempuan'); dinormalisasi saat
  /// ditulis ke Supabase.
  final String? gender;
  final String? address;
  final String? bloodType;

  /// `null` berarti pemanggil belum menentukan role; repository akan memakai
  /// role bawaan akun (template email) atau `patient`.
  final UserRole? role;

  // ── Khusus dokter ───────────────────────────────────────────────────────────
  final String? specialization;

  /// Nomor STR / lisensi praktik.
  final String? strNumber;
  final String? hospital;
  final int? experienceYears;
  final String? bio;

  /// Jadwal praktik: nama hari → rentang jam.
  final Map<String, String> practiceSchedule;

  /// Opsional: id pada tabel direktori `public.doctors`.
  final String? directoryDoctorId;

  // ── Khusus pasien ───────────────────────────────────────────────────────────
  final List<String> allergies;
  final List<String> chronicConditions;
  final String? medicalHistory;
  final String? emergencyContactName;
  final String? emergencyContactPhone;

  RegistrationData copyWith({
    String? email,
    String? name,
    String? phone,
    DateTime? birthDate,
    String? gender,
    String? address,
    String? bloodType,
    UserRole? role,
    String? specialization,
    String? strNumber,
    String? hospital,
    int? experienceYears,
    String? bio,
    Map<String, String>? practiceSchedule,
    String? directoryDoctorId,
    List<String>? allergies,
    List<String>? chronicConditions,
    String? medicalHistory,
    String? emergencyContactName,
    String? emergencyContactPhone,
  }) {
    return RegistrationData(
      email: email ?? this.email,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      address: address ?? this.address,
      bloodType: bloodType ?? this.bloodType,
      role: role ?? this.role,
      specialization: specialization ?? this.specialization,
      strNumber: strNumber ?? this.strNumber,
      hospital: hospital ?? this.hospital,
      experienceYears: experienceYears ?? this.experienceYears,
      bio: bio ?? this.bio,
      practiceSchedule: practiceSchedule ?? this.practiceSchedule,
      directoryDoctorId: directoryDoctorId ?? this.directoryDoctorId,
      allergies: allergies ?? this.allergies,
      chronicConditions: chronicConditions ?? this.chronicConditions,
      medicalHistory: medicalHistory ?? this.medicalHistory,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone:
          emergencyContactPhone ?? this.emergencyContactPhone,
    );
  }

  /// Salinan dengan role yang sudah dipastikan (mis. hasil fallback repo).
  RegistrationData withRole(UserRole value) => copyWith(role: value);
}
