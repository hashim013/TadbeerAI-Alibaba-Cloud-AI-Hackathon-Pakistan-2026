import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Ask Tadbeer: the assistant chat.
///
/// Mock replies render structured [AssistantReply] payloads; backend
/// replies (carrying the typed API payload) render their own rich bubble
/// with the What-If scenario card, key numbers, sources and data status.
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
    // Keep the typed text while a reply is being prepared — the send button
    // is disabled then, so this only guards races (e.g. keyboard submit).
    if (ref.read(assistantChatProvider).isResponding) return;
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
    // The assistant only answers from a ready financial + economic context —
    // input stays off until that data is loaded.
    final contextReady = ref.watch(assistantContextProvider) != null;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.askTitle,
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.askSubtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppColors.textOnDarkSecondary
                                : AppColors.textOnLightSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // The pill names the engine honestly — never demo for
                  // live backend answers.
                  ApiConfig.useMockAssistant
                      ? const DemoAiBadge()
                      : const LiveAiBadge(),
                  if (state.messages.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: l10n.askClear,
                      icon: const Icon(Icons.delete_sweep_outlined),
                      onPressed: state.isResponding
                          ? null
                          : () =>
                              ref.read(assistantChatProvider.notifier).clear(),
                    ),
                  ],
                ],
              ),
            ),

            // ── Conversation ──────────────────────────────────────────────
            Expanded(
              child: state.messages.isEmpty
                  ? _AskEmptyState(onPrompt: _send)
                  : _MessageList(state: state, onPrompt: _send),
            ),

            // ── Last error ───────────────────────────────────────────────
            if (state.lastError)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: AppCard(
                  padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
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
                          style: theme.textTheme.bodySmall,
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

            // ── Input bar ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: l10n.whatIfButton,
                    icon: const Icon(Icons.tune_rounded),
                    onPressed: contextReady && !state.isResponding
                        ? () => showWhatIfSheet(context, _send)
                        : null,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      enabled: contextReady,
                      onSubmitted: _send,
                      textInputAction: TextInputAction.send,
                      maxLines: 4,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: contextReady
                            ? l10n.askInputHint
                            : l10n.askPreparing,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ListenableBuilder(
                    listenable: _inputController,
                    builder: (context, _) {
                      final canSend = contextReady &&
                          !state.isResponding &&
                          _inputController.text.trim().isNotEmpty;
                      return IconButton.filled(
                        tooltip: l10n.askSend,
                        onPressed:
                            canSend ? () => _send(_inputController.text) : null,
                        icon: const Icon(Icons.arrow_upward_rounded),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Friendly, localized message for why the last ask failed — raw
  /// exception details never reach the UI.
  String _errorMessage(AppLocalizations l10n, AssistantErrorKind? kind) =>
      switch (kind) {
        AssistantErrorKind.network => l10n.errorAssistantNetwork,
        AssistantErrorKind.timeout => l10n.errorAssistantTimeout,
        AssistantErrorKind.server => l10n.errorAssistantServer,
        AssistantErrorKind.malformed => l10n.errorAssistantMalformed,
        null => l10n.errorTitle,
      };
}

/// Newest-first list (reverse: true keeps it pinned to the bottom edge).
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
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      itemCount: newestFirst.length + (typing ? 1 : 0),
      itemBuilder: (context, index) {
        if (typing && index == 0) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: AssistantTypingIndicator(),
          );
        }
        final message = newestFirst[index - (typing ? 1 : 0)];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
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

/// First-run state: intro copy plus the suggested starter questions.
class _AskEmptyState extends StatelessWidget {
  const _AskEmptyState({required this.onPrompt});

  final ValueChanged<String> onPrompt;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      children: [
        Icon(
          Icons.auto_awesome_rounded,
          size: 44,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 12),
        Text(
          l10n.askEmptyTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(
          l10n.askEmptyBody,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isDark
                ? AppColors.textOnDarkSecondary
                : AppColors.textOnLightSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final intent in assistantStarterPrompts)
              AssistantPromptChip(
                label: assistantPromptText(l10n, intent),
                onTap: () => onPrompt(assistantPromptText(l10n, intent)),
              ),
          ],
        ),
      ],
    );
  }
}
