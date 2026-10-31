import 'package:Telehealth/data/services/password_reset_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PasswordResetService.maskEmail', () {
    test('menyamarkan email dengan tetap menampilkan domain', () {
      expect(
        PasswordResetService.maskEmail('farhan@gmail.com'),
        'f***n@gmail.com',
      );
    });

    test('menyamarkan email lokal yang pendek', () {
      expect(PasswordResetService.maskEmail('ab@gmail.com'), 'a***@gmail.com');
    });

    test('email tidak valid dikembalikan apa adanya', () {
      expect(PasswordResetService.maskEmail('bukan-email'), 'bukan-email');
    });
  });
}
