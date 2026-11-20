import 'package:flutter/material.dart';

/// Ikon penanda area aplikasi berdasarkan role pengguna.
///
/// Dipakai pada AppBar halaman pasien/dokter agar pengguna tahu sedang berada
/// di area role mana.
class RoleBadge extends StatelessWidget {
  const RoleBadge.patient({super.key, this.size = 24}) : isDoctor = false;

  const RoleBadge.doctor({super.key, this.size = 24}) : isDoctor = true;

  static const String patientIcon = 'assets/icons/Pasien.png';
  static const String doctorIcon = 'assets/icons/Dokter.png';

  final bool isDoctor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Image.asset(
        isDoctor ? doctorIcon : patientIcon,
        width: size,
        height: size,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}
