import '../entities/app_user.dart';

/// Authentication contract.
///
/// The UI phase ships a local mock implementation; a Firebase-backed
/// implementation replaces it in a later phase without touching UI code.
abstract interface class AuthRepository {
  /// Returns the persisted session user, or null when signed out.
  Future<AppUser?> currentUser();

  Future<AppUser> signIn({
    required String email,
    required String password,
  });

  Future<AppUser> signUp({
    required String name,
    required String email,
    required String password,
  });

  Future<void> signOut();
}
