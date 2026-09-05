import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/l10n_context.dart';
import '../../../domain/entities/assistant_message.dart';
import '../../../l10n/app_localizations.dart';
import '../../finance/finance_category_visuals.dart';
import 'api_reply_content.dart';

// ── Prompt / reply resolution ───────────────────────────────────────────────

/// Localized question text for an intent (starter prompts + follow-up chips).
String assistantPromptText(AppLocalizations l10n, AssistantIntent intent) =>
    switch (intent) {
      AssistantIntent.inflation => l10n.askPromptInflation,
      AssistantIntent.savings => l10n.askPromptSavings,
      AssistantIntent.kibor => l10n.askPromptKibor,
      AssistantIntent.incomeDrop => l10n.askPromptIncomeDrop,
      AssistantIntent.currency => l10n.askPromptCurrency,
      AssistantIntent.health => l10n.askPromptHealth,
      AssistantIntent.goals => l10n.askPromptGoals,
      AssistantIntent.budget => l10n.askPromptBudget,
      AssistantIntent.market => l10n.askPromptMarket,
      AssistantIntent.general => l10n.askPromptGeneral,
    };

/// The suggested starter questions shown before the first message.
const List<AssistantIntent> assistantStarterPrompts = [
  AssistantIntent.inflation,
  AssistantIntent.savings,
  AssistantIntent.kibor,
  AssistantIntent.incomeDrop,
  AssistantIntent.currency,
  AssistantIntent.health,
  AssistantIntent.goals,
  AssistantIntent.general,
];

/// Resolves a structured [AssistantReply] into localized display text by
/// interpolating its pre-formatted params into the template for the intent
/// (choosing "no over-budget" / "no goals" variants where the data says so).
String assistantReplyText(AppLocalizations l10n, AssistantReply reply) {
  String p(String key) => reply.params[key] ?? '';

  String base;
  switch (reply.intent) {
    case AssistantIntent.inflation:
      base = l10n.assistantInflationReply(
        p('inflation'),
        p('essentials'),
        p('pressure'),
        p('capacity'),
      );
    case AssistantIntent.savings:
      if (p('overCount') == '0') {
        base = l10n.assistantSavingsReplyNoOver(
          p('savings'),
          p('rate'),
          p('reduction'),
          p('newSavings'),
        );
      } else {
        base = l10n.assistantSavingsReply(
          p('savings'),
          p('rate'),
          _localizedCategories(l10n, p('overCategories')),
          p('reduction'),
          p('newSavings'),
        );
      }
    case AssistantIntent.budget:
      if (p('overCount') == '0') {
        base = l10n.assistantBudgetReplyNoOver(p('spent'), p('limit'));
      } else {
        base = l10n.assistantBudgetReply(
          p('spent'),
          p('limit'),
          _localizedCategories(l10n, p('overCategories')),
        );
      }
    case AssistantIntent.health:
      base = l10n.assistantHealthReply(p('score'), p('rate'), p('months'));
    case AssistantIntent.goals:
      if (p('count') == '0') {
        base = l10n.assistantGoalsReplyEmpty;
      } else {
        base = l10n.assistantGoalsReply(
          p('count'),
          p('percent'),
          p('topGoal'),
          p('topPercent'),
          p('requiredMonthly'),
        );
      }
    case AssistantIntent.kibor:
      base = l10n.assistantKiborReply(
        p('kibor'),
        p('loanExample'),
        p('perPoint'),
      );
    case AssistantIntent.currency:
      base = l10n.assistantCurrencyReply(p('rate'), p('change'));
    case AssistantIntent.market:
      base = l10n.assistantMarketReply;
    case AssistantIntent.incomeDrop:
      base = l10n.assistantIncomeDropReply(
        p('newIncome'),
        p('newSavings'),
        p('newRate'),
        p('cut'),
        p('restored'),
      );
    case AssistantIntent.general:
      base = l10n.assistantGeneralReply(
        p('inflation'),
        p('rate'),
        p('change'),
        p('kibor'),
      );
  }

  // Append persona perspective when the profile is available.
  final perspective = p('personaPerspective');
  if (perspective.isNotEmpty) {
    return '$base\n\n$perspective';
  }
  return base;
}

/// "transport, shopping" (category ids) → localized category names.
String _localizedCategories(AppLocalizations l10n, String joined) {
  if (joined.trim().isEmpty) return joined;
  return joined
      .split(', ')
      .map((id) => CategoryVisuals.nameOf(l10n, id))
      .join(', ');
}

// ── Widgets ───────────────────────────────────────────────────────────────

