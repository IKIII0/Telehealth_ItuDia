import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telehealth_app/core/theme/app_theme.dart';
import 'package:telehealth_app/shared/widgets/app_button.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: Center(child: child)),
    );
  }

  testWidgets('menampilkan label dan merespon tap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(AppButton(label: 'Simpan', onPressed: () => tapped = true)),
    );

    expect(find.text('Simpan'), findsOneWidget);
    await tester.tap(find.byType(AppButton));
    expect(tapped, isTrue);
  });

  testWidgets('saat loading: spinner tampil dan tap diabaikan',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(
        AppButton(
          label: 'Simpan',
          isLoading: true,
          onPressed: () => tapped = true,
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Simpan'), findsNothing);
    await tester.tap(find.byType(AppButton), warnIfMissed: false);
    expect(tapped, isFalse);
  });
}
