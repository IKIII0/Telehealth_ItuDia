import 'package:flutter/material.dart';

/// Model dokter. `id` dipakai sebagai kunci relasi dari entitas lain
/// (mis. pengingat obat -> doctorId, jadwal konsultasi -> doctorId).
class Doctor {
  const Doctor({
    required this.id,
    required this.name,
    required this.specialization,
    required this.experience,
    required this.rating,
    required this.price,
    required this.available,
    required this.hospital,
    required this.bio,
    required this.education,
    this.avatarColor = const Color(0xFF1E88E5),
  });

  final String id;
  final String name;
  final String specialization;
  final int experience; // tahun
  final double rating;
  final int price; // harga konsultasi (Rp)
  final bool available;
  final String hospital;
  final String bio;
  final String education;
  final Color avatarColor;

  /// Inisial nama untuk avatar (mis. "Dr. Ahmad Fauzi" -> "AF").
  String get initials {
    final cleaned = name.replaceAll('Dr.', '').replaceAll(',', ' ');
    final parts = cleaned
        .split(' ')
        .where((p) => p.isNotEmpty && !p.startsWith('Sp'))
        .toList();
    if (parts.isEmpty) return 'DR';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  Doctor copyWith({
    String? name,
    String? specialization,
    int? experience,
    double? rating,
    int? price,
    bool? available,
    String? hospital,
    String? bio,
    String? education,
    Color? avatarColor,
  }) {
    return Doctor(
      id: id,
      name: name ?? this.name,
      specialization: specialization ?? this.specialization,
      experience: experience ?? this.experience,
      rating: rating ?? this.rating,
      price: price ?? this.price,
      available: available ?? this.available,
      hospital: hospital ?? this.hospital,
      bio: bio ?? this.bio,
      education: education ?? this.education,
      avatarColor: avatarColor ?? this.avatarColor,
    );
  }
}
