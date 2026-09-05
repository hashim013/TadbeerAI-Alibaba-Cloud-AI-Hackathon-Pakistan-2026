import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/l10n_context.dart';
import '../../../domain/services/what_if_request.dart';

/// Opens the guided What-If builder. [onSend] receives the natural-language
/// question built from the guided inputs — sending it is the caller's job
/// (it flows through the normal chat pipeline to the backend).
Future<void> showWhatIfSheet(
  BuildContext context,
  ValueChanged<String> onSend,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _WhatIfSheet(onSend: onSend),
  );
}

class _WhatIfSheet extends StatefulWidget {
  const _WhatIfSheet({required this.onSend});

  final ValueChanged<String> onSend;

  @override
  State<_WhatIfSheet> createState() => _WhatIfSheetState();
}

class _WhatIfSheetState extends State<_WhatIfSheet> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _monthsController = TextEditingController();

  WhatIfKind _kind = WhatIfKind.saveMore;
  bool _increase = true;
  String? _error;

  static const _maxMonths = 600;

  @override
  void dispose() {
    _amountController.dispose();
    _monthsController.dispose();
    super.dispose();
  }

  void _run() {
    final l10n = context.l10n;
    final amount = double.tryParse(_amountController.text.trim());

    if (_kind == WhatIfKind.saveMore) {
      if (amount == null || amount <= 0) {
        setState(() => _error = l10n.whatIfInvalidAmount);
        return;
      }
      final monthsText = _monthsController.text.trim();
      int? months;
      if (monthsText.isNotEmpty) {
        months = int.tryParse(monthsText);
        if (months == null || months < 1 || months > _maxMonths) {
          setState(() => _error = l10n.whatIfMonthsInvalid);
          return;
        }
      }
      _submit(buildWhatIfMessage(
        kind: WhatIfKind.saveMore,
        amount: amount,
        months: months,
      ));
    } else {
      if (amount == null || amount <= 0 || amount > 100) {
        setState(() => _error = l10n.whatIfInvalidPercent);
        return;
      }
      _submit(buildWhatIfMessage(
        kind: _kind,
        amount: amount,
        increase: _increase,
      ));
    }
  }

  void _submit(String message) {
    Navigator.of(context).pop();
    widget.onSend(message);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary =
        isDark ? AppColors.textOnDarkSecondary : AppColors.textOnLightSecondary;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        // Keeps the sheet above the keyboard.
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded,
                  size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(l10n.whatIfTitle, style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.whatIfSubtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: secondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<WhatIfKind>(
            segments: [
              ButtonSegment(
                value: WhatIfKind.saveMore,
                label: Text(l10n.whatIfSaveMore),
                icon: const Icon(Icons.savings_rounded, size: 16),
              ),
              ButtonSegment(
                value: WhatIfKind.expenseChange,
                label: Text(l10n.whatIfExpenseChange),
                icon: const Icon(Icons.trending_up_rounded, size: 16),
              ),
              ButtonSegment(
                value: WhatIfKind.rateChange,
                label: Text(l10n.whatIfRateChange),
                icon: const Icon(Icons.percent_rounded, size: 16),
              ),
            ],
            selected: {_kind},
            onSelectionChanged: (selection) => setState(() {
              _kind = selection.first;
              _error = null;
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: _kind == WhatIfKind.saveMore
                  ? l10n.whatIfAmountLabel
                  : _kind == WhatIfKind.rateChange
                      ? l10n.whatIfPointsLabel
                      : l10n.whatIfPercentLabel,
            ),
          ),
          if (_kind == WhatIfKind.saveMore) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _monthsController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.whatIfMonthsLabel,
                hintText: l10n.whatIfMonthsHint,
              ),
            ),
          ],
          if (_kind != WhatIfKind.saveMore) ...[
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: true,
                  label: Text(l10n.whatIfIncrease),
                  icon: const Icon(Icons.north_rounded, size: 16),
                ),
                ButtonSegment(
                  value: false,
                  label: Text(l10n.whatIfDecrease),
                  icon: const Icon(Icons.south_rounded, size: 16),
                ),
              ],
              selected: {_increase},
              onSelectionChanged: (selection) =>
                  setState(() => _increase = selection.first),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style:
                  theme.textTheme.bodySmall?.copyWith(color: AppColors.danger),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _run,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(l10n.whatIfRun),
            ),
          ),
        ],
      ),
    );
  }
}
