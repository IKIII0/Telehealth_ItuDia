import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Telehealth/app.dart';
import 'package:Telehealth/features/authentication/presentation/pages/login_page.dart';

void main() {
  testWidgets('aplikasi menampilkan splash screen saat dibuka', (tester) async {
    await tester.pumpWidget(const TelehealthApp());
    expect(find.text('Telehealth'), findsOneWidget);

    // Selesaikan timer splash agar tidak ada timer yang tertinggal.
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('halaman login dapat dirender', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));
    await tester.pump();
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text('Masuk'), findsWidgets);
  });

  testWidgets('login tidak berpindah halaman bila field kosong', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));
    await tester.pump();

    await tester.tap(find.text('Masuk').first);
    await tester.pump();

    // Validasi mencegah navigasi keluar dari halaman login.
    expect(find.byType(LoginPage), findsOneWidget);
  });
}
