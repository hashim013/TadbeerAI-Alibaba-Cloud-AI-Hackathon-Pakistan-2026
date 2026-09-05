@Timeout(Duration(minutes: 3))
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadbeerai/data/repositories/api_assistant_repository.dart';
import 'package:tadbeerai/domain/entities/assistant_api_models.dart';
import 'package:tadbeerai/domain/entities/financial_profile.dart';
import 'package:tadbeerai/domain/repositories/assistant_repository.dart';

/// The five end-to-end smoke flows against a live backend: an economic
/// question, a personal finance question carrying financial_context, both
/// What-If families, and the unreachable-server failure path.
///
/// Opt-in so the default suite never needs a server running:
///
/// ```sh
/// flutter test test/e2e_backend_smoke_test.dart \
///   --dart-define=E2E_API_BASE_URL=http://127.0.0.1:8000
/// ```
const String _e2eBaseUrl = String.fromEnvironment('E2E_API_BASE_URL');

final bool _enabled = _e2eBaseUrl.isNotEmpty;

/// The demo salaried position used across the suite — a completed profile
/// whose fields must travel as financial_context.
const _profileContext = AssistantContext(
  monthlyIncome: 80000,
  monthlyExpenses: 55000,
  monthlySavings: 25000,
  discretionarySpending: 10100,
  savingsRate: 0.3125,
  healthScore: 76,
  emergencyMonths: 3.0,
  overBudgetCategories: [],
  budgetLimitTotal: 55000,
  budgetedSpent: 55000,
  goalCount: 1,
  goalAverageProgress: 0.6,
  topGoalTitle: 'Emergency Fund',
  topGoalProgress: 0.6,
  topGoalRequiredMonthly: 12000,
  inflationRate: 11.2,
  usdPkrRate: 278.5,
  usdPkrChange: 1.2,
  kiborRate: 20.3,
  persona: Persona.salaried,
  profileIncome: 80000,
  profileExpenses: 55000,
  primaryGoal: PrimaryGoal.emergencyFund,
);

ApiAssistantRepository _repo() => ApiAssistantRepository(baseUrl: _e2eBaseUrl);

/// Backend JSON numbers arrive as int or double — compare numerically.
num _num(Object? value) => value as num;

void main() {
  test('flow 1 — economic question answers with indicators', () async {
    final api = (await _repo().respond(
      'How is inflation affecting Pakistan?',
      _profileContext,
    ))
        .api!;

    expect(api.answer.trim(), isNotEmpty);
    expect(api.language, 'en');
    // Economic indicators are attached — live values or documented fallbacks.
    expect(
      api.metrics.keys.any(const [
        'inflation_rate_pct',
        'policy_rate_pct',
        'kibor_3m_pct',
        'usd_pkr',
      ].contains),
      isTrue,
    );
    // Live or partial answers name their sources; demo says so honestly.
    if (api.dataStatus == DataStatusKind.live ||
        api.dataStatus == DataStatusKind.partial) {
      expect(api.sources, isNotEmpty);
    }
  },
      skip: _enabled ? false : 'E2E_API_BASE_URL not set',
      timeout: const Timeout(Duration(minutes: 3)));

  test('flow 2 — personal finance carries the financial_context', () async {
    final bodies = <Map<String, Object?>>[];
    final dio = Dio(
      BaseOptions(
        baseUrl: _e2eBaseUrl,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 90),
      ),
    )..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            bodies.add(options.data as Map<String, Object?>);
            handler.next(options);
          },
        ),
      );

    final api = (await ApiAssistantRepository(dio: dio).respond(
      'How much money do I have left after my monthly expenses?',
      _profileContext,
    ))
        .api!;

    // The completed profile travelled with the request — nothing invented.
    expect(bodies.single['financial_context'], {
      'persona': 'Salaried Employee',
      'monthly_income': 80000,
      'monthly_expenses': 55000,
      'primary_goal': 'Emergency Fund',
    });
    // The backend computed the leftover from that context — deterministic.
    expect(api.answer.trim(), isNotEmpty);
    expect(_num(api.metrics['monthly_savings']), 25000);
  },
      skip: _enabled ? false : 'E2E_API_BASE_URL not set',
      timeout: const Timeout(Duration(minutes: 3)));

  test('flow 3 — What-If save more computes the deterministic numbers',
      () async {
    final api = (await _repo().respond(
      'What if I save PKR 5,000 more every month?',
      _profileContext,
    ))
        .api!;

    expect(api.dataStatus, DataStatusKind.scenario);
    final scenario = api.scenario!;
    expect(scenario.scenarioType, 'save_more');
    expect(scenario.status, 'calculated');
    // The user's stated assumption, labelled by the backend.
    expect(_num(scenario.assumptions['additional_monthly_savings_pkr']), 5000);
    // Deterministic accumulations — never recalculated in Dart.
    expect(_num(scenario.outputs['additional_monthly_savings']), 5000);
    expect(_num(scenario.outputs['additional_savings_6_months']), 30000);
    expect(_num(scenario.outputs['additional_savings_12_months']), 60000);
  },
      skip: _enabled ? false : 'E2E_API_BASE_URL not set',
      timeout: const Timeout(Duration(minutes: 3)));

  test('flow 4 — What-If expense shock computes the projected budget',
      () async {
    final api = (await _repo().respond(
      'What if my expenses increase by 10%',
      _profileContext,
    ))
        .api!;

    expect(api.dataStatus, DataStatusKind.scenario);
    final scenario = api.scenario!;
    expect(scenario.scenarioType, 'expense_shock');
    expect(scenario.status, 'calculated');
    expect(_num(scenario.assumptions['expense_change_pct']), 10);
    expect(_num(scenario.outputs['current_monthly_expenses']), 55000);
    expect(_num(scenario.outputs['additional_monthly_expense']), 5500);
    expect(_num(scenario.outputs['new_monthly_expenses']), 60500);
    expect(_num(scenario.outputs['projected_monthly_surplus']), 19500);
  },
      skip: _enabled ? false : 'E2E_API_BASE_URL not set',
      timeout: const Timeout(Duration(minutes: 3)));

  test('flow 5 — an unreachable server fails gracefully', () async {
    // Port 9 (discard) has no HTTP server — the URL is dead, not malformed.
    final deadRepo = ApiAssistantRepository(baseUrl: 'http://127.0.0.1:9');
    try {
      await deadRepo.respond(
        'How is inflation affecting Pakistan?',
        _profileContext,
      );
      fail('A dead endpoint must surface a typed failure.');
    } on AssistantApiException catch (error) {
      // Friendly kinds only — a raw Dio/Socket error would have crashed
      // straight through this catch instead.
      expect(
        error.kind,
        anyOf(AssistantErrorKind.network, AssistantErrorKind.timeout),
      );
    }
  },
      skip: _enabled ? false : 'E2E_API_BASE_URL not set',
      timeout: const Timeout(Duration(minutes: 3)));
}
