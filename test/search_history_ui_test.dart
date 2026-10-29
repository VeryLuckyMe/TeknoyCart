import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/models/product.dart';
import 'package:teknoycart/core/services/search_history_service.dart';
import 'package:teknoycart/features/feed/providers/product_provider.dart';
import 'package:teknoycart/features/feed/views/search_results_view.dart';
import 'package:teknoycart/features/feed/views/tabs/browse_tab.dart';
import 'package:teknoycart/features/feed/views/widgets/search_history_chips.dart';

Widget _createTestApp({
  required Widget child,
  List<String>? initialHistory,
  void Function(String)? onSelectQuery,
}) {
  return ProviderScope(
    overrides: [
      searchHistoryStorageProvider.overrideWithValue(
        InMemorySearchHistoryStorageAdapter(initialHistory ?? []),
      ),
      productsListProvider.overrideWith((ref) => []),
      categoriesProvider.overrideWith((ref) => ['All', 'Books', 'Uniforms']),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: child,
      ),
    ),
  );
}

void main() {
  group('GAP-08: SearchHistoryChips Widget Tests', () {
    testWidgets('Renders empty/nothing when history is empty', (tester) async {
      await tester.pumpWidget(
        _createTestApp(
          child: const SearchHistoryChips(),
          initialHistory: [],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Recent Searches'), findsNothing);
      expect(find.byType(ActionChip), findsNothing);
    });

    testWidgets('Renders recent search chips and header when items exist', (tester) async {
      await tester.pumpWidget(
        _createTestApp(
          child: const SearchHistoryChips(),
          initialHistory: ['Calculus', 'Uniforms', 'T-Square'],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Recent Searches'), findsOneWidget);
      expect(find.text('Clear All'), findsOneWidget);
      expect(find.text('Calculus'), findsOneWidget);
      expect(find.text('Uniforms'), findsOneWidget);
      expect(find.text('T-Square'), findsOneWidget);
    });

    testWidgets('Tapping chip triggers onSelectQuery callback', (tester) async {
      String? selectedQuery;
      await tester.pumpWidget(
        _createTestApp(
          child: SearchHistoryChips(
            onSelectQuery: (q) => selectedQuery = q,
          ),
          initialHistory: ['Calculus', 'Drawing Board'],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Calculus'));
      await tester.pumpAndSettle();

      expect(selectedQuery, equals('Calculus'));
    });

    testWidgets('Tapping delete icon on a chip removes it from history', (tester) async {
      await tester.pumpWidget(
        _createTestApp(
          child: const SearchHistoryChips(),
          initialHistory: ['Calculus', 'Drawing Board'],
        ),
      );
      await tester.pumpAndSettle();

      final deleteBtnFinder = find.byKey(const ValueKey('delete_chip_Calculus'));
      expect(deleteBtnFinder, findsOneWidget);

      await tester.tap(deleteBtnFinder);
      await tester.pumpAndSettle();

      expect(find.text('Calculus'), findsNothing);
      expect(find.text('Drawing Board'), findsOneWidget);
    });

    testWidgets('Tapping Clear All clears all chips', (tester) async {
      await tester.pumpWidget(
        _createTestApp(
          child: const SearchHistoryChips(),
          initialHistory: ['Calculus', 'Drawing Board'],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Clear All'));
      await tester.pumpAndSettle();

      expect(find.text('Recent Searches'), findsNothing);
      expect(find.text('Calculus'), findsNothing);
      expect(find.text('Drawing Board'), findsNothing);
    });

    testWidgets('BrowseTab renders SearchHistoryChips below search bar when history exists', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _createTestApp(
          child: const BrowseTab(),
          initialHistory: ['Calculus Textbook', 'Engineering Uniform'],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Recent Searches'), findsOneWidget);
      expect(find.text('Calculus Textbook'), findsOneWidget);
      expect(find.text('Engineering Uniform'), findsOneWidget);
    });

    testWidgets('SearchResultsView records initialQuery and renders history chips', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final storage = InMemorySearchHistoryStorageAdapter(['Existing Query']);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            searchHistoryStorageProvider.overrideWithValue(storage),
            productsListProvider.overrideWith((ref) => []),
            matchingStoresProvider('New Query').overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: SearchResultsView(initialQuery: 'New Query'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Recent Searches'), findsWidgets);
      expect(find.text('New Query'), findsWidgets);
    });
  });
}
