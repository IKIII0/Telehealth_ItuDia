import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter_test/flutter_test.dart';
import 'package:Telehealth/data/services/auth_service.dart';

void main() {
  group('AuthService.messageFor', () {
    String messageForCode(String code) =>
        AuthService.messageFor(FirebaseAuthException(code: code));

    test('email-already-in-use menghasilkan pesan yang jelas', () {
      expect(
        messageForCode('email-already-in-use'),
        contains('sudah terdaftar'),
      );
    });

    test('wrong-password dan invalid-credential memakai pesan kredensial', () {
      expect(messageForCode('wrong-password'), contains('salah'));
      expect(messageForCode('invalid-credential'), contains('salah'));
    });

    test('user-not-found menyebut akun tidak ditemukan', () {
      expect(messageForCode('user-not-found'), contains('tidak ditemukan'));
    });

    test('weak-password menyebut batas minimal karakter', () {
      expect(messageForCode('weak-password'), contains('6 karakter'));
    });

    test('invalid-email menyebut format email', () {
      expect(messageForCode('invalid-email'), contains('Format email'));
    });

    test('configuration-not-found mengarahkan aktivasi Email/Password', () {
      expect(
        messageForCode('configuration-not-found'),
        contains('Email/Password'),
      );
    });

    test('operation-not-allowed mengarahkan aktivasi Email/Password', () {
      expect(
        messageForCode('operation-not-allowed'),
        contains('Email/Password'),
      );
    });

    test('no-app FirebaseException menyebut inisialisasi Firebase', () {
      expect(
        AuthService.messageFor(
          FirebaseException(plugin: 'test', code: 'no-app'),
        ),
        contains('belum diinisialisasi'),
      );
    });

    test('MissingPluginException menyarankan build ulang', () {
      expect(
        AuthService.messageFor(MissingPluginException('auth')),
        contains('jalankan ulang'),
      );
    });

    test('kode tidak dikenal memakai pesan umum', () {
      expect(
        messageForCode('something-unexpected'),
        contains('Terjadi kesalahan'),
      );
    });

    test('AuthException diteruskan tanpa diubah', () {
      const error = AuthException('Pesan khusus');
      expect(AuthService.messageFor(error), 'Pesan khusus');
    });

    test('error non-Firebase memakai pesan umum', () {
      expect(
        AuthService.messageFor(Exception('boom')),
        contains('Terjadi kesalahan'),
      );
    });
  });
}
