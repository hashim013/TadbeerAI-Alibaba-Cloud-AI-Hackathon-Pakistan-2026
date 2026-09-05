/// Typed models for the `POST /v1/assistant/chat` backend contract.
///
/// These mirror `core/schemas.py` on the FastAPI side. The response's
/// `dataStatus` is code-controlled by the backend — "live" / "partial" /
/// "demo" / "unavailable" for economic indicators, or "scenario" when the
/// answer's numbers are a user-defined What-If assumption computed by the
/// deterministic scenario engine. All numbers come from the backend; Flutter
/// never recalculates them.
library;

/// Data provenance of an assistant answer.
enum DataStatusKind { live, partial, demo, unavailable, scenario }

/// Maps the backend's `dataStatus` string to [DataStatusKind].
///
/// Unknown or missing values fall back to [DataStatusKind.demo] — the
/// backend's own default — so uncertainty is never hidden behind "live".
DataStatusKind dataStatusFromName(String? name) => switch (name) {
      'live' => DataStatusKind.live,
      'partial' => DataStatusKind.partial,
      'scenario' => DataStatusKind.scenario,
      'unavailable' => DataStatusKind.unavailable,
      _ => DataStatusKind.demo,
    };

/// Why an assistant request failed — drives the localized, user-facing
/// message (no raw exception details ever reach the UI).
enum AssistantErrorKind { network, timeout, server, malformed }

/// Thrown when the backend call fails or returns an unusable answer.
class AssistantApiException implements Exception {
  const AssistantApiException(this.kind);

  final AssistantErrorKind kind;

  @override
  String toString() => 'AssistantApiException($kind)';
}

/// The structured What-If result the backend embeds under
/// `metrics.scenario` — every field is machine-produced by the
/// deterministic scenario engine.
class ScenarioPayload {
  const ScenarioPayload({
    required this.scenarioType,
    required this.status,
    required this.source,
    required this.assumptions,
    required this.inputs,
    required this.outputs,
    required this.limitations,
  });

  /// One of "save_more", "expense_shock", "rate_shock".
  final String scenarioType;

  /// "calculated", "insufficient_context" or "rejected".
  final String status;

  /// Code-controlled provenance label (never LLM-set).
  final String source;

  final Map<String, Object?> assumptions;
  final Map<String, Object?> inputs;
  final Map<String, Object?> outputs;
  final List<String> limitations;

  factory ScenarioPayload.fromJson(Map<String, Object?> json) =>
      ScenarioPayload(
        scenarioType: json['scenario_type'] as String? ?? '',
        status: json['status'] as String? ?? '',
        source: json['source'] as String? ?? '',
        assumptions: _mapOf(json['assumptions']),
        inputs: _mapOf(json['inputs']),
        outputs: _mapOf(json['outputs']),
        limitations: _stringListOf(json['limitations']),
      );

  Map<String, Object?> toJson() => {
        'scenario_type': scenarioType,
        'status': status,
        'source': source,
        'assumptions': assumptions,
        'inputs': inputs,
        'outputs': outputs,
        'limitations': limitations,
      };
}

/// Typed request body for `POST /v1/assistant/chat`.
class AssistantApiRequest {
  const AssistantApiRequest({
    required this.message,
    this.language = 'en',
    this.financialContext,
  });

  final String message;

  /// Backend language code: "en", "ur" or "ur_latn".
  final String language;

  /// Optional personal context built from the saved Financial Profile;
  /// null / empty when no completed profile exists — the backend degrades
  /// gracefully without it.
  final Map<String, Object?>? financialContext;

  Map<String, Object?> toJson() => {
        'message': message,
        'language': language,
        if (financialContext != null && financialContext!.isNotEmpty)
          'financial_context': financialContext,
      };
}

/// Typed response for `POST /v1/assistant/chat`.
class AssistantApiReply {
  const AssistantApiReply({
    required this.answer,
    required this.intent,
    required this.language,
    required this.provider,
    required this.agentsUsed,
    required this.metrics,
    required this.recommendations,
    required this.sources,
    required this.dataStatus,
    required this.scenario,
  });

  final String answer;
  final String intent;
  final String language;

  /// LLM provider that produced the final answer (e.g. "groq").
  final String provider;

  final List<String> agentsUsed;
  final Map<String, Object?> metrics;
  final List<String> recommendations;
  final List<String> sources;
  final DataStatusKind dataStatus;

  /// Present when [dataStatus] is [DataStatusKind.scenario].
  final ScenarioPayload? scenario;

  /// Parses the backend JSON, throwing [FormatException] when the answer is
  /// missing or blank so the caller can surface a friendly error instead of
  /// rendering an empty bubble.
  factory AssistantApiReply.fromJson(Map<String, Object?> json) {
    final answer = json['answer'];
    if (answer is! String || answer.trim().isEmpty) {
      throw const FormatException('Assistant response has no answer.');
    }
    final metrics = _mapOf(json['metrics']);
    final scenarioJson = metrics['scenario'] ?? json['scenario'];
    return AssistantApiReply(
      answer: answer,
      intent: json['intent'] as String? ?? '',
      language: json['language'] as String? ?? 'en',
      provider: json['provider'] as String? ?? '',
      agentsUsed: _stringListOf(json['agentsUsed']),
      metrics: metrics,
      recommendations: _stringListOf(json['recommendations']),
      sources: _stringListOf(json['sources']),
      dataStatus: dataStatusFromName(json['dataStatus'] as String?),
      scenario: scenarioJson is Map
          ? ScenarioPayload.fromJson(_mapOf(scenarioJson))
          : null,
    );
  }

  Map<String, Object?> toJson() => {
        'answer': answer,
        'intent': intent,
        'language': language,
        'provider': provider,
        'agentsUsed': agentsUsed,
        'metrics': metrics,
        'recommendations': recommendations,
        'sources': sources,
        'dataStatus': dataStatus.name,
        if (scenario != null) 'scenario': scenario!.toJson(),
      };
}

// ── JSON helpers ───────────────────────────────────────────────────────────

Map<String, Object?> _mapOf(Object? value) {
  if (value is Map) {
    return value.map((key, item) => MapEntry('$key', item));
  }
  return const {};
}

List<String> _stringListOf(Object? value) {
  if (value is List) {
    return value.whereType<String>().toList();
  }
  return const [];
}
