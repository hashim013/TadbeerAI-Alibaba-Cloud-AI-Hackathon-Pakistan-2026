import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_format.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/data_status_badge.dart';
import '../../../domain/entities/commodity_price.dart';

/// Modal bottom sheet providing granular economic interpretation and financial
/// impact guidance for an essential commodity.
class CommodityDetailSheet extends StatelessWidget {
  const CommodityDetailSheet({
    super.key,
    required this.commodity,
  });

  final CommodityPrice commodity;

  static Future<void> show(BuildContext context, CommodityPrice commodity) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommodityDetailSheet(commodity: commodity),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color trendColor;
    final String trendText;
    if (commodity.isIncreasing) {
      trendColor = AppColors.danger;
      trendText = '+${commodity.changePercent?.toStringAsFixed(1) ?? '0.0'}% WoW';
    } else if (commodity.isDecreasing) {
      trendColor = AppColors.success;
      trendText = '${commodity.changePercent?.toStringAsFixed(1) ?? '0.0'}% WoW';
    } else {
      trendColor = isDark
          ? AppColors.textOnDarkTertiary
          : AppColors.textOnLightSecondary;
      trendText = '0.0% WoW (Stable)';
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.navyCard : AppColors.lightCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Drag handle ───────────────────────────────────────────────
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.borderDark
                      : AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Header & Status Badge ─────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        commodity.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${commodity.category} • ${commodity.unit}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.textOnDarkTertiary
                              : AppColors.textOnLightSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                DataStatusBadge(status: commodity.dataStatus),
              ],
            ),
            const SizedBox(height: 16),

            // ── Price Card ────────────────────────────────────────────────
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Price',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isDark
                              ? AppColors.textOnDarkTertiary
                              : AppColors.textOnLightSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        CurrencyFormat.pkr(commodity.price),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Weekly Change',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isDark
                              ? AppColors.textOnDarkTertiary
                              : AppColors.textOnLightSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: trendColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          trendText,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: trendColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── What Changed? ─────────────────────────────────────────────
            if (commodity.whatChanged.isNotEmpty) ...[
              const _SectionTitle(title: 'What Changed?'),
              const SizedBox(height: 6),
              Text(
                commodity.whatChanged,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
              ),
              const SizedBox(height: 14),
            ],

            // ── Why It Matters? ───────────────────────────────────────────
            if (commodity.whyItMatters.isNotEmpty) ...[
              const _SectionTitle(title: 'Why It Matters'),
              const SizedBox(height: 6),
              Text(
                commodity.whyItMatters,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.4,
                  color: isDark
                      ? AppColors.textOnDarkSecondary
                      : AppColors.textOnLightSecondary,
                ),
              ),
              const SizedBox(height: 14),
            ],

            // ── Household Impact Hint ─────────────────────────────────────
            if (commodity.financialImpactHint.isNotEmpty) ...[
              const _SectionTitle(title: 'Household Budget Impact'),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        commodity.financialImpactHint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Provenance & Scope ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.navySurface.withValues(alpha: 0.6)
                    : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.verified_outlined,
                    size: 15,
                    color: isDark
                        ? AppColors.textOnDarkTertiary
                        : AppColors.textOnLightSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Source: ${commodity.sourceName} (${commodity.observationPeriod})',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isDark
                            ? AppColors.textOnDarkTertiary
                            : AppColors.textOnLightSecondary,
                        fontSize: 11,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Action Buttons ────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: 'Ask Tadbeer about this price change',
                trailingIcon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                onPressed: () {
                  Navigator.of(context).pop();
                  context.go(
                    '/ask',
                    extra: {
                      'initialQuery':
                          'How will the recent change in ${commodity.name.toLowerCase()} prices affect my monthly budget?'
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.calculate_outlined, size: 18),
                label: const Text('Try a What-If scenario'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  context.go(
                    '/ask',
                    extra: {
                      'initialQuery':
                          'What if my grocery expenses increase by 10%?'
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }
}
