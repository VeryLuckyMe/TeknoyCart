import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/features/checkout/views/order_detail_view.dart';
import 'package:teknoycart/features/feed/views/product_discovery_feed_view.dart';
import 'package:teknoycart/features/feed/views/wishlist_view.dart';
import 'package:teknoycart/features/splash/splash_view.dart';
import 'package:teknoycart/main.dart' show appNavigatorKey;

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

abstract class AppLinkSource {
  Future<Uri?> getInitialLink();
  Stream<Uri> get uriLinkStream;
}

class DefaultAppLinkSource implements AppLinkSource {
  final AppLinks _appLinks;

  DefaultAppLinkSource([AppLinks? appLinks]) : _appLinks = appLinks ?? AppLinks();

  @override
  Future<Uri?> getInitialLink() async {
    try {
      return await _appLinks.getInitialLink();
    } catch (e) {
      debugPrint('DEEP_LINK_INITIAL_READ_ERROR: $e');
      return null;
    }
  }

  @override
  Stream<Uri> get uriLinkStream => _appLinks.uriLinkStream;
}

class FakeAppLinkSource implements AppLinkSource {
  Uri? initialLink;
  final StreamController<Uri> _controller = StreamController<Uri>.broadcast(sync: true);

  FakeAppLinkSource({this.initialLink});

  @override
  Future<Uri?> getInitialLink() async {
    final link = initialLink;
    initialLink = null;
    return link;
  }

  @override
  Stream<Uri> get uriLinkStream => _controller.stream;

  void emit(Uri uri) {
    if (!_controller.isClosed) {
      _controller.add(uri);
    }
  }

  void dispose() {
    _controller.close();
  }
}

class DeepLinkService {
  final GlobalKey<NavigatorState> navigatorKey;
  final AppLinkSource _source;
  final bool Function() _isNavigationReady;
  final bool Function() _isAuthenticated;
  final Duration dedupWindow;
  final void Function(DeepLinkDestination destination)? onDestinationNavigated;

  StreamSubscription<Uri>? _subscription;
  DeepLinkDestination? _pendingDestination;
  DeepLinkDestination? _lastHandledDestination;
  DateTime? _lastHandledAt;
  bool _initialized = false;

  DeepLinkService({
    required this.navigatorKey,
    AppLinkSource? source,
    bool Function()? isNavigationReady,
    bool Function()? isAuthenticated,
    this.dedupWindow = const Duration(seconds: 2),
    this.onDestinationNavigated,
  })  : _source = source ?? DefaultAppLinkSource(),
        _isNavigationReady = isNavigationReady ?? (() => true),
        _isAuthenticated = isAuthenticated ?? (() => true);

  DeepLinkDestination? get pendingDestination => _pendingDestination;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    _subscription = _source.uriLinkStream.listen(
      (uri) {
        handleUri(uri);
      },
      onError: (Object err) {
        debugPrint('DEEP_LINK_STREAM_ERROR: $err');
      },
    );

    final initialUri = await _source.getInitialLink();
    if (initialUri != null) {
      await handleUri(initialUri);
    }
  }

  Future<void> handleUri(Uri? uri) async {
    final destination = DeepLinkParser.parse(uri);
    if (destination is DeepLinkIgnored || destination is DeepLinkUnknown) {
      return;
    }

    final now = DateTime.now();
    if (_lastHandledDestination == destination &&
        _lastHandledAt != null &&
        now.difference(_lastHandledAt!) < dedupWindow) {
      return;
    }

    final requiresAuth = destination is DeepLinkOrder;
    if (!_isNavigationReady() || (requiresAuth && !_isAuthenticated())) {
      _pendingDestination = destination;
      return;
    }

    _executeNavigation(destination, now);
  }

  Future<void> flushPending() async {
    final destination = _pendingDestination;
    if (destination == null) return;

    final requiresAuth = destination is DeepLinkOrder;
    if (!_isNavigationReady() || (requiresAuth && !_isAuthenticated())) {
      return;
    }

    _pendingDestination = null;
    _executeNavigation(destination, DateTime.now());
  }

  void _executeNavigation(DeepLinkDestination destination, DateTime timestamp) {
    final nav = navigatorKey.currentState;
    if (nav == null) {
      _pendingDestination = destination;
      return;
    }

    _lastHandledDestination = destination;
    _lastHandledAt = timestamp;
    onDestinationNavigated?.call(destination);

    switch (destination) {
      case DeepLinkOrder(:final orderId):
        nav.push(
          MaterialPageRoute(
            builder: (_) => OrderDetailView(
              order: {'order_id': orderId},
              isSeller: false,
            ),
          ),
        );
        break;
      case DeepLinkWishlist():
        nav.push(
          MaterialPageRoute(
            builder: (_) => const WishlistView(),
          ),
        );
        break;
      case DeepLinkHome():
        nav.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const ProductDiscoveryFeedView(),
          ),
          (route) => false,
        );
        break;
      case DeepLinkIgnored():
      case DeepLinkUnknown():
        break;
    }
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _initialized = false;
  }
}

final appLinkSourceProvider = Provider<AppLinkSource>((ref) {
  return DefaultAppLinkSource();
});

final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  final source = ref.watch(appLinkSourceProvider);
  final service = DeepLinkService(
    navigatorKey: appNavigatorKey,
    source: source,
    isNavigationReady: () => ref.read(isSplashCompletedProvider),
    isAuthenticated: () => ref.read(authStateProvider).valueOrNull != null,
  );
  ref.onDispose(service.dispose);
  return service;
});
