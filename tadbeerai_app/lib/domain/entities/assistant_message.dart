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
/// [confidence] is a 0..1 signal shown in the trust footer.
///
/// This shape mirrors what a future real backend will return, so Phase 5 can
/// swap the mock without touching the chat UI.
class AssistantReply {
  const AssistantReply({
    required this.intent,
    required this.params,
    required this.followUps,
    required this.confidence,
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
}
