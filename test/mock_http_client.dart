import 'dart:io';
import 'dart:async';
import 'dart:convert';

class MockHttpOverrides extends HttpOverrides {
  /// Optional JSON body served for every Supabase request instead of the
  /// default dummy payload — lets tests inject realistic fixture rows.
  /// Mutable because the Supabase test client caches its HttpClient across
  /// the whole file, so a test re-targets the body instead of rebuilding the
  /// client.
  String? supabaseBody;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _MockHttpClient(this);
  }
}

class _MockHttpClient implements HttpClient {
  _MockHttpClient(this.overrides);

  final MockHttpOverrides overrides;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    return _MockHttpClientRequest(url, overrides);
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    return _MockHttpClientRequest(url, overrides);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return null;
  }
}

class _MockHttpClientRequest implements HttpClientRequest {
  final Uri url;
  final MockHttpOverrides overrides;
  _MockHttpClientRequest(this.url, this.overrides);

  @override
  late final HttpHeaders headers = _MockHttpHeaders(url);

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
    return _MockHttpClientResponse(url, overrides);
  }

  @override
  Future<HttpClientResponse> get done async => _MockHttpClientResponse(url, overrides);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return null;
  }
}

class _MockHttpHeaders implements HttpHeaders {
  final Uri url;
  _MockHttpHeaders(this.url);

  bool get _isSupabase => url.host.contains('supabase.co') || url.path.contains('api/');

  Iterable<String> get keys => _isSupabase ? const ['content-type'] : const [];

  @override
  List<String>? operator [](String name) {
    if (_isSupabase && name.toLowerCase() == 'content-type') {
      return const ['application/json; charset=utf-8'];
    }
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return null;
  }
}

class _MockHttpClientResponse extends Stream<List<int>> implements HttpClientResponse {
  final Uri url;
  final MockHttpOverrides overrides;
  _MockHttpClientResponse(this.url, this.overrides);

  bool get _isSupabase => url.host.contains('supabase.co') || url.path.contains('api/');

  static final List<int> _dummyGif = [
    0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x01, 0x00, 0x01, 0x00, 0x80, 0x00,
    0x00, 0x00, 0x00, 0x00, 0xff, 0xff, 0xff, 0x21, 0xf9, 0x04, 0x01, 0x00,
    0x00, 0x00, 0x00, 0x2c, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00,
    0x00, 0x02, 0x02, 0x4c, 0x01, 0x00, 0x3b
  ];

  static final List<int> _dummyJson = utf8.encode('[{"inquiry_id": "mock-inquiry-123", "id": "mock-id-123", "variant_id": "mock-variant-123"}]');

  List<int> get _bodyBytes {
    if (!_isSupabase) return _dummyGif;
    final body = overrides.supabaseBody;
    if (body != null) return utf8.encode(body);
    if (url.path.contains('place_orders_atomic')) {
      return utf8.encode('{"success": true, "orders": [{"line_index": 0, "order_id": "mock-order-123"}]}');
    }
    return _dummyJson;
  }

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final bytes = _bodyBytes;
    return Stream<List<int>>.fromIterable([bytes]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  int get statusCode => 200;

  @override
  int get contentLength => _bodyBytes.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  bool get persistentConnection => true;

  @override
  bool get isRedirect => false;

  @override
  String get reasonPhrase => 'OK';

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  List<Cookie> get cookies => const [];

  @override
  late final HttpHeaders headers = _MockHttpHeaders(url);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return null;
  }
}
