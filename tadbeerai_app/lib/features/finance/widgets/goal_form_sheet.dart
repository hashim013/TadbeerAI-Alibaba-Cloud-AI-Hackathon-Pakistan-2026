import 'package:flutter/material.dart';

import '../../../core/utils/l10n_context.dart';
import '../../../core/widgets/app_button.dart';
import '../../../domain/entities/goal.dart';
import '../finance_category_visuals.dart';

/// Bottom sheet form to add or edit a savings goal (and delete existing).
///
/// Editing also offers "add funds", which bumps [Goal.savedAmount] — handy
/// for demos and for recording deposits in later phases.
class GoalFormSheet extends StatefulWidget {
  const GoalFormSheet({
    super.key,
    required this.onSubmit,
    this.existing,
    this.onDelete,
  });

  final Goal? existing;
  final Future<void> Function(Goal goal) onSubmit;
  final Future<void> Function()? onDelete;

  @override
  State<GoalFormSheet> createState() => _GoalFormSheetState();
}

class _GoalFormSheetState extends State<GoalFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _targetController;
  late final TextEditingController _savedController;
  late DateTime _targetDate;
  late String _icon;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.title ?? '');
    _targetController = TextEditingController(
        text:
            existing == null ? '' : _stripTrailingZero(existing.targetAmount));
    _savedController = TextEditingController(
        text: existing == null ? '' : _stripTrailingZero(existing.savedAmount));
    _targetDate =
        existing?.targetDate ?? DateTime.now().add(const Duration(days: 365));
    _icon = existing?.icon ?? 'savings';
  }

  static String _stripTrailingZero(double value) {
    final text = value.toString();
    return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _savedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color:
                      theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.existing == null ? l10n.addGoalTitle : l10n.editGoalTitle,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),

            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l10n.fieldGoalName),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? l10n.validationTitleRequired
                  : null,
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _targetController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.fieldTargetAmount,
                prefixText: 'Rs ',
              ),
              validator: _validateTarget,
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _savedController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.fieldSavedAmount,
                prefixText: 'Rs ',
              ),
              validator: _validateSaved,
            ),
            const SizedBox(height: 14),

            // Target date picker.
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(14),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l10n.targetDateLabel,
                  prefixIcon:
                      const Icon(Icons.calendar_today_rounded, size: 20),
                ),
                child: Text(
                    '${_targetDate.day}/${_targetDate.month}/${_targetDate.year}'),
              ),
            ),
            const SizedBox(height: 16),

            // Icon picker.
            Text(l10n.goalIconLabel, style: theme.textTheme.labelLarge),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final choice in CategoryVisuals.goalIconChoices)
                  _IconChoice(
                    icon: choice.icon,
                    selected: choice.key == _icon,
                    onTap: () => setState(() => _icon = choice.key),
                  ),
              ],
            ),
            const SizedBox(height: 22),

            AppButton(
              label: widget.existing == null ? l10n.actionAdd : l10n.actionSave,
              loading: _saving,
              onPressed: _submit,
            ),
            if (widget.existing != null) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _saving ? null : _openAddFunds,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(l10n.addFundsTitle),
              ),
              TextButton(
                onPressed: _confirmDelete,
                child: Text(
                  l10n.actionDelete,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String? _validateTarget(String? value) {
    final l10n = context.l10n;
    final target = double.tryParse((value ?? '').replaceAll(',', '.'));
    if (target == null || target <= 0) return l10n.validationTargetInvalid;
    return null;
  }

  String? _validateSaved(String? value) {
    final l10n = context.l10n;
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final saved = double.tryParse(text.replaceAll(',', '.'));
    if (saved == null || saved < 0) return l10n.validationAmountInvalid;
    final target = double.tryParse(_targetController.text.replaceAll(',', '.'));
    if (target != null && saved > target) {
      return l10n.validationSavedExceeds;
    }
    return null;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate.isAfter(DateTime.now())
          ? _targetDate
          : DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked != null) setState(() => _targetDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final target = double.parse(_targetController.text.replaceAll(',', '.'));
    final savedText = _savedController.text.trim();
    final saved =
        savedText.isEmpty ? 0.0 : double.parse(savedText.replaceAll(',', '.'));

    final goal = (widget.existing ??
            Goal(
              id: 'goal-${DateTime.now().millisecondsSinceEpoch}',
              title: '',
              targetAmount: 1,
              savedAmount: 0,
              targetDate: _targetDate,
            ))
        .copyWith(
      title: _nameController.text.trim(),
      targetAmount: target,
      savedAmount: saved,
      targetDate: _targetDate,
      icon: _icon,
    );

    await widget.onSubmit(goal);
    if (mounted) Navigator.of(context).pop();
  }

  /// Small sheet that adds an amount to the saved total.
  Future<void> _openAddFunds() async {
    final amount = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) =>
          _AddFundsSheet(goalTitle: widget.existing!.title),
    );

    if (amount == null || amount <= 0) return;

    setState(() => _saving = true);
    final existing = widget.existing!;
    final updated = existing.copyWith(
      savedAmount: (existing.savedAmount + amount)
          .clamp(0.0, existing.targetAmount)
          .toDouble(),
    );
    await widget.onSubmit(updated);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _confirmDelete() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteGoalTitle),
        content: Text(l10n.deleteGoalBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    await widget.onDelete?.call();
    if (mounted) Navigator.of(context).pop();
  }
}

class _IconChoice extends StatelessWidget {
  const _IconChoice({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: 0.16)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outline,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Icon(
          icon,
          size: 22,
          color: selected ? scheme.primary : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _AddFundsSheet extends StatefulWidget {
  const _AddFundsSheet({required this.goalTitle});

  final String goalTitle;

  @override
  State<_AddFundsSheet> createState() => _AddFundsSheetState();
}

class _AddFundsSheetState extends State<_AddFundsSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${l10n.addFundsTitle} — ${widget.goalTitle}',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _amountController,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.fieldAmountToAdd,
                prefixText: 'Rs ',
              ),
              validator: (value) {
                final amount =
                    double.tryParse((value ?? '').replaceAll(',', '.'));
                if (amount == null || amount <= 0) {
                  return l10n.validationAmountInvalid;
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
            AppButton(
              label: l10n.actionAdd,
              onPressed: () {
                if (!_formKey.currentState!.validate()) return;
                Navigator.of(context).pop(
                  double.parse(_amountController.text.replaceAll(',', '.')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
