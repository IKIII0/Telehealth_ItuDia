import 'package:flutter/foundation.dart';

/// Data akun yang ditemukan pada tabel `profiles` sebelum tautan reset dikirim.
///
/// [uid] adalah Firebase UID (kolom `profiles.id`), bukan identitas sesi.
@immutable
class ResetAccount {
  const ResetAccount({
    required this.uid,
    required this.email,
    required this.fullName,
  });

  final String uid;
  final String email;
  final String fullName;
}
