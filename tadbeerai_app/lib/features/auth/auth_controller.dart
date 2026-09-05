import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/app_user.dart';
import '../../providers/repository_providers.dart';

/// Holds the current session user (null = signed out) and exposes
/// repository-backed auth actions.
class AuthController extends Notifier<AppUser?> {
  String? _lastErrorMessage;

  /// User-friendly error message from the most recent failed auth operation.
  String? get lastErrorMessage => _lastErrorMessage;

  @override
  AppUser? build() => null;

  /// Restores a persisted session, if any. Returns whether a user is
  /// signed in after the attempt.
  Future<bool> restoreSession() async {
    _lastErrorMessage = null;
    state = await ref.read(authRepositoryProvider).currentUser();
    return state != null;
  }

  /// Returns true on success; sets [lastErrorMessage] on failure.
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _lastErrorMessage = null;
    try {
      state = await ref
          .read(authRepositoryProvider)
          .signIn(email: email, password: password);
      return true;
    } catch (e) {
      _lastErrorMessage = e.toString();
      return false;
    }
  }

  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    _lastErrorMessage = null;
    try {
      state = await ref.read(authRepositoryProvider).signUp(
            name: name,
            email: email,
            password: password,
          );
      return true;
    } catch (e) {
      _lastErrorMessage = e.toString();
      return false;
    }
  }

  Future<void> signOut() async {
    _lastErrorMessage = null;
    await ref.read(authRepositoryProvider).signOut();
    state = null;
  }
}

final authControllerProvider = NotifierProvider<AuthController, AppUser?>(
  AuthController.new,
);
