import 'package:flutter_test/flutter_test.dart';
import 'package:teknoycart/core/services/search_history_service.dart';

void main() {
  group('GAP-08: SearchHistoryService & Notifier Unit Tests', () {
    late InMemorySearchHistoryStorageAdapter storage;
    late SearchHistoryNotifier notifier;

    setUp(() {
      storage = InMemorySearchHistoryStorageAdapter();
      notifier = SearchHistoryNotifier(storage);
    });

    test('Initial state is empty when storage has no records', () async {
      await notifier.load();
      expect(notifier.state, isEmpty);
    });

    test('Initial state loads saved queries from storage adapter', () async {
      storage = InMemorySearchHistoryStorageAdapter(['Calculus', 'Uniform', 'T-Square']);
      notifier = SearchHistoryNotifier(storage);
      await notifier.load();

      expect(notifier.state, equals(['Calculus', 'Uniform', 'T-Square']));
    });

    test('addQuery inserts valid keyword at the front of history', () async {
      await notifier.load();
      await notifier.addQuery('Drawing Board');

      expect(notifier.state, equals(['Drawing Board']));
      expect(await storage.readHistory(), equals(['Drawing Board']));

      await notifier.addQuery('Calculus Book');
      expect(notifier.state, equals(['Calculus Book', 'Drawing Board']));
    });

    test('addQuery ignores empty or single-character strings', () async {
      await notifier.load();
      await notifier.addQuery('');
      await notifier.addQuery('   ');
      await notifier.addQuery('a');

      expect(notifier.state, isEmpty);
    });

    test('addQuery promotes duplicate case-insensitively without duplicating', () async {
      storage = InMemorySearchHistoryStorageAdapter(['Calculus', 'Uniform']);
      notifier = SearchHistoryNotifier(storage);
      await notifier.load();

      await notifier.addQuery('calculus');

      expect(notifier.state, equals(['calculus', 'Uniform']));
      expect(notifier.state.length, equals(2));
    });

    test('addQuery trims surrounding whitespace', () async {
      await notifier.load();
      await notifier.addQuery('   Scientific Calculator   ');

      expect(notifier.state, equals(['Scientific Calculator']));
    });

    test('addQuery caps list at maxHistoryLength (8)', () async {
      await notifier.load();
      for (int i = 1; i <= 10; i++) {
        await notifier.addQuery('Query $i');
      }

      expect(notifier.state.length, equals(8));
      expect(notifier.state.first, equals('Query 10'));
      expect(notifier.state.last, equals('Query 3'));
    });

    test('removeQuery removes targeted search term case-insensitively', () async {
      storage = InMemorySearchHistoryStorageAdapter(['Books', 'Drawing', 'Uniforms']);
      notifier = SearchHistoryNotifier(storage);
      await notifier.load();

      await notifier.removeQuery('drawing');

      expect(notifier.state, equals(['Books', 'Uniforms']));
      expect(await storage.readHistory(), equals(['Books', 'Uniforms']));
    });

    test('clearAll wipes entire search history from state and storage', () async {
      storage = InMemorySearchHistoryStorageAdapter(['Books', 'Uniforms']);
      notifier = SearchHistoryNotifier(storage);
      await notifier.load();

      await notifier.clearAll();

      expect(notifier.state, isEmpty);
      expect(await storage.readHistory(), isEmpty);
    });
  });
}
