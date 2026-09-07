import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadbeerai/core/theme/app_theme.dart';
import 'package:tadbeerai/domain/entities/assistant_api_models.dart';
import 'package:tadbeerai/domain/entities/economic_indicator.dart';
import 'package:tadbeerai/features/economy/widgets/economy_widgets.dart';
import 'package:tadbeerai/l10n/app_localizations.dart';

/// Minimal localization harness — [IndicatorTrendChart] reads its empty-state
/// copy from `context.l10n`, so the widget must be pumped under the app's
/// localization delegates.
Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.dark(),
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

EconomicIndicator _indicator({
  required String id,
  required List<IndicatorPoint> history,
  required double current,
  required double previous,
  DataStatusKind status = DataStatusKind.live,
  String frequency = 'annual',
}) =>
    EconomicIndicator(
      id: id,
      name: id,
      currentValue: current,
      previousValue: previous,
      unit: '%',
      category: 'prices',
      source: 'World Bank',
      dataStatus: status,
      updatedAt: DateTime(2026, 6, 13),
      period: '2025',
      frequency: frequency,
      history: history,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IndicatorTrendChart', () {
    testWidgets('shows an honest empty state when history has < 2 points',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          IndicatorTrendChart(
            indicator: _indicator(
              id: 'policyRate',
              history: const [],
              current: 15.0,
              previous: 15.0,
              status: DataStatusKind.demo,
              frequency: '',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Historical data unavailable'), findsOneWidget);
      expect(find.byType(LineChart), findsNothing);
    });

    testWidgets('also treats a single observation as unavailable',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          IndicatorTrendChart(
            indicator: _indicator(
              id: 'kibor',
              history: [IndicatorPoint(month: DateTime(2025), value: 13.5)],
              current: 13.5,
              previous: 13.5,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Historical data unavailable'), findsOneWidget);
      expect(find.byType(LineChart), findsNothing);
    });

    testWidgets('renders a real line chart when history has >= 2 points',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          IndicatorTrendChart(
            indicator: _indicator(
              id: 'inflation',
              history: [
                IndicatorPoint(month: DateTime(2023), value: 19.88),
                IndicatorPoint(month: DateTime(2024), value: 23.41),
                IndicatorPoint(month: DateTime(2025), value: 3.55),
              ],
              current: 3.55,
              previous: 23.41,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LineChart), findsOneWidget);
      expect(find.text('Historical data unavailable'), findsNothing);
    });
  });
}
