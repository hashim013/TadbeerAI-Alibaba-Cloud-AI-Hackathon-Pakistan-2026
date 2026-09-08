import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadbeerai/core/theme/app_theme.dart';
import 'package:tadbeerai/data/mock/mock_commodity_data.dart';
import 'package:tadbeerai/data/repositories/mock_economic_repository.dart';
import 'package:tadbeerai/domain/entities/financial_profile.dart';
import 'package:tadbeerai/domain/repositories/financial_profile_repository.dart';
import 'package:tadbeerai/domain/services/economic_impact_service.dart';
import 'package:tadbeerai/features/economy/economic_pulse_screen.dart';
import 'package:tadbeerai/features/economy/widgets/economy_widgets.dart';
import 'package:tadbeerai/l10n/app_localizations.dart';
import 'package:tadbeerai/providers/economic_providers.dart';
import 'package:tadbeerai/providers/repository_providers.dart';

Widget _buildPulseApp({
  required Widget child,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: [
      economicRepositoryProvider.overrideWithValue(MockEconomicRepository()),
      economicImpactInputProvider.overrideWithValue(null),
      ...overrides,
    ],
    child: MaterialApp(
      theme: AppTheme.dark(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Essential Commodities Dataset (Zero Duplication & Full Staples)', () {
    test('seedItems contains all essential staples with unique IDs', () {
      final items = MockCommodityData.seedItems(DateTime.now());
      expect(items.length, greaterThanOrEqualTo(20));

      // Verify no duplicate IDs
      final idSet = <String>{};
      for (final item in items) {
        expect(idSet.contains(item.id), isFalse,
            reason: 'Duplicate commodity ID found: ${item.id}');
        idSet.add(item.id);
      }

      // Verify explicit presence of flour, eggs, meat, petrol, diesel
      final ids = items.map((i) => i.id).toSet();
      expect(ids.contains('wheat_flour_10kg'), isTrue,
          reason: 'Wheat Flour 10kg missing');
      expect(ids.contains('wheat_flour_bag'), isTrue,
          reason: 'Wheat Flour 20kg missing');
      expect(ids.contains('farm_eggs'), isTrue, reason: 'Farm Eggs missing');
      expect(ids.contains('chicken_broiler'), isTrue,
          reason: 'Chicken Meat missing');
      expect(ids.contains('beef_bone'), isTrue, reason: 'Beef Meat missing');
      expect(ids.contains('mutton'), isTrue, reason: 'Mutton Meat missing');
      expect(ids.contains('petrol_super'), isTrue,
          reason: 'Petrol Super missing');
      expect(ids.contains('diesel_hsd'), isTrue,
          reason: 'High-Speed Diesel missing');
      expect(ids.contains('lpg_cylinder'), isTrue,
          reason: 'LPG Domestic Cylinder missing');
    });

    test('Cooking & Fuel category includes Petrol, Diesel, and LPG', () async {
      final repo = MockEconomicRepository();
      final overview =
          await repo.getEssentialPrices(category: 'Cooking & Fuel');
      final ids = overview.items.map((i) => i.id).toSet();

      expect(ids.contains('petrol_super'), isTrue);
      expect(ids.contains('diesel_hsd'), isTrue);
      expect(ids.contains('lpg_cylinder'), isTrue);
      expect(ids.contains('cooking_oil'), isTrue);
    });

    test('Food & Staples category includes Wheat Flour and Rice', () async {
      final repo = MockEconomicRepository();
      final overview =
          await repo.getEssentialPrices(category: 'Food & Staples');
      final ids = overview.items.map((i) => i.id).toSet();

      expect(ids.contains('wheat_flour_10kg'), isTrue);
      expect(ids.contains('wheat_flour_bag'), isTrue);
      expect(ids.contains('basmati_rice'), isTrue);
      expect(ids.contains('sugar_refined'), isTrue);
    });

    test('Dairy & Poultry category includes Eggs, Chicken, Beef, and Mutton',
        () async {
      final repo = MockEconomicRepository();
      final overview =
          await repo.getEssentialPrices(category: 'Dairy & Poultry');
      final ids = overview.items.map((i) => i.id).toSet();

      expect(ids.contains('farm_eggs'), isTrue);
      expect(ids.contains('chicken_broiler'), isTrue);
      expect(ids.contains('beef_bone'), isTrue);
      expect(ids.contains('mutton'), isTrue);
      expect(ids.contains('fresh_milk'), isTrue);
    });
  });

  group('EconomicPulseScreen Layout & Non-Duplication Tests', () {
    testWidgets('renders single interactive trend chart without 5x duplication',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildPulseApp(child: const EconomicPulseScreen()));
      await tester.pumpAndSettle();

      // Exactly ONE IndicatorTrendChart is rendered in the interactive explorer
      expect(find.byType(IndicatorTrendChart), findsOneWidget);

      // Verify essential commodity cards are rendered
      expect(find.byType(CommodityCard), findsWidgets);

      // Verify household budget impact card exists
      expect(find.text('Why Everyday Prices Matter'), findsOneWidget);
    });

    testWidgets('filtering by Cooking & Fuel shows Petrol and Diesel',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildPulseApp(child: const EconomicPulseScreen()));
      await tester.pumpAndSettle();

      // Tap on Cooking & Fuel chip
      final fuelChip = find.text('Cooking & Fuel');
      expect(fuelChip, findsOneWidget);
      await tester.tap(fuelChip);
      await tester.pumpAndSettle();

      // Verify Petrol Super and High-Speed Diesel are visible
      expect(find.text('Petrol Super'), findsOneWidget);
      expect(find.text('High-Speed Diesel (HSD)'), findsOneWidget);
    });

    testWidgets('filtering by Food & Staples shows Wheat Flour',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildPulseApp(child: const EconomicPulseScreen()));
      await tester.pumpAndSettle();

      // Tap on Food & Staples chip
      final staplesChip = find.text('Food & Staples');
      expect(staplesChip, findsOneWidget);
      await tester.tap(staplesChip);
      await tester.pumpAndSettle();

      // Verify Wheat Flour 10kg and 20kg are visible
      expect(find.text('Wheat Flour (Atta 10 kg)'), findsOneWidget);
    });

    testWidgets(
        'renders personalized economic decision and persona badge when impact input is present',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final profileRepo = _TestProfileRepo(
        const FinancialProfile(
          persona: Persona.student,
          monthlyIncome: 60000,
          monthlyEssentialExpenses: 35000,
          primaryGoal: PrimaryGoal.education,
          profileCompleted: true,
        ),
      );

      await tester.pumpWidget(_buildPulseApp(
        child: const EconomicPulseScreen(),
        overrides: [
          financialProfileRepositoryProvider.overrideWithValue(profileRepo),
          economicImpactInputProvider.overrideWithValue(
            const EconomicImpactInput(
              monthlyIncome: 60000,
              monthlyExpenses: 35000,
              discretionarySpending: 5000,
            ),
          ),
        ],
      ));
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      // Persona badge and primary goal chip are rendered
      expect(find.text('Student / Learner'), findsOneWidget);
      expect(find.text('Education'), findsOneWidget);

      // Strategic Guidance decision box is rendered
      expect(find.textContaining('Strategic Guidance'), findsOneWidget);
      expect(find.textContaining('academic milestones'), findsOneWidget);
    });
  });
}

class _TestProfileRepo implements FinancialProfileRepository {
  _TestProfileRepo(this._profile);
  FinancialProfile? _profile;

  @override
  Future<FinancialProfile?> loadProfile() async => _profile;

  @override
  Future<void> saveProfile(FinancialProfile profile) async {
    _profile = profile;
  }

  @override
  Future<void> clearProfile() async {
    _profile = null;
  }
}

