import 'package:flutter/material.dart';

import 'package:Telehealth/data/models/doctor_profile.dart';

/// Role akun yang didukung aplikasi.
enum UserRole {
  patient,
  doctor,
  hospitalAdmin;

  String get label => switch (this) {
    UserRole.patient => 'Pasien',
    UserRole.doctor => 'Dokter',
    UserRole.hospitalAdmin => 'Admin Rumah Sakit',
  };

  /// Nilai role yang disimpan di Firestore dan Supabase.
  String get storageValue => switch (this) {
    UserRole.patient => 'patient',
    UserRole.doctor => 'doctor',
    UserRole.hospitalAdmin => 'hospital_admin',
  };

  /// `true` bila role berhak membuka Web Dashboard Admin Rumah Sakit.
  bool get isHospitalAdmin => this == UserRole.hospitalAdmin;
}

/// Akun pengguna hasil autentikasi.
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.avatarColor = const Color(0xFF1E88E5),
    this.doctorProfile,
  });

  final String id;
  final String name;
  final String email;
  final UserRole role;
  final Color avatarColor;

  /// Hanya terisi untuk akun dengan role [UserRole.doctor].
  final DoctorProfile? doctorProfile;

  /// Inisial nama untuk avatar.
  String get initials {
    final cleaned = name.replaceAll('dr.', '').replaceAll(',', ' ');
    final parts = cleaned
        .split(' ')
        .where((part) => part.isNotEmpty && !part.startsWith('Sp'))
        .toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  AppUser copyWith({
    String? id,
    String? name,
    String? email,
    UserRole? role,
    Color? avatarColor,
    DoctorProfile? doctorProfile,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      avatarColor: avatarColor ?? this.avatarColor,
      doctorProfile: doctorProfile ?? this.doctorProfile,
    );
  }
}
