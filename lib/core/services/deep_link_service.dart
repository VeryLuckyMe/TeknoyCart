sealed class DeepLinkDestination {
  const DeepLinkDestination();
}

class DeepLinkOrder extends DeepLinkDestination {
  final String orderId;
  const DeepLinkOrder(this.orderId);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is DeepLinkOrder && other.orderId == orderId);

  @override
  int get hashCode => orderId.hashCode;
}

class DeepLinkWishlist extends DeepLinkDestination {
  const DeepLinkWishlist();

  @override
  bool operator ==(Object other) => other is DeepLinkWishlist;

  @override
  int get hashCode => (DeepLinkWishlist).hashCode;
}

class DeepLinkHome extends DeepLinkDestination {
  const DeepLinkHome();

  @override
  bool operator ==(Object other) => other is DeepLinkHome;

  @override
  int get hashCode => (DeepLinkHome).hashCode;
}

/// Represents auth callbacks (e.g., `teknoycart://login-callback`) that are
/// already handled by `supabase_flutter` and must be ignored by `DeepLinkService`.
class DeepLinkIgnored extends DeepLinkDestination {
  final Uri rawUri;
  const DeepLinkIgnored(this.rawUri);
}

class DeepLinkUnknown extends DeepLinkDestination {
  final Uri? rawUri;
  const DeepLinkUnknown([this.rawUri]);
}

class DeepLinkParser {
  static const String scheme = 'teknoycart';

  static DeepLinkDestination parse(Uri? uri) {
    if (uri == null) return const DeepLinkUnknown();
    if (uri.scheme.toLowerCase() != scheme) {
      return DeepLinkUnknown(uri);
    }

    final host = uri.host.toLowerCase().trim();
    switch (host) {
      case 'login-callback':
        return DeepLinkIgnored(uri);
      case 'home':
        return const DeepLinkHome();
      case 'wishlist':
        return const DeepLinkWishlist();
      case 'order':
      case 'orders':
        String? orderId = uri.queryParameters['id']?.trim() ??
            uri.queryParameters['order']?.trim() ??
            uri.queryParameters['order_id']?.trim();
        if (orderId == null || orderId.isEmpty) {
          final segments = uri.pathSegments
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
          if (segments.isNotEmpty) {
            orderId = segments.first;
          }
        }
        if (orderId != null && orderId.isNotEmpty) {
          return DeepLinkOrder(orderId);
        }
        return DeepLinkUnknown(uri);
      default:
        return DeepLinkUnknown(uri);
    }
  }
}
