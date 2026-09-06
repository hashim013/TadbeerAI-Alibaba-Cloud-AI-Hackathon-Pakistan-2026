import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadbeerai/core/network/auth_interceptor.dart';

/// [AuthInterceptor] tests over a scripted HTTP adapter — no real network and
/// no Firebase. The injectable `tokenProvider` lets us exercise every branch
/// (token present, null, empty) plus the default Firebase-backed source, which
/// must degrade gracefully to "no header" when Firebase is unavailable.

/// Records the final request headers so the interceptor's Authorization
/// injection can be asserted end-to-end through the real Dio pipeline.
class _RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({'ok': true}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dioWith(AuthInterceptor interceptor, _RecordingAdapter adapter) => Dio(
      BaseOptions(baseUrl: 'http://localhost:9'),
    )
      ..interceptors.add(interceptor)
      ..httpClientAdapter = adapter;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('attaches a Bearer header when a token is available', () async {
    final adapter = _RecordingAdapter();
    final dio =
        _dioWith(AuthInterceptor(tokenProvider: () async => 'abc123'), adapter);

    await dio.get('/v1/finance');

    expect(adapter.requests.single.headers['Authorization'], 'Bearer abc123');
  });

  test('omits the header when signed out (token provider returns null)',
      () async {
    final adapter = _RecordingAdapter();
    final dio =
        _dioWith(AuthInterceptor(tokenProvider: () async => null), adapter);

    await dio.get('/v1/assistant/chat');

    expect(
      adapter.requests.single.headers.containsKey('Authorization'),
      isFalse,
    );
  });

  test('omits the header when the token is empty', () async {
    final adapter = _RecordingAdapter();
    final dio =
        _dioWith(AuthInterceptor(tokenProvider: () async => ''), adapter);

    await dio.get('/v1/economy/snapshot');

    expect(
      adapter.requests.single.headers.containsKey('Authorization'),
      isFalse,
    );
  });

  test('default Firebase source is safe when Firebase is unavailable',
      () async {
    final adapter = _RecordingAdapter();
    // No tokenProvider -> falls back to FirebaseAuth.instance, which is not
    // initialized in unit tests. The guarded provider must return null instead
    // of throwing, so the request still proceeds without an Authorization
    // header (the existing v1 endpoints tolerate that).
    final dio = _dioWith(AuthInterceptor(), adapter);

    await dio.get('/v1/finance');

    expect(adapter.requests, hasLength(1));
    expect(
      adapter.requests.single.headers.containsKey('Authorization'),
      isFalse,
    );
  });
}
