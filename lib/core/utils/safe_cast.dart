/// Defensive type-safe parsing helpers for Postgrest / Supabase dynamic responses.
/// Prevents runtime [TypeError] when Postgrest payloads deviate from expected shapes.
class SafeCast {
  SafeCast._();

  /// Safely converts a dynamic response into a typed `List<Map<String, dynamic>>`.
  /// Returns an empty list if [response] is null, not a [List], or empty.
  static List<Map<String, dynamic>> toListOfMaps(dynamic response) {
    if (response is! List) return const [];
    return response
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  /// Safely converts a dynamic response into a `List<dynamic>`.
  /// Returns an empty list if [response] is not a [List].
  static List<dynamic> toList(dynamic response) {
    if (response is List) return response;
    return const [];
  }

  /// Safely extracts a `Map<String, dynamic>` from dynamic response.
  /// Returns null if [response] is not a [Map].
  static Map<String, dynamic>? toMap(dynamic response) {
    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }
    return null;
  }

  /// Safely extracts a list of strings from a dynamic field (e.g. image URLs).
  static List<String> toStringList(dynamic value) {
    if (value is! List) return const [];
    return value.map((item) => item?.toString() ?? '').where((s) => s.isNotEmpty).toList();
  }
}
