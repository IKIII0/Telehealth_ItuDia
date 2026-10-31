import 'package:Telehealth/features/authentication/presentation/models/reset_link_sent_args.dart';
import 'package:Telehealth/features/authentication/presentation/pages/reset_link_sent_page.dart';
import 'package:Telehealth/features/authentication/presentation/pages/reset_password_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('halaman reset dimulai dengan pencarian email akun', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ResetPasswordPage()));
    await tester.pump();

    expect(find.text('Cari Akun'), findsOneWidget);
    expect(find.text('Email Akun'), findsOneWidget);
    expect(find.text('Kirim Link Reset'), findsNothing);
  });

  testWidgets('halaman konfirmasi menampilkan email tersamarkan', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ResetLinkSentPage(
          args: ResetLinkSentArgs(email: 'pasien@email.com'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Cek Email Anda'), findsOneWidget);
    expect(find.textContaining('p***n@email.com'), findsOneWidget);
    expect(find.text('Kembali ke Login'), findsOneWidget);
    expect(find.text('Kirim Ulang Tautan'), findsOneWidget);
  });
}
