import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_format.dart';
import '../../../core/widgets/app_card.dart';
import '../../../domain/entities/commodity_price.dart';

/// An executive-grade card displaying a single essential commodity and its weekly price movement.
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
      trendColor = isDark ? AppColors.danger : const Color(0xFFDC2626);
      trendIcon = Icons.arrow_upward_rounded;
      changeLabel = '+${commodity.changePercent?.toStringAsFixed(1) ?? '0.0'}%';
    } else if (commodity.isDecreasing) {
      trendColor = isDark ? AppColors.success : const Color(0xFF047857);
      trendIcon = Icons.arrow_downward_rounded;
      changeLabel = '${commodity.changePercent?.toStringAsFixed(1) ?? '0.0'}%';
    } else {
      trendColor = isDark
          ? AppColors.textOnDarkTertiary
          : AppColors.textOnLightSecondary;
      trendIcon = Icons.trending_flat_rounded;
      changeLabel = '0.0%';
    }

    final accentColor = _iconColor(commodity);
    final iconData = _commodityIcon(commodity);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          // ── Category / Commodity Icon with Theme Accent ───────────────────
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: isDark ? 0.16 : 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: accentColor.withValues(alpha: isDark ? 0.28 : 0.20),
                width: 1,
              ),
            ),
            child: Icon(
              iconData,
              color: accentColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // ── Name, Category & Unit ─────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  commodity.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  commodity.unit,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isDark
                        ? AppColors.textOnDarkSecondary
                        : AppColors.textOnLightSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // ── Price & Trend Pill ───────────────────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                CurrencyFormat.pkr(commodity.price),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: trendColor.withValues(alpha: isDark ? 0.16 : 0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(trendIcon, size: 11, color: trendColor),
                    const SizedBox(width: 2.5),
                    Text(
                      changeLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: trendColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 10.5,
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

  IconData _commodityIcon(CommodityPrice item) {
    final norm = item.normalizedName.toLowerCase();
    final id = item.id.toLowerCase();
    if (norm.contains('petrol') || id.contains('petrol')) {
      return Icons.local_gas_station_rounded;
    }
    if (norm.contains('diesel') || id.contains('diesel')) {
      return Icons.oil_barrel_rounded;
    }
    if (norm.contains('lpg') || id.contains('lpg')) {
      return Icons.local_fire_department_rounded;
    }
    if (norm.contains('flour') || id.contains('flour') || norm.contains('atta')) {
      return Icons.grain_rounded;
    }
    if (norm.contains('egg') || id.contains('egg')) {
      return Icons.egg_outlined;
    }
    if (norm.contains('chicken') || id.contains('chicken')) {
      return Icons.restaurant_rounded;
    }
    if (norm.contains('beef') ||
        id.contains('beef') ||
        norm.contains('mutton') ||
        id.contains('mutton')) {
      return Icons.kebab_dining_rounded;
    }
    if (norm.contains('milk') || id.contains('milk')) {
      return Icons.local_drink_rounded;
    }
    if (norm.contains('oil') || id.contains('oil')) {
      return Icons.opacity_rounded;
    }
    if (norm.contains('rice') || id.contains('rice')) {
      return Icons.rice_bowl_rounded;
    }
    if (norm.contains('sugar') || id.contains('sugar')) {
      return Icons.cookie_outlined;
    }
    if (norm.contains('banana') || id.contains('banana')) {
      return Icons.shopping_basket_outlined;
    }
    if (item.category.toLowerCase().contains('pulses') ||
        norm.contains('daal') ||
        norm.contains('pulse')) {
      return Icons.grain_rounded;
    }
    if (item.category.toLowerCase().contains('vegetables') ||
        norm.contains('tomato') ||
        norm.contains('onion') ||
        norm.contains('potato') ||
        norm.contains('garlic')) {
      return Icons.eco_rounded;
    }
    return Icons.shopping_basket_outlined;
  }

  Color _iconColor(CommodityPrice item) {
    final norm = item.normalizedName.toLowerCase();
    final id = item.id.toLowerCase();
    if (norm.contains('petrol') ||
        norm.contains('diesel') ||
        norm.contains('lpg') ||
        id.contains('petrol') ||
        id.contains('diesel')) {
      return const Color(0xFFF59E0B); // Warm Amber / Fuel
    }
    if (norm.contains('flour') ||
        norm.contains('atta') ||
        norm.contains('rice') ||
        norm.contains('sugar')) {
      return const Color(0xFFD97706); // Warm Wheat / Gold
    }
    if (norm.contains('chicken') ||
        norm.contains('beef') ||
        norm.contains('mutton')) {
      return const Color(0xFFEF4444); // Crimson / Meat
    }
    if (norm.contains('egg') || norm.contains('milk')) {
      return const Color(0xFF0284C7); // Cyan / Blue Dairy & Eggs
    }
    if (item.category.toLowerCase().contains('vegetables')) {
      return const Color(0xFF10B981); // Emerald / Fresh Produce
    }
    return const Color(0xFF0D9488); // Teal
  }
}
