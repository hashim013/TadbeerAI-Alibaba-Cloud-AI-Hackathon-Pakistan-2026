import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/app_user.dart';
import '../../providers/repository_providers.dart';

/// Holds the current session user (null = signed out) and exposes
/// repository-backed auth actions with bulletproof local persistence.
class AuthController extends Notifier<AppUser?> {
  String? _lastErrorMessage;

  /// User-friendly error message from the most recent failed auth operation.
  String? get lastErrorMessage => _lastErrorMessage;

  @override
  AppUser? build() {
    try {
      final prefs = ref.watch(sharedPrefsProvider);
      final raw = prefs.getString(AppConstants.prefSessionUser);
      if (raw != null && raw.isNotEmpty) {
        return AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _persistSession(AppUser user) async {
    try {
      final prefs = ref.read(sharedPrefsProvider);
      await prefs.setString(
        AppConstants.prefSessionUser,
        jsonEncode(user.toJson()),
      );
      await ref.read(settingsRepositoryProvider).completeOnboarding();
    } catch (_) {}
  }

  Future<void> _clearSession() async {
    try {
      final prefs = ref.read(sharedPrefsProvider);
      await prefs.remove(AppConstants.prefSessionUser);
    } catch (_) {}
  }

  /// Restores a persisted session, checking repository and local preferences.
  /// Returns whether a user is authenticated after the attempt.
  Future<bool> restoreSession() async {
    _lastErrorMessage = null;
    try {
      final repoUser = await ref.read(authRepositoryProvider).currentUser();
      if (repoUser != null) {
        state = repoUser;
        await _persistSession(repoUser);
        return true;
      }
    } catch (_) {}

    try {
      final prefs = ref.read(sharedPrefsProvider);
      final raw = prefs.getString(AppConstants.prefSessionUser);
      if (raw != null && raw.isNotEmpty) {
        final cached =
            AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        state = cached;
        return true;
      }
    } catch (_) {}

    state = null;
    return false;
  }

  /// Returns true on success; sets [lastErrorMessage] on failure.
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _lastErrorMessage = null;
    try {
      final user = await ref
          .read(authRepositoryProvider)
          .signIn(email: email, password: password);
      state = user;
      await _persistSession(user);
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
      final user = await ref.read(authRepositoryProvider).signUp(
            name: name,
            email: email,
            password: password,
          );
      state = user;
      await _persistSession(user);
      return true;
    } catch (e) {
      _lastErrorMessage = e.toString();
      return false;
    }
  }

  Future<bool> signInAsGuest() async {
    _lastErrorMessage = null;
    try {
      final user = await ref.read(authRepositoryProvider).signInAsGuest();
      state = user;
      await _persistSession(user);
      return true;
    } catch (e) {
      _lastErrorMessage = e.toString();
      return false;
    }
  }

  Future<bool> signInWithGoogle({String? email, String? name}) async {
    _lastErrorMessage = null;
    try {
      final user = await ref.read(authRepositoryProvider).signInWithGoogle(
            email: email,
            name: name,
          );
      if (user == null) {
        // User cancelled - return false without setting error message
        return false;
      }
      state = user;
      await _persistSession(user);
      return true;
    } catch (e) {
      _lastErrorMessage = e.toString();
      return false;
    }
  }

  Future<bool> sendPasswordResetCode(String email) async {
    _lastErrorMessage = null;
    try {
      await ref
          .read(authRepositoryProvider)
          .sendPasswordResetCode(email: email);
      return true;
    } catch (e) {
      _lastErrorMessage = e.toString();
      return false;
    }
  }

  Future<bool> resetPasswordWithCode({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    _lastErrorMessage = null;
    try {
      final success =
          await ref.read(authRepositoryProvider).resetPasswordWithCode(
                email: email,
                code: code,
                newPassword: newPassword,
              );
      if (!success) {
        _lastErrorMessage = 'Invalid or expired verification code.';
      }
      return success;
    } catch (e) {
      _lastErrorMessage = e.toString();
      return false;
    }
  }

  void updateUserName(String newName) {
    if (state != null && newName.trim().isNotEmpty) {
      state = state!.copyWith(name: newName.trim());
      _persistSession(state!);
    }
  }

  void updateUserProfile({String? name, String? phone, String? photoUrl}) {
    if (state != null) {
      state = state!.copyWith(
        name: (name != null && name.trim().isNotEmpty)
            ? name.trim()
            : state!.name,
        phone: phone != null ? phone.trim() : state!.phone,
        photoUrl: photoUrl != null ? photoUrl.trim() : state!.photoUrl,
      );
      _persistSession(state!);
    }
  }

  Future<void> signOut() async {
    _lastErrorMessage = null;
    await _clearSession();
    await ref.read(authRepositoryProvider).signOut();
    state = null;
  }
}

final authControllerProvider = NotifierProvider<AuthController, AppUser?>(
  AuthController.new,
);
