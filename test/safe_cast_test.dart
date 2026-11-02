import 'package:flutter_test/flutter_test.dart';
import 'package:teknoycart/core/utils/safe_cast.dart';

void main() {
  group('SafeCast Defensive Type Conversion Tests', () {
    test('toListOfMaps parses valid lists of maps and discards non-map items', () {
      final input = [
        {'id': 1, 'name': 'Item A'},
        'invalid item',
        123,
        {'id': 2, 'name': 'Item B'},
      ];

      final result = SafeCast.toListOfMaps(input);

      expect(result.length, 2);
      expect(result[0]['name'], 'Item A');
      expect(result[1]['name'], 'Item B');
    });

    test('toListOfMaps safely returns empty list for null, empty, or non-list values', () {
      expect(SafeCast.toListOfMaps(null), isEmpty);
      expect(SafeCast.toListOfMaps([]), isEmpty);
      expect(SafeCast.toListOfMaps('not a list'), isEmpty);
      expect(SafeCast.toListOfMaps({'key': 'value'}), isEmpty);
    });

    test('toList returns list when valid, empty list otherwise', () {
      expect(SafeCast.toList([1, 2, 3]), [1, 2, 3]);
      expect(SafeCast.toList(null), isEmpty);
      expect(SafeCast.toList('string'), isEmpty);
    });

    test('toMap converts valid maps and returns null for non-maps', () {
      final map = SafeCast.toMap({'code': 'OK'});
      expect(map?['code'], 'OK');

      expect(SafeCast.toMap(null), isNull);
      expect(SafeCast.toMap([1, 2]), isNull);
      expect(SafeCast.toMap('string'), isNull);
    });

    test('toStringList extracts strings and drops empty or null items', () {
      final input = ['https://img1.png', null, '', 'https://img2.png'];
      final result = SafeCast.toStringList(input);

      expect(result, ['https://img1.png', 'https://img2.png']);
      expect(SafeCast.toStringList(null), isEmpty);
    });
  });
}

