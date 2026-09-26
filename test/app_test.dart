import 'package:flutter_test/flutter_test.dart';
import 'package:telehealth_app/app.dart';

void main() {
  testWidgets('menampilkan galeri design system sebagai home sementara',
      (tester) async {
    await tester.pumpWidget(const TelehealthApp());

    expect(find.text('Design System'), findsOneWidget);
    expect(find.text('Primary'), findsOneWidget);
  });
}
