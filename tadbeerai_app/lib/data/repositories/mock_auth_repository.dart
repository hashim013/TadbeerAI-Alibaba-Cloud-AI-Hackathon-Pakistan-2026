import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

/// Local, offline mock authentication used during the UI phase.
///
/// Any syntactically valid credentials succeed; the session is persisted
/// on-device so returning users skip login. This is clearly a demo-mode
/// implementation and is replaced by a remote repository in a later phase.
class MockAuthRepository implements AuthRepository {
  MockAuthRepository(this._prefs);

  final SharedPreferences _prefs;

  @override
  Future<AppUser?> currentUser() async {
    final raw = _prefs.getString(AppConstants.prefSessionUser);
    if (raw == null || raw.isEmpty) return null;
    try {
      return AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Corrupt session — treat as signed out.
      return null;
    }
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    // Simulated latency so loading states are exercised realistically.
    await Future<void>.delayed(AppConstants.mockAuthLatency);
    final user = AppUser(
      id: _localId(email),
      name: _nameFromEmail(email),
      email: email,
    );
    await _persist(user);
    return user;
  }

  @override
  Future<AppUser> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(AppConstants.mockAuthLatency);
    final user = AppUser(id: _localId(email), name: name, email: email);
    await _persist(user);
    return user;
  }

  @override
  Future<void> signOut() => _prefs.remove(AppConstants.prefSessionUser);

  Future<void> _persist(AppUser user) =>
      _prefs.setString(AppConstants.prefSessionUser, jsonEncode(user.toJson()));

  static String _localId(String email) =>
      'local-${email.hashCode.toRadixString(16)}';

  static String _nameFromEmail(String email) {
    final handle = email.split('@').first;
    if (handle.isEmpty) return 'Friend';
    return handle
        .split(RegExp(r'[._\-]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }
}
