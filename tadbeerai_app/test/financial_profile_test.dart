import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tadbeerai/data/repositories/prefs_financial_profile_repository.dart';
import 'package:tadbeerai/domain/entities/financial_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── Persona enum ──────────────────────────────────────────────────────
  group('Persona', () {
    test('storageKey matches enum name', () {
      expect(Persona.student.storageKey, 'student');
      expect(Persona.salaried.storageKey, 'salaried');
      expect(Persona.businessOwner.storageKey, 'businessOwner');
      expect(Persona.shopOwner.storageKey, 'shopOwner');
    });

    test('fromStorageKey round-trips every value', () {
      for (final persona in Persona.values) {
        expect(Persona.fromStorageKey(persona.storageKey), persona);
      }
    });

    test('fromStorageKey returns null for null', () {
      expect(Persona.fromStorageKey(null), isNull);
    });

    test('fromStorageKey returns null for unknown key', () {
      expect(Persona.fromStorageKey('unknown'), isNull);
      expect(Persona.fromStorageKey(''), isNull);
    });

    test('has exactly 4 personas', () {
      expect(Persona.values, hasLength(4));
    });
  });

  // ── PrimaryGoal enum ──────────────────────────────────────────────────
  group('PrimaryGoal', () {
    test('storageKey matches enum name', () {
      expect(PrimaryGoal.emergencyFund.storageKey, 'emergencyFund');
      expect(PrimaryGoal.saveMore.storageKey, 'saveMore');
      expect(PrimaryGoal.education.storageKey, 'education');
      expect(PrimaryGoal.newDevice.storageKey, 'newDevice');
      expect(PrimaryGoal.businessGrowth.storageKey, 'businessGrowth');
      expect(PrimaryGoal.reduceSpending.storageKey, 'reduceSpending');
      expect(PrimaryGoal.other.storageKey, 'other');
    });

    test('fromStorageKey round-trips every value', () {
      for (final goal in PrimaryGoal.values) {
        expect(PrimaryGoal.fromStorageKey(goal.storageKey), goal);
      }
    });

    test('fromStorageKey returns null for null', () {
      expect(PrimaryGoal.fromStorageKey(null), isNull);
    });

    test('fromStorageKey returns null for unknown key', () {
      expect(PrimaryGoal.fromStorageKey('unknown'), isNull);
    });

    test('has exactly 7 goals', () {
      expect(PrimaryGoal.values, hasLength(7));
    });
  });

  // ── FinancialProfile entity ───────────────────────────────────────────
  group('FinancialProfile', () {
    test('default constructor has null fields and completed=false', () {
      const profile = FinancialProfile();

      expect(profile.persona, isNull);
      expect(profile.monthlyIncome, isNull);
      expect(profile.monthlyEssentialExpenses, isNull);
      expect(profile.primaryGoal, isNull);
      expect(profile.profileCompleted, isFalse);
    });

    test('full constructor stores all fields', () {
      const profile = FinancialProfile(
        persona: Persona.salaried,
        monthlyIncome: 80000,
        monthlyEssentialExpenses: 55000,
        primaryGoal: PrimaryGoal.emergencyFund,
        profileCompleted: true,
      );

      expect(profile.persona, Persona.salaried);
      expect(profile.monthlyIncome, 80000);
      expect(profile.monthlyEssentialExpenses, 55000);
      expect(profile.primaryGoal, PrimaryGoal.emergencyFund);
      expect(profile.profileCompleted, isTrue);
    });

    test('toJson produces expected map', () {
      const profile = FinancialProfile(
        persona: Persona.student,
        monthlyIncome: 0,
        monthlyEssentialExpenses: 5000,
        primaryGoal: PrimaryGoal.education,
        profileCompleted: true,
      );

      final json = profile.toJson();

      expect(json['persona'], 'student');
      expect(json['monthlyIncome'], 0);
      expect(json['monthlyEssentialExpenses'], 5000);
      expect(json['primaryGoal'], 'education');
      expect(json['profileCompleted'], true);
    });

    test('toJson handles null fields gracefully', () {
      const profile = FinancialProfile();
      final json = profile.toJson();

      expect(json['persona'], isNull);
      expect(json['monthlyIncome'], isNull);
      expect(json['monthlyEssentialExpenses'], isNull);
      expect(json['primaryGoal'], isNull);
      expect(json['profileCompleted'], false);
    });

    test('fromJson round-trips a complete profile', () {
      const original = FinancialProfile(
        persona: Persona.businessOwner,
        monthlyIncome: 250000,
        monthlyEssentialExpenses: 120000,
        primaryGoal: PrimaryGoal.businessGrowth,
        profileCompleted: true,
      );

      final restored = FinancialProfile.fromJson(original.toJson());

      expect(restored, original);
    });

    test('fromJson round-trips an empty profile', () {
      const original = FinancialProfile();
      final restored = FinancialProfile.fromJson(original.toJson());

      expect(restored, original);
    });

    test('fromJson handles missing keys gracefully', () {
      final restored = FinancialProfile.fromJson(<String, dynamic>{});

      expect(restored.persona, isNull);
      expect(restored.monthlyIncome, isNull);
      expect(restored.monthlyEssentialExpenses, isNull);
      expect(restored.primaryGoal, isNull);
      expect(restored.profileCompleted, isFalse);
    });

    test('fromJson tolerates unknown enum keys', () {
      final json = {
        'persona': 'futurePersona',
        'monthlyIncome': 10000,
        'monthlyEssentialExpenses': 8000,
        'primaryGoal': 'futureGoal',
        'profileCompleted': true,
      };

      final profile = FinancialProfile.fromJson(json);

      expect(profile.persona, isNull);
      expect(profile.primaryGoal, isNull);
      expect(profile.monthlyIncome, 10000);
      expect(profile.profileCompleted, isTrue);
    });

    test('equality: identical profiles are equal', () {
      const a = FinancialProfile(
        persona: Persona.salaried,
        monthlyIncome: 80000,
        monthlyEssentialExpenses: 55000,
        primaryGoal: PrimaryGoal.saveMore,
        profileCompleted: true,
      );
      const b = FinancialProfile(
        persona: Persona.salaried,
        monthlyIncome: 80000,
        monthlyEssentialExpenses: 55000,
        primaryGoal: PrimaryGoal.saveMore,
        profileCompleted: true,
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('equality: different profiles are not equal', () {
      const a = FinancialProfile(
        persona: Persona.salaried,
        monthlyIncome: 80000,
      );
      const b = FinancialProfile(
        persona: Persona.shopOwner,
        monthlyIncome: 80000,
      );

      expect(a, isNot(b));
    });

    test('copyWith replaces specified fields only', () {
      const original = FinancialProfile(
        persona: Persona.student,
        monthlyIncome: 0,
        monthlyEssentialExpenses: 5000,
        primaryGoal: PrimaryGoal.education,
      );

      final updated = original.copyWith(
        persona: Persona.salaried,
        monthlyIncome: 60000,
        profileCompleted: true,
      );

      // Changed fields.
      expect(updated.persona, Persona.salaried);
      expect(updated.monthlyIncome, 60000);
      expect(updated.profileCompleted, isTrue);

      // Preserved fields.
      expect(updated.monthlyEssentialExpenses, 5000);
      expect(updated.primaryGoal, PrimaryGoal.education);
    });

    test('copyWith preserves fields when no args given', () {
      const original = FinancialProfile(
        persona: Persona.shopOwner,
        monthlyIncome: 150000,
        monthlyEssentialExpenses: 80000,
        primaryGoal: PrimaryGoal.businessGrowth,
        profileCompleted: true,
      );

      final copy = original.copyWith();
      expect(copy, original);
    });

    test('toString contains useful debug info', () {
      const profile = FinancialProfile(
        persona: Persona.salaried,
        monthlyIncome: 80000,
        monthlyEssentialExpenses: 55000,
        primaryGoal: PrimaryGoal.emergencyFund,
        profileCompleted: true,
      );

      final s = profile.toString();
      expect(s, contains('salaried'));
      expect(s, contains('80000'));
      expect(s, contains('emergencyFund'));
    });
  });

  // ── Validation scenarios ──────────────────────────────────────────────
  group('Validation', () {
    test('zero income is a valid profile (student)', () {
      const profile = FinancialProfile(
        persona: Persona.student,
        monthlyIncome: 0,
        monthlyEssentialExpenses: 0,
        primaryGoal: PrimaryGoal.education,
        profileCompleted: true,
      );

      // Round-trip preserves zero values.
      final restored = FinancialProfile.fromJson(profile.toJson());
      expect(restored.monthlyIncome, 0);
      expect(restored.monthlyEssentialExpenses, 0);
      expect(restored.profileCompleted, isTrue);
    });

    test('expenses exceeding income are allowed (financial pressure)', () {
      const profile = FinancialProfile(
        persona: Persona.salaried,
        monthlyIncome: 40000,
        monthlyEssentialExpenses: 55000,
        primaryGoal: PrimaryGoal.reduceSpending,
        profileCompleted: true,
      );

      final restored = FinancialProfile.fromJson(profile.toJson());
      expect(restored.monthlyIncome, 40000);
      expect(restored.monthlyEssentialExpenses, 55000);

      // The surplus is negative — real financial pressure.
      final surplus =
          restored.monthlyIncome! - restored.monthlyEssentialExpenses!;
      expect(surplus, isNegative);
    });

    test('large income and expenses are handled', () {
      const profile = FinancialProfile(
        persona: Persona.businessOwner,
        monthlyIncome: 5000000,
        monthlyEssentialExpenses: 3200000,
        primaryGoal: PrimaryGoal.businessGrowth,
        profileCompleted: true,
      );

      final restored = FinancialProfile.fromJson(profile.toJson());
      expect(restored.monthlyIncome, 5000000);
      expect(restored.monthlyEssentialExpenses, 3200000);
    });

    test('JSON round-trip preserves integer values as doubles', () {
      // SharedPreferences may persist int where double is expected.
      final json = {
        'persona': 'salaried',
        'monthlyIncome': 80000,
        'monthlyEssentialExpenses': 55000,
        'primaryGoal': 'saveMore',
        'profileCompleted': true,
      };

      final profile = FinancialProfile.fromJson(json);
      expect(profile.monthlyIncome, isA<double>());
      expect(profile.monthlyIncome, 80000.0);
    });
  });

  // ── PrefsFinancialProfileRepository ───────────────────────────────────
  group('PrefsFinancialProfileRepository', () {
    test('loadProfile returns null when nothing is saved', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = PrefsFinancialProfileRepository(prefs);

      expect(await repo.loadProfile(), isNull);
    });

    test('saveProfile then loadProfile round-trips', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = PrefsFinancialProfileRepository(prefs);

      const profile = FinancialProfile(
        persona: Persona.salaried,
        monthlyIncome: 80000,
        monthlyEssentialExpenses: 55000,
        primaryGoal: PrimaryGoal.emergencyFund,
        profileCompleted: true,
      );

      await repo.saveProfile(profile);
      final loaded = await repo.loadProfile();

      expect(loaded, profile);
    });

    test('saveProfile overwrites previous profile', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = PrefsFinancialProfileRepository(prefs);

      const first = FinancialProfile(
        persona: Persona.student,
        monthlyIncome: 0,
        monthlyEssentialExpenses: 3000,
        primaryGoal: PrimaryGoal.education,
        profileCompleted: true,
      );
      const second = FinancialProfile(
        persona: Persona.salaried,
        monthlyIncome: 90000,
        monthlyEssentialExpenses: 60000,
        primaryGoal: PrimaryGoal.saveMore,
        profileCompleted: true,
      );

      await repo.saveProfile(first);
      await repo.saveProfile(second);
      final loaded = await repo.loadProfile();

      expect(loaded, second);
      expect(loaded?.persona, Persona.salaried);
    });

    test('clearProfile removes stored data', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = PrefsFinancialProfileRepository(prefs);

      const profile = FinancialProfile(
        persona: Persona.shopOwner,
        monthlyIncome: 120000,
        monthlyEssentialExpenses: 80000,
        primaryGoal: PrimaryGoal.businessGrowth,
        profileCompleted: true,
      );

      await repo.saveProfile(profile);
      expect(await repo.loadProfile(), isNotNull);

      await repo.clearProfile();
      expect(await repo.loadProfile(), isNull);
    });

    test('corrupt persisted data is treated as no profile', () async {
      SharedPreferences.setMockInitialValues({
        'financial_profile_v1': '{not valid json',
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = PrefsFinancialProfileRepository(prefs);

      expect(await repo.loadProfile(), isNull);
    });

    test('profile survives a new repository instance (persistence)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final repo1 = PrefsFinancialProfileRepository(prefs);
      const profile = FinancialProfile(
        persona: Persona.salaried,
        monthlyIncome: 80000,
        monthlyEssentialExpenses: 55000,
        primaryGoal: PrimaryGoal.emergencyFund,
        profileCompleted: true,
      );
      await repo1.saveProfile(profile);

      // Second repository sharing the same backing store.
      final repo2 = PrefsFinancialProfileRepository(prefs);
      expect(await repo2.loadProfile(), profile);
    });

    test('partial profile can be saved and loaded', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = PrefsFinancialProfileRepository(prefs);

      // User filled in persona only — not yet completed.
      const draft = FinancialProfile(persona: Persona.student);

      await repo.saveProfile(draft);
      final loaded = await repo.loadProfile();

      expect(loaded?.persona, Persona.student);
      expect(loaded?.monthlyIncome, isNull);
      expect(loaded?.monthlyEssentialExpenses, isNull);
      expect(loaded?.primaryGoal, isNull);
      expect(loaded?.profileCompleted, isFalse);
    });

    test('raw JSON stored in preferences matches expected format', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = PrefsFinancialProfileRepository(prefs);

      const profile = FinancialProfile(
        persona: Persona.salaried,
        monthlyIncome: 80000,
        monthlyEssentialExpenses: 55000,
        primaryGoal: PrimaryGoal.saveMore,
        profileCompleted: true,
      );

      await repo.saveProfile(profile);

      final raw = prefs.getString('financial_profile_v1');
      expect(raw, isNotNull);

      final decoded = jsonDecode(raw!) as Map<String, dynamic>;
      expect(decoded['persona'], 'salaried');
      expect(decoded['monthlyIncome'], 80000);
      expect(decoded['monthlyEssentialExpenses'], 55000);
      expect(decoded['primaryGoal'], 'saveMore');
      expect(decoded['profileCompleted'], true);
    });
  });
}
