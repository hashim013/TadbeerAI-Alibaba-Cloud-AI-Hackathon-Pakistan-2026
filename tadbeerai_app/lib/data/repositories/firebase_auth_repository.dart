import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../domain/entities/app_user.dart';
import '../../domain/exceptions/auth_exception.dart';
import '../../domain/repositories/auth_repository.dart';

/// Firebase Authentication implementation of [AuthRepository].
///
/// Wraps official [fb.FirebaseAuth] SDK, translates all Firebase error codes
/// into user-friendly [AuthException] instances, and maps Firebase [fb.User]
/// instances into domain [AppUser] records.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({fb.FirebaseAuth? firebaseAuth})
      : _firebaseAuth = firebaseAuth ?? fb.FirebaseAuth.instance;

  final fb.FirebaseAuth _firebaseAuth;

  @override
  Future<AppUser?> currentUser() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;
    return _toAppUser(user);
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthException(
          message: 'Email or password is incorrect.',
          code: 'invalid_credentials',
        );
      }
      return _toAppUser(user);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException.fromFirebaseCode(e.code);
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException(
        message: 'Something went wrong. Please try again.',
        code: 'unknown_error',
      );
    }
  }

  @override
  Future<AppUser> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthException(
          message: 'Something went wrong. Please try again.',
          code: 'unknown_error',
        );
      }
      try {
        await user.updateDisplayName(name.trim());
      } catch (_) {
        // Non-critical: continue if display name update fails
      }
      return AppUser(
        id: user.uid,
        name: name.trim().isNotEmpty ? name.trim() : _nameFromEmail(email),
        email: user.email ?? email.trim(),
      );
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException.fromFirebaseCode(e.code);
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException(
        message: 'Something went wrong. Please try again.',
        code: 'unknown_error',
      );
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } catch (_) {
      // Degrade gracefully
    }
  }

  AppUser _toAppUser(fb.User user) {
    final displayName = user.displayName?.trim();
    final name = (displayName != null && displayName.isNotEmpty)
        ? displayName
        : _nameFromEmail(user.email ?? '');
    return AppUser(
      id: user.uid,
      name: name,
      email: user.email ?? '',
    );
  }

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
