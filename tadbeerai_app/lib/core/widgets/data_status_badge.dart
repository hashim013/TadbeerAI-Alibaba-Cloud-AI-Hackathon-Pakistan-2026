import 'package:flutter/material.dart';

import '../../domain/entities/assistant_api_models.dart';
import '../theme/app_colors.dart';
import '../utils/l10n_context.dart';

/// Reusable provenance pill for the backend's data status.
///
/// Uncertainty is never hidden: "live" is only shown when the backend
/// marked the data live, and a scenario is always labelled as the user's
/// assumption — never a forecast.
class DataStatusBadge extends StatelessWidget {
  const DataStatusBadge({super.key, required this.status});

  final DataStatusKind status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    final (label, color, icon) = switch (status) {
      DataStatusKind.live => (
          l10n.dataStatusLive,
          AppColors.success,
          Icons.bolt_rounded,
        ),
      DataStatusKind.partial => (
          l10n.dataStatusPartial,
          AppColors.warning,
          Icons.warning_amber_rounded,
        ),
      DataStatusKind.demo => (
          l10n.dataStatusDemo,
          AppColors.info,
          Icons.science_outlined,
        ),
      DataStatusKind.scenario => (
          l10n.dataStatusScenario,
          AppColors.warning,
          Icons.tune_rounded,
        ),
      DataStatusKind.unavailable => (
          l10n.dataStatusUnavailable,
          AppColors.danger,
          Icons.cloud_off_rounded,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
