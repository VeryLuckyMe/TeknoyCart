import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Abstract storage adapter allowing in-memory swapping in unit/widget tests.
abstract class SearchHistoryStorageAdapter {
  Future<List<String>> readHistory();
  Future<void> writeHistory(List<String> history);
  Future<void> clearHistory();
}

/// Production storage adapter backing search history into FlutterSecureStorage.
class SecureSearchHistoryStorageAdapter implements SearchHistoryStorageAdapter {
  final FlutterSecureStorage _storage;
  static const String _storageKey = 'teknoycart_search_history_v1';

  const SecureSearchHistoryStorageAdapter([
    this._storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    ),
  ]);

  bool get _hasBinding {
    try {
      WidgetsBinding.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<String>> readHistory() async {
    try {
      if (!_hasBinding) return [];
      final raw = await _storage.read(key: _storageKey);
      if (raw == null || raw.trim().isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> writeHistory(List<String> history) async {
    try {
      if (!_hasBinding) return;
      await _storage.write(key: _storageKey, value: jsonEncode(history));
    } catch (_) {}
  }

  @override
  Future<void> clearHistory() async {
    try {
      if (!_hasBinding) return;
      await _storage.delete(key: _storageKey);
    } catch (_) {}
  }
}

/// In-memory storage adapter for zero-mock, lightning fast test execution.
class InMemorySearchHistoryStorageAdapter implements SearchHistoryStorageAdapter {
  List<String> _items;

  InMemorySearchHistoryStorageAdapter([List<String>? initial])
      : _items = List<String>.from(initial ?? []);

  @override
  Future<List<String>> readHistory() async => List<String>.from(_items);

  @override
  Future<void> writeHistory(List<String> history) async {
    _items = List<String>.from(history);
  }

  @override
  Future<void> clearHistory() async {
    _items.clear();
  }
}

/// State notifier managing user search keywords with automatic de-duplication,
/// max length cap, and persistence.
class SearchHistoryNotifier extends StateNotifier<List<String>> {
  final SearchHistoryStorageAdapter _storage;
  static const int maxHistoryLength = 8;

  SearchHistoryNotifier(this._storage) : super(const []) {
    load();
  }

  /// Loads stored search history from persistent storage.
  Future<void> load() async {
    final list = await _storage.readHistory();
    state = List<String>.unmodifiable(list);
  }

  /// Records a new search term. Trims, checks >= 2 chars, deduplicates case-insensitively,
  /// places at the head of the list, and limits length to [maxHistoryLength].
  Future<void> addQuery(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.length < 2) return;

    final updated = List<String>.from(state);
    // Remove existing occurrence case-insensitively
    updated.removeWhere((item) => item.toLowerCase() == query.toLowerCase());

    // Insert at front
    updated.insert(0, query);

    // Enforce max length cap
    if (updated.length > maxHistoryLength) {
      updated.removeRange(maxHistoryLength, updated.length);
    }

    state = List<String>.unmodifiable(updated);
    await _storage.writeHistory(updated);
  }

  /// Removes a specific search term.
  Future<void> removeQuery(String rawQuery) async {
    final query = rawQuery.trim();
    final updated = List<String>.from(state);
    updated.removeWhere((item) => item.toLowerCase() == query.toLowerCase());

    state = List<String>.unmodifiable(updated);
    await _storage.writeHistory(updated);
  }

  /// Clears all stored search history.
  Future<void> clearAll() async {
    state = const [];
    await _storage.clearHistory();
  }
}

/// Provider for the search history storage adapter (can be overridden in tests).
final searchHistoryStorageProvider = Provider<SearchHistoryStorageAdapter>((ref) {
  return const SecureSearchHistoryStorageAdapter();
});

/// Riverpod state notifier provider for search history.
final searchHistoryProvider = StateNotifierProvider<SearchHistoryNotifier, List<String>>((ref) {
  final storage = ref.watch(searchHistoryStorageProvider);
  return SearchHistoryNotifier(storage);
});

/// Convenience provider indicating whether any search history exists.
final hasSearchHistoryProvider = Provider<bool>((ref) {
  return ref.watch(searchHistoryProvider).isNotEmpty;
});

