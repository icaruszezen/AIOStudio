import 'package:aio_studio/core/utils/epoch_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('epochNowMs', () {
    test('returns a value close to DateTime.now().millisecondsSinceEpoch', () {
      final before = DateTime.now().millisecondsSinceEpoch;
      final result = epochNowMs();
      final after = DateTime.now().millisecondsSinceEpoch;

      expect(result, greaterThanOrEqualTo(before));
      expect(result, lessThanOrEqualTo(after));
    });

    test('returns a positive integer', () {
      expect(epochNowMs(), isPositive);
    });

    test('successive calls are non-decreasing', () {
      final first = epochNowMs();
      final second = epochNowMs();
      expect(second, greaterThanOrEqualTo(first));
    });
  });
}
