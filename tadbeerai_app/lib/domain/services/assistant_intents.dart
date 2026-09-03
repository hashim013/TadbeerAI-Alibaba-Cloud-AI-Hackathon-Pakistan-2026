import '../entities/assistant_message.dart';

/// Rule-based intent detection for the mock assistant.
///
/// Keywords are matched case-insensitively (English plus common romanized
/// Urdu spellings); the first rule that matches wins, so detection is fully
/// deterministic and explainable. A later phase replaces this with real
/// language understanding on the backend.
abstract final class AssistantIntents {
  /// Maps a free-form question to the intent the assistant answers with.
  static AssistantIntent detect(String question) {
    final q = question.toLowerCase();

    // KIBOR first: it is a distinctive token that must not fall through to
    // a generic rates/market rule.
    if (_hasAny(q, ['kibor'])) return AssistantIntent.kibor;

    // Income-drop scenarios ("what if my income drops by 10%") before the
    // generic savings/health rules that also mention income.
    if (_hasAny(q, [
      'drop',
      'drops',
      'dropped',
      'cut',
      'cuts',
      'fall',
      'falls',
      'fell',
      'lose my',
      'lost my',
      'reduced',
      'reduction',
    ])) {
      return AssistantIntent.incomeDrop;
    }

    // Goal questions often contain "savings goal" — match goals before
    // savings so "reach my savings goal faster" routes correctly.
    if (_hasAny(q, ['goal', 'goals', 'target', 'maqsad', 'maqasat'])) {
      return AssistantIntent.goals;
    }

    if (_hasAny(q, [
      'inflation',
      'mehngai',
      'mahangai',
      'price',
      'prices',
      'qeematein',
    ])) {
      return AssistantIntent.inflation;
    }

    if (_hasAny(q, [
      'dollar',
      'usd',
      'exchange',
      'currency',
      'rupee',
      'rupees',
      'forex',
    ])) {
      return AssistantIntent.currency;
    }

    if (_hasAny(q, ['save', 'saving', 'savings', 'bachat'])) {
      return AssistantIntent.savings;
    }

    if (_hasAny(q, ['budget', 'budgets', 'limit', 'limits'])) {
      return AssistantIntent.budget;
    }

    // "How am I doing financially?" — note the deliberately narrow "how am
    // i" phrase: a bare "doing" would swallow "How is the market doing?".
    if (_hasAny(q, [
      'health',
      'score',
      'how am i',
      'mera score',
    ])) {
      return AssistantIntent.health;
    }

    if (_hasAny(q, [
      'market',
      'psx',
      'stock',
      'stocks',
      'share',
      'shares',
      'index',
    ])) {
      return AssistantIntent.market;
    }

    return AssistantIntent.general;
  }

  static bool _hasAny(String text, List<String> keywords) =>
      keywords.any(text.contains);
}
