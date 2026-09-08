import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tadbeerai/core/constants/app_constants.dart';
import 'package:tadbeerai/domain/entities/app_user.dart';
import 'package:tadbeerai/domain/entities/financial_profile.dart';
import 'package:tadbeerai/domain/repositories/auth_repository.dart';
import 'package:tadbeerai/domain/repositories/financial_profile_repository.dart';
import 'package:tadbeerai/features/auth/auth_controller.dart';
import 'package:tadbeerai/features/profile/user_profile_screen.dart';
import 'package:tadbeerai/l10n/app_localizations.dart';
import 'package:tadbeerai/providers/repository_providers.dart';

class _FakeProfileRepo implements FinancialProfileRepository {
  _FakeProfileRepo(this.stored);
  FinancialProfile? stored;

  @override
  Future<FinancialProfile?> loadProfile() async => stored;

  @override
  Future<void> saveProfile(FinancialProfile profile) async {
    stored = profile;
  }

  @override
  Future<void> clearProfile() async {
    stored = null;
  }
}

class _FakeAuthRepo implements AuthRepository {
  _FakeAuthRepo(this.currentUserVal);
  AppUser? currentUserVal;

  @override
  Future<AppUser?> currentUser() async => currentUserVal;

  @override
  Future<AppUser> signIn(
          {required String email, required String password}) async =>
      currentUserVal!;

  @override
  Future<AppUser> signUp({
    required String name,
    required String email,
    required String password,
  }) async =>
      currentUserVal!;

  @override
  Future<AppUser> signInAsGuest() async => currentUserVal!;

  @override
  Future<AppUser?> signInWithGoogle({String? email, String? name}) async =>
      currentUserVal;

  @override
  Future<void> sendPasswordResetCode({required String email}) async {}

  @override
  Future<bool> resetPasswordWithCode({
    required String email,
    required String code,
    required String newPassword,
  }) async =>
      true;

  @override
  Future<void> signOut() async {
    currentUserVal = null;
  }
}

class _TestAuthController extends AuthController {
  _TestAuthController(this._initialUser);
  final AppUser? _initialUser;

  @override
  AppUser? build() => _initialUser;
}

late SharedPreferences testPrefs;

