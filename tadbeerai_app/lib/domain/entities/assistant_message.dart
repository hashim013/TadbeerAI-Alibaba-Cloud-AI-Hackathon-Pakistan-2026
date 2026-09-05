import 'assistant_api_models.dart';

/// Which side of the conversation a message belongs to.
enum ChatRole { user, assistant }

/// The categories of questions the mock assistant understands.
enum AssistantIntent {
  inflation,
  savings,
  budget,
  health,
  goals,
  kibor,
  currency,
  market,
  incomeDrop,
  general,
}

/// A structured, deterministic answer produced by the assistant.
///
/// [params] holds pre-formatted values (money, rates, counts) that the UI
/// interpolates into localized templates — the domain never formats copy.
/// [followUps] are intents offered as tappable next questions, and
/// [confidence] is a 0..1 signal shown in the trust footer. Replies that
/// came from the real backend instead carry the typed [api] payload and
/// leave [params]/[followUps]/[confidence] at their defaults.
class AssistantReply {
  const AssistantReply({
    required this.intent,
    required this.params,
    required this.followUps,
    required this.confidence,
    this.api,
  });

  final AssistantIntent intent;

  /// Values interpolated into the localized reply template. Keys that hold
  /// category ids (e.g. 'overCategories') are resolved to localized names by
  /// the UI before interpolation.
  final Map<String, String> params;

  /// Suggested next questions (intents), rendered as tappable chips.
  final List<AssistantIntent> followUps;

  /// 0..1 — how strongly the demo rule matched the question.
  final double confidence;

  /// Typed backend payload when this reply came from the real API
  /// (mock replies leave it null).
  final AssistantApiReply? api;

  Map<String, Object?> toJson() => {
        'intent': intent.name,
        'params': params,
        'followUps': followUps.map((e) => e.name).toList(),
        'confidence': confidence,
        if (api != null) 'api': api!.toJson(),
      };

  factory AssistantReply.fromJson(Map<String, Object?> json) => AssistantReply(
        intent: AssistantIntent.values.firstWhere(
          (e) => e.name == json['intent'],
          orElse: () => AssistantIntent.general,
        ),
        params: (json['params'] as Map?)?.map((k, v) => MapEntry('$k', '$v')) ??
            const {},
        followUps: (json['followUps'] as List?)
                ?.map((e) => AssistantIntent.values.firstWhere(
                      (i) => i.name == e,
                      orElse: () => AssistantIntent.general,
                    ))
                .toList() ??
            const [],
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
        api: json['api'] is Map
            ? AssistantApiReply.fromJson(
                (json['api'] as Map).cast<String, Object?>())
            : null,
      );
}

/// One message in the conversation.
///
/// User messages carry the raw [text]; assistant messages carry a structured
/// [reply] (and an empty [text]) so history stays localizable after locale
/// switches.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.timestamp,
    this.reply,
  });

  final String id;
  final ChatRole role;

  /// The user's input; empty for assistant messages.
  final String text;

  /// Structured payload when [role] is [ChatRole.assistant].
  final AssistantReply? reply;

  final DateTime timestamp;

  Map<String, Object?> toJson() => {
        'id': id,
        'role': role.name,
        'text': text,
        'timestamp': timestamp.toIso8601String(),
        if (reply != null) 'reply': reply!.toJson(),
      };

  factory ChatMessage.fromJson(Map<String, Object?> json) => ChatMessage(
        id: json['id'] as String? ?? '',
        role: json['role'] == 'user' ? ChatRole.user : ChatRole.assistant,
        text: json['text'] as String? ?? '',
        timestamp: json['timestamp'] is String
            ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
            : DateTime.now(),
        reply: json['reply'] is Map
            ? AssistantReply.fromJson(
                (json['reply'] as Map).cast<String, Object?>())
            : null,
      );
}
