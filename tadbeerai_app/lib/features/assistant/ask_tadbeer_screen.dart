import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/api_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/l10n_context.dart';
import '../../../core/widgets/app_card.dart';
import '../../../domain/entities/assistant_api_models.dart';
import '../../../domain/entities/assistant_message.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/assistant_providers.dart';
import 'widgets/assistant_widgets.dart';
import 'widgets/what_if_sheet.dart';

/// Ask Tadbeer: an executive financial AI assistant.
///
/// Features:
/// - Handcrafted fintech command center aesthetic
/// - Context-aware intelligence indicator (Live vs Demo AI)
/// - Categorized smart prompts with dedicated micro-cards
/// - Guided What-If simulation launcher
/// - Docked command-bar with floating high-contrast styling
class AskTadbeerScreen extends ConsumerStatefulWidget {
  const AskTadbeerScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  ConsumerState<AskTadbeerScreen> createState() => _AskTadbeerScreenState();
}

class _AskTadbeerScreenState extends ConsumerState<AskTadbeerScreen> {
  final TextEditingController _inputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _inputController.text = widget.initialQuery!;
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _send(String text) {
    final question = text.trim();
    if (question.isEmpty) return;
    if (ref.read(assistantChatProvider).isResponding) return;
    HapticFeedback.lightImpact();
    _inputController.clear();
    ref.read(assistantChatProvider.notifier).send(
          question,
          language: apiLanguageCode(Localizations.localeOf(context)),
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(assistantChatProvider);
    final contextReady = ref.watch(assistantContextProvider) != null;

    return Scaffold(
      backgroundColor: isDark ? AppColors.navyBg : Colors.transparent,
      body: DecoratedBox(
        decoration: BoxDecoration(
          color: isDark ? AppColors.navyBg : null,
          gradient: isDark ? null : AppColors.lightThemeGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.navyBg : Colors.transparent,
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : AppColors.borderLight,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [AppColors.teal, Color(0xFF10B981)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.teal.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          color: Color(0xFF010717),
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.askTitle,
                            style: GoogleFonts.inter(
                              color:
                                  isDark ? Colors.white : AppColors.textOnLight,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.askSubtitle,
                            style: GoogleFonts.inter(
                              color: isDark
                                  ? AppColors.textOnDarkSecondary
                                  : AppColors.textOnLightSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ApiConfig.useMockAssistant
                        ? const DemoAiBadge()
                        : const LiveAiBadge(),
                    if (state.messages.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: l10n.askClear,
                        icon: Icon(
                          Icons.delete_sweep_outlined,
                          color: isDark
                              ? AppColors.textOnDarkSecondary
                              : AppColors.textOnLightSecondary,
                          size: 20,
                        ),
                        onPressed: state.isResponding
                            ? null
                            : () {
                                HapticFeedback.mediumImpact();
                                ref
                                    .read(assistantChatProvider.notifier)
                                    .clear();
                              },
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: state.messages.isEmpty
                    ? _AskEmptyState(onPrompt: _send)
                    : _MessageList(state: state, onPrompt: _send),
              ),
              if (state.lastError)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  child: AppCard(
                    padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 18,
                          color: AppColors.danger,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage(l10n, state.errorKind),
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color:
                                  isDark ? Colors.white : AppColors.textOnLight,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: state.isResponding
                              ? null
                              : () => ref
                                  .read(assistantChatProvider.notifier)
                                  .retry(),
                          child: Text(l10n.retryAction),
                        ),
                      ],
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.navyCard : AppColors.lightCard,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.10)
                          : AppColors.borderLight,
                      width: 1.2,
                    ),
                    boxShadow: isDark
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.28),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [
                            const BoxShadow(
                              color: AppColors.lightCardShadow,
                              blurRadius: 14,
                              offset: Offset(0, 4),
                            ),
                          ],
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: l10n.whatIfButton,
                        icon: Icon(
                          Icons.tune_rounded,
                          color: contextReady && !state.isResponding
                              ? (isDark
                                  ? AppColors.teal
                                  : const Color(0xFF0D9488))
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.2)
                                  : Colors.black26),
                          size: 20,
                        ),
                        onPressed: contextReady && !state.isResponding
                            ? () {
                                HapticFeedback.lightImpact();
                                showWhatIfSheet(context, _send);
                              }
                            : null,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 8),
                          child: TextField(
                            controller: _inputController,
                            enabled: contextReady,
                            onSubmitted: _send,
                            textInputAction: TextInputAction.send,
                            maxLines: 4,
                            minLines: 1,
                            style: GoogleFonts.inter(
                              color:
                                  isDark ? Colors.white : AppColors.textOnLight,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                            decoration: InputDecoration.collapsed(
                              hintText: contextReady
                                  ? l10n.askInputHint
                                  : l10n.askPreparing,
                              hintStyle: GoogleFonts.inter(
                                color: isDark
                                    ? AppColors.textOnDarkTertiary
                                    : AppColors.textOnLightSecondary,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      ListenableBuilder(
                        listenable: _inputController,
                        builder: (context, _) {
                          final canSend = contextReady &&
                              !state.isResponding &&
                              _inputController.text.trim().isNotEmpty;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 2, right: 2),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: canSend
                                    ? () => _send(_inputController.text)
                                    : null,
                                borderRadius: BorderRadius.circular(20),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: canSend
                                        ? const LinearGradient(
                                            colors: [
                                              AppColors.teal,
                                              Color(0xFF10B981)
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          )
                                        : null,
                                    color: canSend
                                        ? null
                                        : (isDark
                                            ? Colors.white
                                                .withValues(alpha: 0.06)
                                            : const Color(0xFFE2E8F0)),
                                  ),
                                  child: Icon(
                                    Icons.arrow_upward_rounded,
                                    size: 20,
                                    color: canSend
                                        ? const Color(0xFF010717)
                                        : (isDark
                                            ? Colors.white
                                                .withValues(alpha: 0.25)
                                            : Colors.black26),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _errorMessage(AppLocalizations l10n, AssistantErrorKind? kind) =>
      switch (kind) {
        AssistantErrorKind.network => l10n.errorAssistantNetwork,
        AssistantErrorKind.timeout => l10n.errorAssistantTimeout,
        AssistantErrorKind.server => l10n.errorAssistantServer,
        AssistantErrorKind.malformed => l10n.errorAssistantMalformed,
        null => l10n.errorTitle,
      };
}

/// Newest-first conversation list.
class _MessageList extends StatelessWidget {
  const _MessageList({required this.state, required this.onPrompt});

  final AssistantChatState state;
  final ValueChanged<String> onPrompt;

  @override
  Widget build(BuildContext context) {
    final newestFirst = state.messages.reversed.toList();
    final typing = state.isResponding;

    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      itemCount: newestFirst.length + (typing ? 1 : 0),
      itemBuilder: (context, index) {
        if (typing && index == 0) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: AssistantTypingIndicator(),
          );
        }
        final message = newestFirst[index - (typing ? 1 : 0)];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: switch (message.role) {
            ChatRole.user => AssistantUserBubble(message: message),
            ChatRole.assistant => AssistantReplyBubble(
                message: message,
                onPrompt: onPrompt,
              ),
          },
        );
      },
    );
  }
}

/// Modern, simple, and clean empty state with curated 2x2 cards & topic carousel.
class _AskEmptyState extends StatelessWidget {
  const _AskEmptyState({required this.onPrompt});

  final ValueChanged<String> onPrompt;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      children: [
        Center(
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.teal, Color(0xFF10B981)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.teal.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFF010717),
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.askEmptyTitle,
                style: GoogleFonts.inter(
                  color: isDark ? Colors.white : AppColors.textOnLight,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 5),
              Text(
                l10n.askEmptyBody,
                style: GoogleFonts.inter(
                  color: isDark
                      ? AppColors.textOnDarkSecondary
                      : AppColors.textOnLightSecondary,
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      size: 13,
                      color: Color(0xFF10B981),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Tadbeer AI has full context of your income & budgets',
                        style: GoogleFonts.inter(
                          color: isDark
                              ? const Color(0xFF34D399)
                              : const Color(0xFF047857),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'POPULAR TOPICS',
              style: GoogleFonts.inter(
                color: isDark
                    ? AppColors.textOnDarkTertiary
                    : AppColors.textOnLightSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.9,
              ),
            ),
            Text(
              'Tap to ask',
              style: GoogleFonts.inter(
                color: isDark
                    ? AppColors.textOnDarkTertiary
                    : AppColors.textOnLightSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ModernPromptCard(
                title: 'Inflation Shock',
                subtitle: assistantPromptText(l10n, AssistantIntent.inflation),
                icon: Icons.trending_up_rounded,
                accentColor:
                    isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
                onTap: () => onPrompt(
                    assistantPromptText(l10n, AssistantIntent.inflation)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ModernPromptCard(
                title: 'Savings Plan',
                subtitle: assistantPromptText(l10n, AssistantIntent.savings),
                icon: Icons.savings_rounded,
                accentColor: isDark ? AppColors.mint : const Color(0xFF047857),
                onTap: () => onPrompt(
                    assistantPromptText(l10n, AssistantIntent.savings)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ModernPromptCard(
                title: 'KIBOR & Rates',
                subtitle: assistantPromptText(l10n, AssistantIntent.kibor),
                icon: Icons.account_balance_rounded,
                accentColor:
                    isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                onTap: () =>
                    onPrompt(assistantPromptText(l10n, AssistantIntent.kibor)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ModernPromptCard(
                title: l10n.whatIfButton,
                subtitle: 'Simulate income drops or saving more',
                icon: Icons.tune_rounded,
                accentColor: const Color(0xFFA78BFA),
                onTap: () {
                  HapticFeedback.lightImpact();
                  showWhatIfSheet(context, onPrompt);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'EXPLORE MORE',
          style: GoogleFonts.inter(
            color: isDark
                ? AppColors.textOnDarkTertiary
                : AppColors.textOnLightSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.9,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _TopicChip(
                label: 'USD / PKR Rate',
                icon: Icons.currency_exchange_rounded,
                onTap: () => onPrompt(
                    assistantPromptText(l10n, AssistantIntent.currency)),
              ),
              const SizedBox(width: 8),
              _TopicChip(
                label: 'Health & Resilience',
                icon: Icons.shield_rounded,
                onTap: () =>
                    onPrompt(assistantPromptText(l10n, AssistantIntent.health)),
              ),
              const SizedBox(width: 8),
              _TopicChip(
                label: 'Financial Goals',
                icon: Icons.flag_rounded,
                onTap: () =>
                    onPrompt(assistantPromptText(l10n, AssistantIntent.goals)),
              ),
              const SizedBox(width: 8),
              _TopicChip(
                label: 'Economic Overview',
                icon: Icons.auto_awesome_rounded,
                onTap: () => onPrompt(
                    assistantPromptText(l10n, AssistantIntent.general)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ModernPromptCard extends StatelessWidget {
  const _ModernPromptCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.navyCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppColors.borderLight,
          width: 1,
        ),
        boxShadow: isDark
            ? null
            : [
                const BoxShadow(
                  color: AppColors.lightCardShadow,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 17, color: accentColor),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: isDark ? Colors.white : AppColors.textOnLight,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: isDark
                        ? AppColors.textOnDarkSecondary
                        : AppColors.textOnLightSecondary,
                    fontSize: 11,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopicChip extends StatelessWidget {
  const _TopicChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.navyCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : AppColors.borderLight,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isDark ? AppColors.teal : AppColors.tealDeep,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: isDark ? Colors.white : AppColors.textOnLight,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