Widget _buildTestApp({
  required AppUser? user,
  required FinancialProfile? profile,
}) {
  final profileRepo = _FakeProfileRepo(profile);
  final authRepo = _FakeAuthRepo(user);

  return ProviderScope(
    overrides: [
      sharedPrefsProvider.overrideWithValue(testPrefs),
      financialProfileRepositoryProvider.overrideWithValue(profileRepo),
      authRepositoryProvider.overrideWithValue(authRepo),
      authControllerProvider.overrideWith(() => _TestAuthController(user)),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: UserProfileScreen(),
    ),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    testPrefs = await SharedPreferences.getInstance();
  });

  group('UserProfileScreen Tests', () {
    testWidgets('renders user profile with registered account data',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      const testUser = AppUser(
        id: 'usr_12345',
        name: 'Ali Khan',
        email: 'ali.khan@example.com',
        phone: '+923001234567',
      );

      const testProfile = FinancialProfile(
        name: 'Ali Khan',
        persona: Persona.salaried,
        monthlyIncome: 150000,
        monthlyEssentialExpenses: 80000,
        totalSavings: 250000,
        profileCompleted: true,
      );

      await tester
          .pumpWidget(_buildTestApp(user: testUser, profile: testProfile));
      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('My Profile'), findsOneWidget);

      // Verify Identity card
      expect(find.text('Ali Khan'), findsWidgets);
      expect(find.text('Salaried Professional'), findsWidgets);
      expect(find.text('Verified • Alerts Active'), findsOneWidget);

      // Verify Groups and Menu Items
      expect(find.text('ACCOUNT & FINANCES'), findsOneWidget);
      expect(find.text('Personal Information'), findsOneWidget);
      expect(find.text('Financial Information'), findsOneWidget);

      expect(find.text('PREFERENCES & SYSTEM'), findsOneWidget);
      expect(find.text('Theme Appearance'), findsOneWidget);
      expect(find.text('App Settings'), findsNothing);
      expect(find.text('Language'), findsOneWidget);

      expect(find.text('SUPPORT & INFORMATION'), findsOneWidget);
      expect(find.text('Help & Support'), findsOneWidget);
      expect(find.text('About Tadbeer AI'), findsOneWidget);

      // Verify Sign Out
      expect(find.text('Sign Out'), findsOneWidget);
    });

    testWidgets('renders guest session status pill when user is guest',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      const guestUser = AppUser(
        id: 'guest_9999',
        name: 'Guest User',
        email: 'guest@tadbeer.ai',
      );

      await tester.pumpWidget(_buildTestApp(user: guestUser, profile: null));
      await tester.pumpAndSettle();

      expect(find.text('Guest Session • Local'), findsOneWidget);
    });

    testWidgets('tapping Personal Information opens bottom sheet',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      const testUser = AppUser(
        id: 'usr_abc',
        name: 'Sara Ahmed',
        email: 'sara@example.com',
        phone: '+923331112233',
      );

      await tester.pumpWidget(_buildTestApp(user: testUser, profile: null));
      await tester.pumpAndSettle();

      // Tap Personal Information
      await tester.tap(find.text('Personal Information'));
      await tester.pumpAndSettle();

      // Verify modal sheet content
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('sara@example.com'), findsWidgets);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Phone Number'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
    });

    testWidgets('tapping Financial Information opens overview bottom sheet',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      const testProfile = FinancialProfile(
        name: 'Hamza Malik',
        persona: Persona.businessOwner,
        monthlyIncome: 350000,
        monthlyEssentialExpenses: 120000,
        totalSavings: 800000,
        profileCompleted: true,
      );

      await tester.pumpWidget(_buildTestApp(user: null, profile: testProfile));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Financial Information'));
      await tester.pumpAndSettle();

      expect(find.text('Assigned Persona'), findsOneWidget);
      expect(find.text('Business Owner'), findsWidgets);
      expect(find.text('Monthly Income'), findsOneWidget);
      expect(find.text('Edit Financial Information'), findsOneWidget);
    });

    testWidgets(
        'tapping each financial option separately opens individual editor and updates profile',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      const testProfile = FinancialProfile(
        name: 'Hamza Malik',
        persona: Persona.businessOwner,
        monthlyIncome: 350000,
        monthlyEssentialExpenses: 120000,
        totalSavings: 800000,
        primaryGoal: PrimaryGoal.emergencyFund,
        profileCompleted: true,
      );

      final profileRepo = _FakeProfileRepo(testProfile);

      await tester.pumpWidget(ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(testPrefs),
          financialProfileRepositoryProvider.overrideWithValue(profileRepo),
          authRepositoryProvider.overrideWithValue(_FakeAuthRepo(null)),
          authControllerProvider.overrideWith(() => _TestAuthController(null)),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: UserProfileScreen(),
        ),
      ));
      await tester.pumpAndSettle();

      // Open Financial Information sheet
      await tester.tap(find.text('Financial Information'));
      await tester.pumpAndSettle();

      // Verify instruction banner
      expect(
        find.text('Tap any item to edit it separately at once.'),
        findsOneWidget,
      );

      // 1. Edit Persona directly
      await tester.tap(find.text('Assigned Persona'));
      await tester.pumpAndSettle();

      expect(find.text('Update Persona'), findsWidgets);
      // Select Salaried Professional
      await tester.tap(find.text('Salaried Professional').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Update Persona').last);
      await tester.pumpAndSettle();

      expect(profileRepo.stored?.persona, Persona.salaried);

      // 2. Edit Monthly Income directly
      await tester.tap(find.text('Monthly Income'));
      await tester.pumpAndSettle();

      expect(find.text('Update Monthly Income'), findsWidgets);
      // Select quick preset chip
      await tester.tap(find.text('PKR 200k'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Update Monthly Income').last);
      await tester.pumpAndSettle();

      expect(profileRepo.stored?.monthlyIncome, 200000);

      // 3. Edit Primary Financial Goal directly
      await tester.tap(find.text('Primary Financial Goal'));
      await tester.pumpAndSettle();

      expect(find.text('Update Financial Goal'), findsOneWidget);
      await tester.tap(find.text('Save More'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Update Primary Goal'));
      await tester.pumpAndSettle();

      expect(profileRepo.stored?.primaryGoal, PrimaryGoal.saveMore);
    });

    testWidgets(
        'Theme Appearance is present directly in Preferences & System without App Settings',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildTestApp(user: null, profile: null));
      await tester.pumpAndSettle();

      expect(find.text('App Settings'), findsNothing);
      expect(find.text('Theme Appearance'), findsOneWidget);
    });

    testWidgets(
        'tapping Theme Appearance opens theme selection sheet and allows selecting Light/Dark/System',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildTestApp(user: null, profile: null));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Theme Appearance').first, 200);
      await tester.tap(find.text('Theme Appearance').first);
      await tester.pumpAndSettle();

      expect(
        find.text('Select your preferred appearance for Tadbeer AI'),
        findsOneWidget,
      );
      expect(find.text('Dark Theme'), findsOneWidget);
      expect(find.text('Light Theme'), findsOneWidget);
      expect(find.text('System Default'), findsOneWidget);

      // Tap Light Theme
      await tester.tap(find.text('Light Theme'));
      await tester.pumpAndSettle();

      // Bottom sheet closes after selection
      expect(
        find.text('Select your preferred appearance for Tadbeer AI'),
        findsNothing,
      );
      expect(testPrefs.getString(AppConstants.prefThemeMode), 'light');
    });

    testWidgets(
        'tapping Language opens language sheet and shows English as active language',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildTestApp(user: null, profile: null));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Language'));
      await tester.pumpAndSettle();

      expect(find.text('Language'), findsWidgets);
      expect(find.text('English'), findsWidgets);
      expect(find.text('Default language (English only)'), findsOneWidget);

      // Tap English option
      await tester.tap(find.text('English').last);
      await tester.pumpAndSettle();

      // Bottom sheet closes after selection
      expect(find.text('Default language (English only)'), findsNothing);
    });

    testWidgets(
        'tapping Sign Out shows confirmation bottom sheet with Cancel action',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildTestApp(user: null, profile: null));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Sign Out'), 200);
      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Are you sure you want to sign out? Your financial records on this device will remain secure.',
        ),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Are you sure you want to sign out? Your financial records on this device will remain secure.',
        ),
        findsNothing,
      );
    });
  });
}
