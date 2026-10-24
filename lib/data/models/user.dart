import 'package:flutter/material.dart';

import 'package:Telehealth/data/models/doctor_profile.dart';

/// Role akun yang didukung aplikasi.
enum UserRole {
  patient,
  doctor;

  String get label => switch (this) {
    UserRole.patient => 'Pasien',
    UserRole.doctor => 'Dokter',
  };
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
}
