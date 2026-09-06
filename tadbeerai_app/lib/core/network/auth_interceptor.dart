import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Attaches the signed-in user's Firebase ID token to every backend request.
///
/// A single queued interceptor shared by the assistant, economy and the finance
/// ledger so the whole app authenticates consistently. Requests are queued
/// while a token is fetched, which avoids concurrent ID-token refresh races.
///
/// When no user is signed in — or Firebase is unavailable (headless tests) —
/// the request proceeds WITHOUT an `Authorization` header. The existing v1
/// endpoints tolerate that (they don't require auth), and the finance endpoints
/// answer 401, which the offline-first repository handles by staying on its
/// local cache. The token provider is injectable so it can be tested without
/// initializing Firebase.
class AuthInterceptor extends QueuedInterceptorsWrapper {
  AuthInterceptor({Future<String?> Function()? tokenProvider})
      : _tokenProvider = tokenProvider ?? _firebaseIdToken;

  final Future<String?> Function() _tokenProvider;

  /// Default token source: the current Firebase user's ID token, or `null`
  /// when signed out or when Firebase is not initialized. Never throws — an
  /// auth failure must not break otherwise-public requests.
  static Future<String?> _firebaseIdToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      return await user.getIdToken();
    } catch (_) {
      // Firebase not initialized (tests) or token fetch failed — go anonymous.
      return null;
    }
  }

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _tokenProvider();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}
