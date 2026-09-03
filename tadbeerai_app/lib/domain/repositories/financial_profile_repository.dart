import '../entities/financial_profile.dart';

/// Repository contract for the user's financial profile.
///
/// The profile is a single device-level record. Implementations may back it
/// with SharedPreferences (current), a local database, or a remote API —
/// consumers only depend on this interface.
abstract interface class FinancialProfileRepository {
  /// Loads the stored profile, or `null` when none has been saved yet.
  Future<FinancialProfile?> loadProfile();

  /// Persists the given profile. Replaces any previously stored profile.
  Future<void> saveProfile(FinancialProfile profile);

  /// Removes the stored profile entirely.
  Future<void> clearProfile();
}