/// Small pill marking the chat as running on the demo AI engine.
class DemoAiBadge extends StatelessWidget {
  const DemoAiBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 12, color: scheme.primary),
          const SizedBox(width: 6),
          Text(
            context.l10n.demoAiBadge,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

/// Same pill as [DemoAiBadge], but for the live backend engine.
class LiveAiBadge extends StatelessWidget {
  const LiveAiBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 12, color: scheme.primary),
          const SizedBox(width: 6),
          Text(
            context.l10n.liveAiBadge,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

/// Tappable question chip (starter prompts and follow-ups).
class AssistantPromptChip extends StatelessWidget {
  const AssistantPromptChip({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.35)),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// The user's message: filled bubble on the trailing edge.
class AssistantUserBubble extends StatelessWidget {
  const AssistantUserBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.78;

    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(6),
          ),
        ),
        child: Text(
          message.text,
          style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onPrimary),
        ),
      ),
    );
  }
}

/// The assistant's answer: card-like bubble with reply text, optional
/// personalized insight, follow-up question chips and a trust footer.
class AssistantReplyBubble extends StatelessWidget {
  const AssistantReplyBubble({
    super.key,
    required this.message,
    required this.onPrompt,
  });

  final ChatMessage message;

  /// Sends a tapped follow-up question.
  final ValueChanged<String> onPrompt;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final reply = message.reply!;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.85;
    final secondary =
        isDark ? AppColors.textOnDarkSecondary : AppColors.textOnLightSecondary;
    final tertiary =
        isDark ? AppColors.textOnDarkTertiary : AppColors.textOnLightSecondary;

    // Backend replies render their own rich bubble (answer, scenario card,
    // key numbers, sources, status footer).
    if (reply.api != null) {
      return ApiAssistantBubble(message: message);
    }

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        decoration: assistantBubbleDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              assistantReplyText(l10n, reply),
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
            if (reply.intent == AssistantIntent.savings) ...[
              const SizedBox(height: 12),
              _InsightCard(rate: reply.params['rate'] ?? ''),
            ],
            if (reply.followUps.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                l10n.askFollowUps,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final intent in reply.followUps)
                    AssistantPromptChip(
                      label: assistantPromptText(l10n, intent),
                      onTap: () => onPrompt(assistantPromptText(l10n, intent)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.verified_rounded,
                  size: 12,
                  color: theme.colorScheme.primary.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    l10n.askTrustLine(
                      '${(reply.confidence * 100).round()}',
                    ),
                    style:
                        theme.textTheme.labelSmall?.copyWith(color: tertiary),
                  ),
                ),
                Text(
                  DateFormat('jm').format(message.timestamp),
                  style: theme.textTheme.labelSmall?.copyWith(color: tertiary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Highlighted card inside a reply: a personalized, deterministic insight.
class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.rate});

  /// Pre-formatted savings-rate percentage.
  final String rate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_rounded, size: 14, color: scheme.primary),
              const SizedBox(width: 6),
              Text(
                l10n.askInsightTitle,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.askInsightSavingsBody(rate),
            style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.askInsightAction,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated "Tadbeer is typing…" indicator shown while a reply is prepared.
class AssistantTypingIndicator extends StatefulWidget {
  const AssistantTypingIndicator({super.key});

  @override
  State<AssistantTypingIndicator> createState() =>
      _AssistantTypingIndicatorState();
}

class _AssistantTypingIndicatorState extends State<AssistantTypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tertiary =
        isDark ? AppColors.textOnDarkTertiary : AppColors.textOnLightSecondary;

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: assistantBubbleDecoration(context),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              FadeTransition(
                opacity: _dotOpacity(i),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 10),
            Text(
              l10n.askTyping,
              style: theme.textTheme.labelSmall?.copyWith(color: tertiary),
            ),
          ],
        ),
      ),
    );
  }

  Animation<double> _dotOpacity(int dot) {
    final start = dot * 0.25;
    return Tween(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(
          start,
          (start + 0.5).clamp(0.0, 1.0),
          curve: Curves.easeInOut,
        ),
      ),
    );
  }
}

/// Shared surface for assistant-side bubbles.
BoxDecoration assistantBubbleDecoration(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: isDark ? AppColors.navyCard : AppColors.lightCard,
    borderRadius: const BorderRadius.only(
      topLeft: Radius.circular(18),
      topRight: Radius.circular(18),
      bottomRight: Radius.circular(18),
      bottomLeft: Radius.circular(6),
    ),
    border: Border.all(
      color: isDark ? AppColors.borderDark : AppColors.borderLight,
    ),
  );
}
