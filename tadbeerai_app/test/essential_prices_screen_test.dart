import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadbeerai/core/theme/app_theme.dart';
import 'package:tadbeerai/data/repositories/mock_economic_repository.dart';
import 'package:tadbeerai/domain/entities/assistant_api_models.dart';
import 'package:tadbeerai/domain/entities/commodity_price.dart';
import 'package:tadbeerai/features/economy/economic_pulse_screen.dart';
import 'package:tadbeerai/features/economy/widgets/commodity_card.dart';
import 'package:tadbeerai/features/economy/widgets/commodity_detail_sheet.dart';
import 'package:tadbeerai/l10n/app_localizations.dart';
import 'package:tadbeerai/providers/economic_providers.dart';

Widget _buildTestApp({
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

  final testCommodity = CommodityPrice(
    id: 'test_item',
    name: 'Wheat Flour (Atta)',
    normalizedName: 'wheat_flour',
    category: 'Food & Staples',
    unit: '10 kg bag',
    price: 1390.0,
    previousPrice: 1380.0,
    changeAbsolute: 10.0,
    changePercent: 0.72,
    trend: 'up',
    sourceName: 'Pakistan Bureau of Statistics (PBS)',
    observationPeriod: 'Week ended Sep 03, 2026',
    retrievedAt: DateTime.now(),
    dataStatus: DataStatusKind.live,
    whatChanged: 'Mill-gate prices adjusted upward.',
    whyItMatters: 'Essential caloric staple for everyday Pakistani households.',
    financialImpactHint: 'Average family consumes 2 bags/month.',
  );

  group('CommodityCard Widget', () {
    testWidgets('renders commodity information, unit price, and trend',
        (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        _buildTestApp(
          child: CommodityCard(
            commodity: testCommodity,
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Wheat Flour (Atta)'), findsOneWidget);
      expect(find.text('Rs 1,390'), findsOneWidget);
      expect(find.text('10 kg bag'), findsOneWidget);
      expect(find.text('+0.7%'), findsOneWidget);

      await tester.tap(find.byType(CommodityCard));
      expect(tapped, isTrue);
    });
  });

  group('CommodityDetailSheet Widget', () {
    testWidgets('renders economic explanation, provenance, and action buttons',
        (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: SingleChildScrollView(
            child: CommodityDetailSheet(commodity: testCommodity),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Wheat Flour (Atta)'), findsOneWidget);
      expect(find.text('What Changed?'), findsOneWidget);
      expect(find.text('Mill-gate prices adjusted upward.'), findsOneWidget);
      expect(find.text('Why It Matters'), findsOneWidget);
      expect(
        find.text('Essential caloric staple for everyday Pakistani households.'),
        findsOneWidget,
      );
      expect(find.text('Household Budget Impact'), findsOneWidget);
      expect(
        find.text('Average family consumes 2 bags/month.'),
        findsOneWidget,
      );
      expect(find.textContaining('Pakistan Bureau of Statistics (PBS)'),
          findsOneWidget);
      expect(find.text('Ask Tadbeer about this price change'), findsOneWidget);
      expect(find.text('Try a What-If scenario'), findsOneWidget);
    });
  });

  group('EconomicPulseScreen - Essential Prices Section', () {
    testWidgets('renders essential prices section with categories and items',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildTestApp(
          child: const EconomicPulseScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the Essential Prices section exists
      expect(find.text('Essential Prices'), findsOneWidget);
      expect(find.textContaining('Everyday items affecting household budgets'),
          findsOneWidget);

      // Verify category filter chips are present
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Vegetables'), findsOneWidget);

      // Verify commodity cards are rendered
      expect(find.byType(CommodityCard), findsWidgets);

      // Verify tapping 'View all 16 items' expands the list
      final viewAllButton = find.text('View all 16 items');
      if (viewAllButton.evaluate().isNotEmpty) {
        await tester.tap(viewAllButton);
        await tester.pumpAndSettle();
        expect(find.text('Show less'), findsOneWidget);
      }
    });

    testWidgets('filtering by Vegetables category updates the commodity list',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildTestApp(
          child: const EconomicPulseScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on the Vegetables category chip
      final vegChip = find.text('Vegetables');
      expect(vegChip, findsOneWidget);
      await tester.tap(vegChip);
      await tester.pumpAndSettle();

      // Vegetables should include Tomatoes or Onions or Potatoes
      expect(find.text('Tomatoes'), findsOneWidget);
    });
  });
}
