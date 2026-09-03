import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/app_user.dart';
import '../../providers/repository_providers.dart';

/// Holds the current session user (null = signed out) and exposes
/// repository-backed auth actions.
class AuthController extends Notifier<AppUser?> {
  @override
  AppUser? build() => null;

  /// Restores a persisted session, if any. Returns whether a user is
  /// signed in after the attempt.
  Future<bool> restoreSession() async {
    state = await ref.read(authRepositoryProvider).currentUser();
    return state != null;
  }

  /// Returns true on success; the calling screen shows a localized
  /// generic error otherwise.
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    try {
      state = await ref
          .read(authRepositoryProvider)
          .signIn(email: email, password: password);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      state = await ref.read(authRepositoryProvider).signUp(
            name: name,
            email: email,
            password: password,
          );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = null;
  }
}

final authControllerProvider = NotifierProvider<AuthController, AppUser?>(
  AuthController.new,
);
