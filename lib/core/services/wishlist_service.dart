import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Local persistence service for student favorites / wishlist (Ponytail Audit H7).
class WishlistService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _keyFavorites = 'teknoy_favorite_product_ids';

  static Future<Set<String>> getFavorites() async {
    try {
      final data = await _storage.read(key: _keyFavorites);
      if (data == null || data.isEmpty) return {};
      final list = jsonDecode(data) as List<dynamic>;
      return list.map((e) => e.toString()).toSet();
    } catch (_) {
      return {};
    }
  }

  static Future<bool> isFavorite(String productId) async {
    final favs = await getFavorites();
    return favs.contains(productId);
  }

  static Future<bool> toggleFavorite(String productId) async {
    try {
      final favs = await getFavorites();
      bool added;
      if (favs.contains(productId)) {
        favs.remove(productId);
        added = false;
      } else {
        favs.add(productId);
        added = true;
      }
      await _storage.write(key: _keyFavorites, value: jsonEncode(favs.toList()));
      return added;
    } catch (_) {
      return false;
    }
  }
}
