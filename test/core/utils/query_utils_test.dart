@TestOn('vm')
library;

import 'package:aio_studio/core/utils/query_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('escapeLikePattern', () {
    test('returns plain text unchanged', () {
      expect(escapeLikePattern('hello'), 'hello');
    });

    test('escapes percent sign', () {
      expect(escapeLikePattern('100%'), r'100\%');
    });

    test('escapes underscore', () {
      expect(escapeLikePattern('a_b'), r'a\_b');
    });

    test('escapes backslash', () {
      expect(escapeLikePattern(r'c:\path'), r'c:\\path');
    });

    test('escapes all special chars in combination', () {
      expect(escapeLikePattern(r'50%_off\sale'), r'50\%\_off\\sale');
    });

    test('handles empty string', () {
      expect(escapeLikePattern(''), '');
    });

    test('handles string with only special chars', () {
      expect(escapeLikePattern(r'%_\'), r'\%\_\\');
    });

    test('preserves unicode characters', () {
      expect(escapeLikePattern('你好%世界'), r'你好\%世界');
    });

    test('handles consecutive special chars', () {
      expect(escapeLikePattern('%%__'), r'\%\%\_\_');
    });
  });
}
