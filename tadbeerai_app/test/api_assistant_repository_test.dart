import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadbeerai/data/repositories/api_assistant_repository.dart';
import 'package:tadbeerai/domain/entities/assistant_api_models.dart';
import 'package:tadbeerai/domain/entities/financial_profile.dart';
import 'package:tadbeerai/domain/repositories/assistant_repository.dart';

/// ApiAssistantRepository tests over a scripted HTTP adapter — no real
/// network, full request-shape verification (spec cases 3, 10, 11, 12, 16,
/// 17, 18 request side).

/// Mirrors the demo finance context used across the app's test suite.
const _context = AssistantContext(
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

/// Context with no completed profile — nothing may be invented.
const _bareContext = AssistantContext(
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
);

const _okBody = {
  'answer': 'You would have Rs 25,000 left each month.',
  'intent': 'personal_finance',
  'language': 'en',
  'provider': 'groq',
  'agentsUsed': ['personal_finance'],
  'metrics': {'monthly_savings': 25000.0},
  'recommendations': ['Build an emergency fund.'],
  'sources': ['deterministic calculation results'],
  'dataStatus': 'live',
};

/// Fake adapter that records the RequestOptions it served and replies with
/// a scripted status/body — or throws when [error] is set.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter({
    this.statusCode = 200,
    this.body = _okBody,
    this.error,
  });

  final int statusCode;
  final Object? body;
  final Object? error;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (error != null) throw error!;
    final payload =
        body is String ? body as String : jsonEncode(body ?? const {});
    return ResponseBody.fromString(
      payload,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(_ScriptedAdapter adapter) => Dio(
      BaseOptions(baseUrl: 'http://localhost:9'),
    )..httpClientAdapter = adapter;

ApiAssistantRepository _repo(_ScriptedAdapter adapter) =>
    ApiAssistantRepository(dio: _dio(adapter));

void main() {
  test('posts the typed request to /v1/assistant/chat', () async {
    final adapter = _ScriptedAdapter();

    final reply = await _repo(adapter).respond(
      'How much money do I have left after my monthly expenses?',
      _context,
    );

    final request = adapter.requests.single;
    expect(request.path, '/v1/assistant/chat');
    expect(request.method, 'POST');

    final body = request.data as Map<String, Object?>;
    expect(
      body['message'],
      'How much money do I have left after my monthly expenses?',
    );
    expect(body['language'], 'en');

    // The typed reply wraps the parsed backend payload.
    expect(reply.api, isNotNull);
    expect(reply.api!.answer, 'You would have Rs 25,000 left each month.');
    expect(reply.api!.dataStatus, DataStatusKind.live);
    expect(reply.api!.sources, ['deterministic calculation results']);
  });

  test('financial_context serializes the saved profile (spec case 3)',
      () async {
    final adapter = _ScriptedAdapter();

    await _repo(adapter).respond('How am I doing?', _context);

    final body = adapter.requests.single.data as Map<String, Object?>;
    expect(body['financial_context'], {
      'persona': 'Salaried Employee',
      'monthly_income': 80000,
      'monthly_expenses': 55000,
      'primary_goal': 'Emergency Fund',
    });
  });

  test('missing financial context is omitted, not invented (spec case 16)',
      () async {
    final adapter = _ScriptedAdapter();

    await _repo(adapter).respond('What is inflation?', _bareContext);

    final body = adapter.requests.single.data as Map<String, Object?>;
    expect(body.containsKey('financial_context'), isFalse);
  });

  test('forwards the backend language code for Urdu and Roman Urdu', () async {
    final adapter = _ScriptedAdapter();
    final repo = _repo(adapter);

    await repo.respond('مہنگائی کیا ہے؟', _bareContext, language: 'ur');
    await repo.respond('Mehngai kya hai?', _bareContext, language: 'ur_latn');

    expect(
      (adapter.requests[0].data as Map)['language'],
      'ur',
    );
    expect(
      (adapter.requests[1].data as Map)['language'],
      'ur_latn',
    );
  });

  test('network failure maps to a friendly network error (spec case 10)',
      () async {
    final adapter = _ScriptedAdapter(
      error: DioException(
        requestOptions: RequestOptions(path: '/v1/assistant/chat'),
        type: DioExceptionType.connectionError,
      ),
    );

    await expectLater(
      _repo(adapter).respond('What is inflation?', _bareContext),
      throwsA(isA<AssistantApiException>().having(
        (error) => error.kind,
        'kind',
        AssistantErrorKind.network,
      )),
    );
  });

  test('timeouts map to a friendly timeout error (spec case 11)', () async {
    for (final type in [
      DioExceptionType.connectionTimeout,
      DioExceptionType.receiveTimeout,
    ]) {
      final adapter = _ScriptedAdapter(
        error: DioException(
          requestOptions: RequestOptions(path: '/v1/assistant/chat'),
          type: type,
        ),
      );

      await expectLater(
        _repo(adapter).respond('What is inflation?', _bareContext),
        throwsA(isA<AssistantApiException>().having(
          (error) => error.kind,
          'kind',
          AssistantErrorKind.timeout,
        )),
      );
    }
  });

  test('HTTP 5xx and 4xx map to a friendly server error (spec case 10)',
      () async {
    for (final status in [500, 503, 422]) {
      final adapter = _ScriptedAdapter(statusCode: status, body: {
        'detail': 'Internal Server Error',
      });

      await expectLater(
        _repo(adapter).respond('What is inflation?', _bareContext),
        throwsA(isA<AssistantApiException>().having(
          (error) => error.kind,
          'kind',
          AssistantErrorKind.server,
        )),
      );
    }
  });

  test('malformed (non-map) responses map to a friendly error (case 12)',
      () async {
    final adapter = _ScriptedAdapter(body: '[1, 2, 3]');

    await expectLater(
      _repo(adapter).respond('What is inflation?', _bareContext),
      throwsA(isA<AssistantApiException>().having(
        (error) => error.kind,
        'kind',
        AssistantErrorKind.malformed,
      )),
    );
  });

  test('empty answers map to a friendly error (spec case 12)', () async {
    final adapter = _ScriptedAdapter(body: {
      'answer': '',
      'intent': 'personal_finance',
      'provider': 'groq',
      'dataStatus': 'live',
    });

    await expectLater(
      _repo(adapter).respond('What is inflation?', _bareContext),
      throwsA(isA<AssistantApiException>().having(
        (error) => error.kind,
        'kind',
        AssistantErrorKind.malformed,
      )),
    );
  });

  test('scenario responses parse through the repository', () async {
    final adapter = _ScriptedAdapter(body: {
      'answer': 'Under this scenario your savings rise.',
      'intent': 'scenario_planning',
      'provider': 'groq',
      'metrics': {
        'scenario': {
          'scenario_type': 'save_more',
          'status': 'calculated',
          'assumptions': {'additional_monthly_savings_pkr': 5000.0},
          'outputs': {
            'additional_monthly_savings': 5000.0,
            'additional_savings_6_months': 30000.0,
            'additional_savings_12_months': 60000.0,
          },
        },
      },
      'sources': ['user-defined scenario (deterministic calculation)'],
      'dataStatus': 'scenario',
    });

    final reply =
        await _repo(adapter).respond('What if I save PKR 5000 more?', _context);

    expect(reply.api!.dataStatus, DataStatusKind.scenario);
    expect(reply.api!.scenario!.scenarioType, 'save_more');
    expect(
        reply.api!.scenario!.outputs['additional_savings_12_months'], 60000.0);
  });
}
