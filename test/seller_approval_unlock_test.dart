import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teknoycart/features/auth/models/profile.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/features/auth/services/auth_service.dart';
import 'package:teknoycart/features/feed/views/tabs/sell_tab.dart';

import 'mock_http_client.dart';
import 'support/test_harness.dart';

class _StubHttpResponse {
  final int statusCode;
  final String body;
  const _StubHttpResponse(this.statusCode, this.body);
}

class _RoutingMockHttpOverrides extends MockHttpOverrides {
  _StubHttpResponse Function(String method, Uri url)? resolver;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _RoutingMockHttpClient(this);
  }
}

class _RoutingMockHttpClient implements HttpClient {
  _RoutingMockHttpClient(this.overrides);

  final _RoutingMockHttpOverrides overrides;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    overrides.requestedPaths.add('$method ${url.path}');
    return _RoutingMockHttpClientRequest(method, url, overrides);
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    overrides.requestedPaths.add('GET ${url.path}');
    return _RoutingMockHttpClientRequest('GET', url, overrides);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _RoutingMockHttpClientRequest implements HttpClientRequest {
  _RoutingMockHttpClientRequest(this.method, this.url, this.overrides);

  @override
  final String method;
  final Uri url;
  final _RoutingMockHttpOverrides overrides;

  @override
  late final HttpHeaders headers = _RoutingMockHttpHeaders();

  @override
  List<Cookie> get cookies => const [];

  @override
  void add(List<int> data) {}

  @override
  void write(Object? obj) {}

  @override
  Future addStream(Stream<List<int>> stream) async {}

  @override
  Future flush() async {}

  @override
  Future<HttpClientResponse> close() async {
    final stub = overrides.resolver?.call(method, url) ??
        const _StubHttpResponse(200, '[]');
    return _RoutingMockHttpClientResponse(stub);
  }

  @override
  Future<HttpClientResponse> get done => close();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _RoutingMockHttpHeaders implements HttpHeaders {
  Iterable<String> get keys => const ['content-type'];

  @override
  List<String>? operator [](String name) {
    if (name.toLowerCase() == 'content-type') {
      return const ['application/json; charset=utf-8'];
    }
    return null;
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _RoutingMockHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _RoutingMockHttpClientResponse(this.stub);

  final _StubHttpResponse stub;

  @override
  int get statusCode => stub.statusCode;

  @override
  String get reasonPhrase => stub.statusCode >= 400 ? 'Error' : 'OK';

  List<int> get _bytes => utf8.encode(stub.body);

  @override
  int get contentLength => _bytes.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  bool get persistentConnection => true;

  @override
  bool get isRedirect => false;

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  List<Cookie> get cookies => const [];

  @override
  late final HttpHeaders headers = _RoutingMockHttpHeaders();

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_bytes]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _ControllableAuthService extends AuthService {
  _ControllableAuthService(this._current);

  Profile? _current;
  final StreamController<Profile?> controller =
      StreamController<Profile?>.broadcast();

  @override
  Profile? get currentUser => _current;

  @override
  Stream<Profile?> get authStateChanges => controller.stream;

  void emitAuthChange(Profile? next) {
    _current = next;
    controller.add(next);
  }

  @override
  void dispose() {
    controller.close();
  }
}

void main() {
  late _RoutingMockHttpOverrides httpOverrides;

  setUpAll(() async {
    httpOverrides = _RoutingMockHttpOverrides();
    await TestHarness.setUpAllEnvironment(customHttpOverrides: httpOverrides);
  });

  setUp(() {
    httpOverrides.requestedPaths.clear();
    httpOverrides.resolver = null;
  });

  group('Seller approval unlock regression tests', () {
    test(
      'getEnrichedProfile resolves approved seller when my_profile RPC errors',
      () async {
        httpOverrides.resolver = (method, url) {
          if (url.path.endsWith('/rest/v1/rpc/my_profile')) {
            return const _StubHttpResponse(
              404,
              '{"message":"Could not find function public.my_profile","code":"PGRST202"}',
            );
          }
          if (url.path.endsWith('/rest/v1/users')) {
            return const _StubHttpResponse(
              200,
              '{"user_id":"u-err-1","full_name":"Clarence M","role":"SELLER","is_seller_verified":true}',
            );
          }
          return const _StubHttpResponse(200, '[]');
        };

        final stale = Profile(
          id: 'u-err-1',
          username: 'clarence',
          email: 'clarence@cit.edu',
          role: 'BUYER',
          isSellerVerified: false,
          createdAt: DateTime(2026),
        );

        final enriched = await AuthService().getEnrichedProfile(stale);
        expect(enriched.role, equals('SELLER'));
        expect(enriched.isSellerVerified, isTrue);
        expect(enriched.isSeller, isTrue);
        expect(enriched.username, equals('Clarence M'));
      },
    );

    test(
      'getEnrichedProfile falls back to my_profile view when my_profile RPC errors',
      () async {
        httpOverrides.resolver = (method, url) {
          if (url.path.endsWith('/rest/v1/rpc/my_profile')) {
            return const _StubHttpResponse(
              404,
              '{"message":"Could not find function public.my_profile","code":"PGRST202"}',
            );
          }
          if (url.path.endsWith('/rest/v1/my_profile')) {
            return const _StubHttpResponse(
              200,
              '{"full_name":"Clarence View","email":"clarence@cit.edu","role":"SELLER","is_seller_verified":true,"student_id":"22-1234-567","contact":"09171234567","gcash_number":"09171234567","seller_type":"STUDENT"}',
            );
          }
          return const _StubHttpResponse(200, '[]');
        };

        final stale = Profile(
          id: 'u-view-1',
          username: 'clarence',
          email: 'clarence@cit.edu',
          role: 'BUYER',
          isSellerVerified: false,
          createdAt: DateTime(2026),
        );

        final enriched = await AuthService().getEnrichedProfile(stale);
        expect(enriched.role, equals('SELLER'));
        expect(enriched.isSellerVerified, isTrue);
        expect(enriched.isSeller, isTrue);
        expect(enriched.username, equals('Clarence View'));
        expect(enriched.studentId, equals('22-1234-567'));
        expect(enriched.contact, equals('09171234567'));
        expect(enriched.gcashNumber, equals('09171234567'));
      },
    );

    test(
      'getEnrichedProfile falls back to seller_verifications APPROVED when my_profile returns []',
      () async {
        httpOverrides.resolver = (method, url) {
          if (url.path.endsWith('/rest/v1/rpc/my_profile')) {
            return const _StubHttpResponse(200, '[]');
          }
          if (url.path.endsWith('/rest/v1/users')) {
            return const _StubHttpResponse(
              200,
              '{"user_id":"u-empty-1","full_name":"Clarence M","role":"BUYER","is_seller_verified":false}',
            );
          }
          if (url.path.endsWith('/rest/v1/seller_verifications')) {
            return const _StubHttpResponse(
              200,
              '{"status":"approved","seller_type":"STUDENT"}',
            );
          }
          if (url.path.endsWith('/rest/v1/store_profiles')) {
            return const _StubHttpResponse(
              200,
              '{"store_name":"Wildcat Supplies"}',
            );
          }
          return const _StubHttpResponse(200, '[]');
        };

        final stale = Profile(
          id: 'u-empty-1',
          username: 'clarence',
          email: 'clarence@cit.edu',
          role: 'BUYER',
          isSellerVerified: false,
          createdAt: DateTime(2026),
        );

        final enriched = await AuthService().getEnrichedProfile(stale);
        expect(enriched.role, equals('SELLER'));
        expect(enriched.isSellerVerified, isTrue);
        expect(enriched.isSeller, isTrue);
        expect(enriched.sellerType, equals('STUDENT'));
        expect(enriched.storeName, equals('Wildcat Supplies'));
      },
    );

    test(
      'getEnrichedProfile accepts single Map response from my_profile RPC',
      () async {
        httpOverrides.resolver = (method, url) {
          if (url.path.endsWith('/rest/v1/rpc/my_profile')) {
            return const _StubHttpResponse(
              200,
              '{"user_id":"u-map-1","full_name":"Org Store","email":"org@gmail.com","role":"SELLER","is_seller_verified":true,"seller_type":"ORG"}',
            );
          }
          return const _StubHttpResponse(200, '[]');
        };

        final stale = Profile(
          id: 'u-map-1',
          username: 'org',
          email: '',
          role: 'BUYER',
          isSellerVerified: false,
          createdAt: DateTime(2026),
        );

        final enriched = await AuthService().getEnrichedProfile(stale);
        expect(enriched.role, equals('SELLER'));
        expect(enriched.isSellerVerified, isTrue);
        expect(enriched.isSeller, isTrue);
        expect(enriched.email, equals('org@gmail.com'));
        expect(enriched.sellerType, equals('ORG'));
      },
    );

    test(
      'AuthNotifier preserves verified seller state across tokenRefreshed auth emission when refresh fails',
      () async {
        var allowEnrichSuccess = true;
        httpOverrides.resolver = (method, url) {
          if (!allowEnrichSuccess) {
            return const _StubHttpResponse(
              500,
              '{"message":"temporary failure"}',
            );
          }
          if (url.path.endsWith('/rest/v1/rpc/my_profile')) {
            return const _StubHttpResponse(
              200,
              '[{"user_id":"u-refresh-1","full_name":"Clarence","role":"SELLER","is_seller_verified":true,"seller_type":"STUDENT"}]',
            );
          }
          return const _StubHttpResponse(200, '[]');
        };

        final staleMeta = Profile(
          id: 'u-refresh-1',
          username: 'clarence',
          email: 'clarence@cit.edu',
          role: 'BUYER',
          isSellerVerified: false,
          createdAt: DateTime(2026),
        );

        final service = _ControllableAuthService(staleMeta);
        final container = ProviderContainer(
          overrides: [
            authServiceProvider.overrideWithValue(service),
          ],
        );
        addTearDown(container.dispose);

        // Initial enrichment promotes user to verified seller.
        container.read(authNotifierProvider);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(
          container.read(authStateProvider).valueOrNull?.isSeller,
          isTrue,
        );

        // Simulate tokenRefreshed emitting un-enriched auth metadata while backend temporarily errors.
        allowEnrichSuccess = false;
        service.emitAuthChange(staleMeta);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final afterRefresh = container.read(authStateProvider).valueOrNull;
        expect(afterRefresh?.isSeller, isTrue);
        expect(afterRefresh?.isSellerVerified, isTrue);
        expect(afterRefresh?.role, equals('SELLER'));
      },
    );

    testWidgets(
      'SellTab unlocks from Seller Account Approved to List New Item on Open Seller Hub tap even when my_profile RPC returns empty',
      (tester) async {
        var authEnrichShouldFail = true;
        var verifSelectCalls = 0;

        httpOverrides.resolver = (method, url) {
          if (url.path.endsWith('/rest/v1/rpc/my_profile')) {
            return const _StubHttpResponse(200, '[]');
          }
          if (url.path.endsWith('/rest/v1/users')) {
            if (authEnrichShouldFail) {
              return const _StubHttpResponse(500, '{"message":"transient"}');
            }
            return const _StubHttpResponse(
              200,
              '{"user_id":"u-widget-unlock-1","full_name":"Clarence","role":"SELLER","is_seller_verified":true}',
            );
          }
          if (url.path.endsWith('/rest/v1/seller_verifications')) {
            verifSelectCalls++;
            final selectParam = url.queryParameters['select'] ?? '';
            // AuthService queries 'status, seller_type'; SellerVerificationService queries '*'.
            if (authEnrichShouldFail && selectParam.startsWith('status')) {
              return const _StubHttpResponse(500, '{"message":"transient"}');
            }
            return const _StubHttpResponse(
              200,
              '{"id":"verif-unlock-1","user_id":"u-widget-unlock-1","seller_type":"STUDENT","id_card_url":"https://example.com/id.jpg","selfie_url":"https://example.com/selfie.jpg","id_card_storage_path":"kyc/u/id.jpg","selfie_storage_path":"kyc/u/selfie.jpg","status":"APPROVED","rejection_reason":null,"created_at":"2026-11-11T00:00:00Z"}',
            );
          }
          return const _StubHttpResponse(200, '[]');
        };

        final staleUser = Profile(
          id: 'u-widget-unlock-1',
          username: 'clarence',
          email: 'clarence@cit.edu',
          role: 'BUYER',
          isSellerVerified: false,
          createdAt: DateTime(2026),
        );
        final service = _ControllableAuthService(staleUser);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authServiceProvider.overrideWithValue(service),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: SellTab(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Seller Account Approved'), findsOneWidget);
        expect(find.text('Open Seller Hub'), findsOneWidget);
        expect(verifSelectCalls, greaterThan(0));

        // While backend refresh fails, tapping Open Seller Hub surfaces sync feedback.
        await tester.tap(find.text('Open Seller Hub'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('seller status is still syncing'),
          findsOneWidget,
        );

        // Once backend queries succeed, tapping Open Seller Hub unlocks SellTab while my_profile RPC still returns [].
        authEnrichShouldFail = false;
        await tester.tap(find.text('Open Seller Hub'));
        await tester.pumpAndSettle();

        expect(find.text('Seller Account Approved'), findsNothing);
        expect(find.text('List New Item'), findsOneWidget);

        // Unmount and flush any realtime client timers cleanly.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 60));
      },
    );
  });
}

