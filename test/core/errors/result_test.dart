import 'package:flutter_test/flutter_test.dart';
import 'package:telehealth_app/core/errors/failure.dart';
import 'package:telehealth_app/core/errors/result.dart';

void main() {
  group('Result', () {
    test('Success membawa data dan fold memanggil onSuccess', () {
      const Result<int> result = Success(42);

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, 42);
      expect(result.failureOrNull, isNull);
      expect(result.fold((f) => 'gagal', (data) => 'data $data'), 'data 42');
    });

    test('ResultError membawa failure dan fold memanggil onFailure', () {
      const Result<int> result = ResultError(NetworkFailure());

      expect(result.isSuccess, isFalse);
      expect(result.dataOrNull, isNull);
      expect(result.failureOrNull, isA<NetworkFailure>());
      expect(
        result.fold((f) => f.message, (data) => 'data'),
        const NetworkFailure().message,
      );
    });
  });
}
