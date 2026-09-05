import 'package:flutter_test/flutter_test.dart';
import 'package:tadbeerai/domain/entities/assistant_api_models.dart';

/// Typed request/response model tests for the POST /v1/assistant/chat
/// contract (spec cases 1, 2, 4-7, 12).
void main() {
  group('AssistantApiRequest serialization', () {
    test('includes message, language and financial_context when present', () {
      const request = AssistantApiRequest(
        message: 'How much money do I have left after my monthly expenses?',
        language: 'en',
        financialContext: {
          'persona': 'Salaried Employee',
          'monthly_income': 80000,
          'monthly_expenses': 55000,
          'primary_goal': 'Emergency Fund',
        },
      );

      final json = request.toJson();

      expect(json['message'],
          'How much money do I have left after my monthly expenses?');
      expect(json['language'], 'en');
      expect(json['financial_context'], {
        'persona': 'Salaried Employee',
        'monthly_income': 80000,
        'monthly_expenses': 55000,
        'primary_goal': 'Emergency Fund',
      });
    });

    test('omits financial_context entirely when there is no profile', () {
      const request = AssistantApiRequest(message: 'What is inflation?');

      final json = request.toJson();

      expect(json.containsKey('financial_context'), isFalse);
      expect(json['message'], 'What is inflation?');
      expect(json['language'], 'en');
    });

    test('defaults language to en', () {
      const request = AssistantApiRequest(message: 'hello');
      expect(request.language, 'en');
    });
  });

  group('AssistantApiReply deserialization', () {
    test('parses a full backend response with a scenario payload', () {
      final reply = AssistantApiReply.fromJson({
        'answer': 'Under this scenario your savings rise.',
        'intent': 'scenario_planning',
        'language': 'en',
        'provider': 'groq',
        'agentsUsed': ['supervisor', 'risk_impact'],
        'metrics': {
          'monthly_savings': 25000.0,
          'scenario': {
            'scenario_type': 'save_more',
            'status': 'calculated',
            'source': 'user-defined scenario (deterministic calculation)',
            'assumptions': {'additional_monthly_savings_pkr': 5000.0},
            'inputs': {'monthly_income': 80000.0},
            'outputs': {
              'additional_monthly_savings': 5000.0,
              'additional_savings_6_months': 30000.0,
              'additional_savings_12_months': 60000.0,
            },
            'limitations': ['This is an illustrative calculation.'],
          },
        },
        'recommendations': ['Direct the amount toward your goal.'],
        'sources': ['deterministic calculation results'],
        'dataStatus': 'scenario',
      });

      expect(reply.answer, 'Under this scenario your savings rise.');
      expect(reply.intent, 'scenario_planning');
      expect(reply.language, 'en');
      expect(reply.provider, 'groq');
      expect(reply.agentsUsed, ['supervisor', 'risk_impact']);
      expect(reply.metrics['monthly_savings'], 25000.0);
      expect(reply.recommendations, ['Direct the amount toward your goal.']);
      expect(reply.sources, ['deterministic calculation results']);
      expect(reply.dataStatus, DataStatusKind.scenario);

      final scenario = reply.scenario!;
      expect(scenario.scenarioType, 'save_more');
      expect(scenario.status, 'calculated');
      expect(
          scenario.source, 'user-defined scenario (deterministic calculation)');
      expect(scenario.assumptions['additional_monthly_savings_pkr'], 5000.0);
      expect(scenario.outputs['additional_savings_12_months'], 60000.0);
      expect(scenario.limitations, ['This is an illustrative calculation.']);
    });

    test('parses each dataStatus kind (live/partial/demo/unavailable)', () {
      AssistantApiReply minimal(String status) => AssistantApiReply.fromJson({
            'answer': 'ok',
            'intent': 'economic_intelligence',
            'provider': 'gemini',
            'dataStatus': status,
          });

      expect(minimal('live').dataStatus, DataStatusKind.live);
      expect(minimal('partial').dataStatus, DataStatusKind.partial);
      expect(minimal('demo').dataStatus, DataStatusKind.demo);
      expect(minimal('unavailable').dataStatus, DataStatusKind.unavailable);
      expect(minimal('scenario').dataStatus, DataStatusKind.scenario);
    });

    test('unknown or missing dataStatus never masquerades as live', () {
      AssistantApiReply withStatus(String? status) =>
          AssistantApiReply.fromJson({
            'answer': 'ok',
            'provider': 'groq',
            if (status != null) 'dataStatus': status,
          });

      expect(withStatus('totally-new-status').dataStatus, DataStatusKind.demo);
      expect(withStatus(null).dataStatus, DataStatusKind.demo);
    });

    test('defaults for optional list fields', () {
      final reply = AssistantApiReply.fromJson({
        'answer': 'ok',
        'provider': 'groq',
      });

      expect(reply.agentsUsed, isEmpty);
      expect(reply.recommendations, isEmpty);
      expect(reply.sources, isEmpty);
      expect(reply.metrics, isEmpty);
      expect(reply.scenario, isNull);
      expect(reply.intent, '');
      expect(reply.language, 'en');
    });

    test('scenario stays null when metrics carry no scenario', () {
      final reply = AssistantApiReply.fromJson({
        'answer': 'ok',
        'provider': 'groq',
        'dataStatus': 'live',
        'metrics': {'inflation_rate_pct': 3.5},
      });

      expect(reply.scenario, isNull);
      expect(reply.dataStatus, DataStatusKind.live);
    });

    test('empty answer is rejected (spec case: empty response handling)', () {
      expect(
        () => AssistantApiReply.fromJson({
          'answer': '   ',
          'provider': 'groq',
        }),
        throwsFormatException,
      );
      expect(
        () => AssistantApiReply.fromJson({'provider': 'groq'}),
        throwsFormatException,
      );
    });

    test('non-string answers are rejected as malformed', () {
      expect(
        () => AssistantApiReply.fromJson({'answer': 42, 'provider': 'groq'}),
        throwsFormatException,
      );
    });
  });

  group('DataStatusKind parsing', () {
    test('maps every documented backend value', () {
      expect(dataStatusFromName('live'), DataStatusKind.live);
      expect(dataStatusFromName('partial'), DataStatusKind.partial);
      expect(dataStatusFromName('demo'), DataStatusKind.demo);
      expect(dataStatusFromName('scenario'), DataStatusKind.scenario);
      expect(dataStatusFromName('unavailable'), DataStatusKind.unavailable);
      expect(dataStatusFromName('anything-else'), DataStatusKind.demo);
      expect(dataStatusFromName(null), DataStatusKind.demo);
    });
  });
}
