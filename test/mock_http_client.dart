import 'dart:io';
import 'dart:async';

class MockHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _MockHttpClient();
  }
}

class _MockHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    return _MockHttpClientRequest();
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    return _MockHttpClientRequest();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return null;
  }
}

class _MockHttpClientRequest implements HttpClientRequest {
  @override
  final HttpHeaders headers = _MockHttpHeaders();

  @override
  Future<HttpClientResponse> close() async {
    return _MockHttpClientResponse();
  }

  @override
  Future<HttpClientResponse> get done async => _MockHttpClientResponse();

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return null;
  }
}

class _MockHttpHeaders implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    return null;
  }
}

class _MockHttpClientResponse extends Stream<List<int>> implements HttpClientResponse {
  static final List<int> _dummyGif = [
    0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x01, 0x00, 0x01, 0x00, 0x80, 0x00,
    0x00, 0x00, 0x00, 0x00, 0xff, 0xff, 0xff, 0x21, 0xf9, 0x04, 0x01, 0x00,
    0x00, 0x00, 0x00, 0x2c, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00,
    0x00, 0x02, 0x02, 0x4c, 0x01, 0x00, 0x3b
  ];

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_dummyGif]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  int get statusCode => 200;

  @override
  int get contentLength => _dummyGif.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  final HttpHeaders headers = _MockHttpHeaders();

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return null;
  }
}
