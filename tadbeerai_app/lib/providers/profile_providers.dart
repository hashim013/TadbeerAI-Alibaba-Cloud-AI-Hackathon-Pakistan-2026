import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/financial_profile.dart';
import '../domain/repositories/financial_profile_repository.dart';
import 'repository_providers.dart';

/// Loads the stored financial profile (null when none exists yet).
final financialProfileProvider = FutureProvider<FinancialProfile?>((ref) {
  final repo = ref.watch(financialProfileRepositoryProvider);
  return repo.loadProfile();
});

/// Manages save / clear mutations on the financial profile.
class FinancialProfileController extends AsyncNotifier<FinancialProfile?> {
  FinancialProfileRepository get _repo =>
      ref.watch(financialProfileRepositoryProvider);

  @override
  Future<FinancialProfile?> build() => _repo.loadProfile();

  /// Persists [profile] and updates the local state.
  Future<void> saveProfile(FinancialProfile profile) async {
    state = const AsyncLoading();
    try {
      await _repo.saveProfile(profile);
      state = AsyncData(profile);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  /// Removes the stored profile.
  Future<void> clearProfile() async {
    state = const AsyncLoading();
    try {
      await _repo.clearProfile();
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}

final financialProfileControllerProvider =
    AsyncNotifierProvider<FinancialProfileController, FinancialProfile?>(
        FinancialProfileController.new);
