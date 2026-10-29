import 'package:flutter_test/flutter_test.dart';
import 'package:Telehealth/data/models/user.dart';
import 'package:Telehealth/data/repositories/auth_repository.dart';

void main() {
  group('AuthRepository.parseRole', () {
    test('mengenali role doctor', () {
      expect(AuthRepository.parseRole('doctor'), UserRole.doctor);
      expect(AuthRepository.parseRole('dokter'), UserRole.doctor);
      expect(AuthRepository.parseRole(' Doctor '), UserRole.doctor);
    });

    test('mengenali role patient', () {
      expect(AuthRepository.parseRole('patient'), UserRole.patient);
      expect(AuthRepository.parseRole('pasien'), UserRole.patient);
    });

    test('nilai kosong atau tidak dikenal mengembalikan null', () {
      expect(AuthRepository.parseRole(null), isNull);
      expect(AuthRepository.parseRole(''), isNull);
      expect(AuthRepository.parseRole('admin'), isNull);
      expect(AuthRepository.parseRole(1), isNull);
    });
  });
}
