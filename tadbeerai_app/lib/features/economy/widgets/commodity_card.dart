import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_format.dart';
import '../../../core/widgets/app_card.dart';
import '../../../domain/entities/commodity_price.dart';

/// A card displaying a single essential commodity and its weekly price movement.
class CommodityCard extends StatelessWidget {
  const CommodityCard({
    super.key,
    required this.commodity,
    required this.onTap,
  });

  final CommodityPrice commodity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color trendColor;
    final IconData trendIcon;
    final String changeLabel;

    if (commodity.isIncreasing) {
      trendColor = AppColors.danger;
      trendIcon = Icons.arrow_upward_rounded;
      changeLabel = '+${commodity.changePercent?.toStringAsFixed(1) ?? '0.0'}%';
    } else if (commodity.isDecreasing) {
      trendColor = AppColors.success;
      trendIcon = Icons.arrow_downward_rounded;
      changeLabel = '${commodity.changePercent?.toStringAsFixed(1) ?? '0.0'}%';
    } else {
      trendColor = isDark
          ? AppColors.textOnDarkTertiary
          : AppColors.textOnLightSecondary;
      trendIcon = Icons.trending_flat_rounded;
      changeLabel = '0.0%';
    }

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          // ── Category / Commodity Icon ─────────────────────────────────────
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _categoryIcon(commodity.category),
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // ── Name & Unit ──────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  commodity.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  commodity.unit,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isDark
                        ? AppColors.textOnDarkTertiary
                        : AppColors.textOnLightSecondary,
                  ),
                ),
              ],
            ),
          ),

          // ── Price & Trend Pill ───────────────────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                CurrencyFormat.pkr(commodity.price),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: trendColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(trendIcon, size: 12, color: trendColor),
                    const SizedBox(width: 2),
                    Text(
                      changeLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: trendColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'vegetables':
        return Icons.eco_rounded;
      case 'dairy & poultry':
        return Icons.egg_outlined;
      case 'food & staples':
        return Icons.bakery_dining_outlined;
      case 'pulses':
        return Icons.grain_rounded;
      case 'cooking & fuel':
        return Icons.local_gas_station_rounded;
      default:
        return Icons.shopping_basket_outlined;
    }
  }
}
