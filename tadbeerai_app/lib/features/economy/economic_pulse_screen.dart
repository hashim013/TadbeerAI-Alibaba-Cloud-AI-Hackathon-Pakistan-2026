import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_format.dart';
import '../../../core/utils/l10n_context.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/data_status_badge.dart';
import '../../../domain/entities/assistant_api_models.dart';
import '../../../domain/entities/economic_indicator.dart';
import '../../../domain/entities/economic_overview.dart';
import '../../../domain/entities/financial_profile.dart';
import '../../../domain/services/economic_impact_service.dart';
import '../../../providers/economic_providers.dart';
import '../../../providers/profile_providers.dart';
import '../finance/widgets/finance_widgets.dart';
import 'widgets/economy_widgets.dart';

/// The Economy tab root: Pakistan's key indicators at a glance with zero data
/// duplication, interactive trend analysis, and comprehensive PBS essential
/// commodity price tracking.
class EconomicPulseScreen extends ConsumerWidget {
  const EconomicPulseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(economicPulseProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.navyBg : Colors.transparent,
      body: SafeArea(
        child: asyncData.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _EconomyErrorView(
            message: context.l10n.errorTitle,
            onRetry: () => ref.invalidate(economicPulseProvider),
          ),
          data: (economy) => _EconomicPulseContent(economy: economy),
        ),
      ),
    );
  }
}

class _EconomicPulseContent extends ConsumerStatefulWidget {
  const _EconomicPulseContent({required this.economy});

  final EconomicOverview economy;

  @override
  ConsumerState<_EconomicPulseContent> createState() =>
      _EconomicPulseContentState();
}

class _EconomicPulseContentState extends ConsumerState<_EconomicPulseContent> {
  late String _selectedIndicatorId;

  @override
  void initState() {
    super.initState();
    // Default to inflation or the first available indicator.
    _selectedIndicatorId = widget.economy.indicators.isNotEmpty
        ? widget.economy.indicators.first.id
        : 'inflation';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final input = ref.watch(economicImpactInputProvider);
    final economy = widget.economy;

    final selectedIndicator = economy.indicatorById(_selectedIndicatorId) ??
        (economy.indicators.isNotEmpty ? economy.indicators.first : null);

    return ListView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        // ── Executive Header ───────────────────────────────────────────────
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            Text(
              l10n.economyPulseTitle,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            DataStatusBadge(status: economy.status),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          l10n.economyPulseSubtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isDark
                ? AppColors.textOnDarkSecondary
                : AppColors.textOnLightSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.mint,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                switch (economy.status) {
                  DataStatusKind.live ||
                  DataStatusKind.partial =>
                    l10n.economyLatestOfficial,
                  _ => l10n.economyUpdatedAt(
                      economyRelativeDayLabel(l10n, economy.updatedAt)),
                },
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isDark
                      ? AppColors.textOnDarkTertiary
                      : AppColors.textOnLightSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── Macroeconomic Intelligence: KPI Matrix (No Duplication) ─────────
        SectionHeader(l10n.economyKeyIndicatorsTitle),
        _buildKpiMatrix(context, economy),
        const SizedBox(height: 12),

        // ── Unified Interactive Trend Explorer ──────────────────────────────
        if (selectedIndicator != null) ...[
          _InteractiveTrendCard(
            indicator: selectedIndicator,
            allIndicators: economy.indicators,
            onSelectIndicator: (id) {
              setState(() => _selectedIndicatorId = id);
            },
            onDeepDive: () {
              context.push('/economy/indicator/${selectedIndicator.id}');
            },
          ),
          const SizedBox(height: 24),
        ],

        // ── Essential Prices — Pakistan (PBS SPI Module) ────────────────────
        const _EssentialPricesSection(),
        const SizedBox(height: 24),

        // ── Personalized Household Impact (Only if finance data exists) ─────
        if (input != null) ...[
          SectionHeader(l10n.economyImpactTitle),
          _ImpactPreviewCard(input: input),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: l10n.economyAskCta,
              onPressed: () => context.go('/ask'),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // ── Institutional Trust & Attribution Footer ────────────────────────
        SourceFooter(
          source:
              economy.indicators.isEmpty ? '' : economy.indicators.first.source,
          status: economy.status,
        ),
      ],
    );
  }

  Widget _buildKpiMatrix(BuildContext context, EconomicOverview economy) {
    // Pick the 4 core headline indicators for high-density, executive presentation
    final headlineIds = ['inflation', 'usdPkr', 'policyRate', 'fxReserves'];
    final headlineIndicators = headlineIds
        .map((id) => economy.indicatorById(id))
        .whereType<EconomicIndicator>()
        .toList();

    // Fallback if indicators have different IDs
    final displayList = headlineIndicators.isNotEmpty
        ? headlineIndicators
        : economy.indicators.take(4).toList();

    return Column(
      children: [
        for (var i = 0; i < displayList.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: _MacroKpiTile(
                    indicator: displayList[i],
                    isSelected: _selectedIndicatorId == displayList[i].id,
                    onTap: () {
                      setState(() => _selectedIndicatorId = displayList[i].id);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: i + 1 < displayList.length
                      ? _MacroKpiTile(
                          indicator: displayList[i + 1],
                          isSelected:
                              _selectedIndicatorId == displayList[i + 1].id,
                          onTap: () {
                            setState(() =>
                                _selectedIndicatorId = displayList[i + 1].id);
                          },
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A dense, executive-styled macroeconomic KPI tile.
class _MacroKpiTile extends StatelessWidget {
  const _MacroKpiTile({
    required this.indicator,
    required this.isSelected,
    required this.onTap,
  });

  final EconomicIndicator indicator;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final isDark = theme.brightness == Brightness.dark;
    final trendColor = economyTrendColor(context, indicator);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.navyCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : (isDark ? AppColors.borderDark : AppColors.borderLight),
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  economyIndicatorIcon(indicator),
                  size: 15,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : (isDark
                          ? AppColors.textOnDarkSecondary
                          : AppColors.textOnLightSecondary),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    economyIndicatorName(l10n, indicator),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isDark
                          ? AppColors.textOnDarkSecondary
                          : AppColors.textOnLightSecondary,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                economyValueLabel(indicator),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  economyChangeLabel(indicator),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: trendColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                if (isSelected)
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A unified interactive trend explorer that allows switching indicators
/// dynamically rather than stacking 5 duplicate charts down the screen.
class _InteractiveTrendCard extends StatelessWidget {
  const _InteractiveTrendCard({
    required this.indicator,
    required this.allIndicators,
    required this.onSelectIndicator,
    required this.onDeepDive,
  });

  final EconomicIndicator indicator;
  final List<EconomicIndicator> allIndicators;
  final ValueChanged<String> onSelectIndicator;
  final VoidCallback onDeepDive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final isDark = theme.brightness == Brightness.dark;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header & Deep Dive Action ────────────────────────────────────
          Row(
            children: [
              Icon(
                economyIndicatorIcon(indicator),
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${economyIndicatorName(l10n, indicator)} 6-Month Trend',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      economyEventPeriodLabel(l10n, indicator),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isDark
                            ? AppColors.textOnDarkTertiary
                            : AppColors.textOnLightSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              TrendChip(indicator: indicator),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                tooltip: 'Indicator Details',
                visualDensity: VisualDensity.compact,
                onPressed: onDeepDive,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Segmented Indicator Selector Pills ───────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: allIndicators.map((item) {
                final isSelected = item.id == indicator.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(economyIndicatorName(l10n, item)),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) onSelectIndicator(item.id);
                    },
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? (isDark ? AppColors.navyBg : Colors.white)
                          : (isDark
                              ? AppColors.textOnDarkSecondary
                              : AppColors.textOnLight),
                    ),
                    selectedColor: theme.colorScheme.primary,
                    backgroundColor:
                        isDark ? AppColors.navyBg : AppColors.lightCard,
                    side: BorderSide(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : (isDark
                              ? AppColors.borderDark
                              : AppColors.borderLight),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    showCheckmark: false,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          // ── The Trend Chart ──────────────────────────────────────────────
          IndicatorTrendChart(indicator: indicator),
        ],
      ),
    );
  }
}

/// The Essential Commodity Prices section: Flour, Eggs, Meat, Petrol, Diesel, etc.
class _EssentialPricesSection extends ConsumerStatefulWidget {
  const _EssentialPricesSection();

  @override
  ConsumerState<_EssentialPricesSection> createState() =>
      _EssentialPricesSectionState();
}

class _EssentialPricesSectionState
    extends ConsumerState<_EssentialPricesSection> {
  bool _expanded = false;

  static const _categories = [
    'All',
    'Food & Staples',
    'Dairy & Poultry',
    'Cooking & Fuel',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;
    final selectedCategory = ref.watch(selectedCommodityCategoryProvider);
    final pricesAsync = ref.watch(essentialPricesProvider);

    return pricesAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, _) => AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 32, color: AppColors.danger),
            const SizedBox(height: 8),
            Text(
              l10n.essentialPricesUnavailable,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => ref.invalidate(essentialPricesProvider),
              child: Text(l10n.retryAction),
            ),
          ],
        ),
      ),
      data: (overview) {
        final items = overview.items;
        // Show initial 6 primary staple items; expand to show all 12
        final visibleItems = _expanded ? items : items.take(6).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Section Title & Status ────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.essentialPricesTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${l10n.essentialPricesSubtitle} • ${overview.period}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isDark
                              ? AppColors.textOnDarkTertiary
                              : AppColors.textOnLightSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                DataStatusBadge(status: overview.status),
              ],
            ),
            const SizedBox(height: 12),

            // ── Category Filter Pills ─────────────────────────────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              child: Row(
                children: _categories.map((category) {
                  final isSelected = selectedCategory == category;
                  final label = switch (category) {
                    'All' => l10n.essentialPricesCategoryAll,
                    'Dairy & Poultry' => l10n.essentialPricesCategoryDairy,
                    'Food & Staples' => l10n.essentialPricesCategoryStaples,
                    'Cooking & Fuel' => l10n.essentialPricesCategoryCookingFuel,
                    _ => category,
                  };
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          ref
                              .read(selectedCommodityCategoryProvider.notifier)
                              .state = category;
                        }
                      },
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? (isDark ? AppColors.navyBg : Colors.white)
                            : (isDark
                                ? AppColors.textOnDark
                                : AppColors.textOnLight),
                      ),
                      selectedColor: theme.colorScheme.primary,
                      backgroundColor:
                          isDark ? AppColors.navyCard : AppColors.lightCard,
                      side: BorderSide(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : (isDark
                                ? AppColors.borderDark
                                : AppColors.borderLight),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      showCheckmark: false,
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),

            // ── Items List ────────────────────────────────────────────────
            if (visibleItems.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    l10n.essentialPricesEmptyCategory,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.textOnDarkTertiary
                          : AppColors.textOnLightSecondary,
                    ),
                  ),
                ),
              )
            else
              ...visibleItems.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: CommodityCard(
                    commodity: item,
                    onTap: () => CommodityDetailSheet.show(context, item),
                  ),
                ),
              ),

            // ── View All Toggle ───────────────────────────────────────────
            if (items.length > 6)
              Center(
                child: TextButton.icon(
                  icon: Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                  ),
                  label: Text(_expanded
                      ? l10n.essentialPricesShowLess
                      : '${l10n.essentialPricesViewAll} (${items.length})'),
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
              ),
            const SizedBox(height: 8),

            // ── Household Budget Impact Card (No Duplication) ─────────────
            AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.essentialPricesWhyTitle,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.essentialPricesWhyBody,
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.chat_bubble_outline_rounded,
                              size: 16),
                          label: Text(
                            l10n.essentialPricesAskImpact,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onPressed: () => context.go(
                            '/ask',
                            extra: {
                              'initialQuery':
                                  'How are recent grocery and essential price changes (flour, petrol, diesel, meat, eggs) affecting my budget?'
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          icon: const Icon(Icons.calculate_outlined, size: 16),
                          label: Text(
                            l10n.essentialPricesTryWhatIf,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onPressed: () => context.go(
                            '/ask',
                            extra: {
                              'initialQuery':
                                  'What if my monthly fuel and grocery expenses increase by 10%?'
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The inflation scenario preview derived from the user's current finances and persona.
class _ImpactPreviewCard extends ConsumerWidget {
  const _ImpactPreviewCard({required this.input});

  final EconomicImpactInput input;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final profile = ref.watch(financialProfileControllerProvider).valueOrNull;
    final impact = EconomicImpactService.inflationImpact(input);
    final delta = (EconomicImpactService.demoInflationDelta * 100).round();

    final persona = profile?.persona;
    final personaLabel = switch (persona) {
      Persona.student => 'Student / Learner',
      Persona.salaried => 'Salaried Professional',
      Persona.businessOwner => 'Business Owner',
      Persona.shopOwner => 'Retailer / Shopkeeper',
      null => null,
    };

    final goalLabel = switch (profile?.primaryGoal) {
      PrimaryGoal.emergencyFund => 'Emergency Fund',
      PrimaryGoal.saveMore => 'Save More',
      PrimaryGoal.education => 'Education',
      PrimaryGoal.newDevice => 'New Device / Equipment',
      PrimaryGoal.businessGrowth => 'Business Growth',
      PrimaryGoal.reduceSpending => 'Reduce Spending',
      PrimaryGoal.other => 'Financial Security',
      null => null,
    };

    final isDeficit = impact.estimatedSavingsCapacity < 0;
    final decisionTitle = isDeficit
        ? 'Strategic Alert: Inflation Pressure Exceeds Buffer'
        : switch (persona) {
            Persona.student =>
              'Strategic Guidance: Student Liquidity & Discretionary Control',
            Persona.businessOwner ||
            Persona.shopOwner =>
              'Strategic Advisory: Commercial Margin & Inventory Buffer',
            Persona.salaried => 'Strategic Decision: Systematic Goal Funding',
            null => 'Strategic Decision: Inflation Absorption Plan',
          };

    final decisionBody = isDeficit
        ? 'Under this +$delta% essential shock, your monthly expenses will exceed your income by ${CurrencyFormat.pkr(impact.estimatedSavingsCapacity.abs())}. Consider curtailing non-essential spends and securing bulk essentials at wholesale prices before projected SPI increases.'
        : switch (persona) {
            Persona.student =>
              'Your low-fixed essential overhead insulates you against macro swings. Preserve your ${CurrencyFormat.pkr(impact.estimatedSavingsCapacity)} monthly margin in liquid savings for upcoming academic milestones.',
            Persona.businessOwner ||
            Persona.shopOwner =>
              'With fuel & transport volatility impacting supply chains, maintain at least 45 days of operating buffer. Re-evaluate supplier contracts and factor an inflation cushion into your retail markup.',
            Persona.salaried =>
              'Your cash flow safely absorbs this shock with ${CurrencyFormat.pkr(impact.estimatedSavingsCapacity)} remaining. Direct this surplus toward your goal${goalLabel != null ? ' ($goalLabel)' : ''} before discretionary drift.',
            null =>
              'Your monthly margin of ${CurrencyFormat.pkr(impact.estimatedSavingsCapacity)} provides resilience against current price fluctuations. Continue routing surplus into emergency reserves.',
          };

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (personaLabel != null || goalLabel != null) ...[
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (personaLabel != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          personaLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (goalLabel != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.info.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.flag_outlined,
                          size: 14,
                          color: AppColors.info,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          goalLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.info,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          ImpactFinanceRows(
            income: input.monthlyIncome,
            expenses: input.monthlyExpenses,
            savings: input.monthlySavings,
          ),
          const Divider(height: 20),
          Text(
            l10n.economyImpactInflationBody(
              delta,
              CurrencyFormat.pkr(impact.estimatedMonthlyPressure),
              CurrencyFormat.pkr(impact.estimatedSavingsCapacity),
              CurrencyFormat.pkr(input.monthlySavings),
            ),
            style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDeficit
                  ? AppColors.danger.withValues(alpha: 0.08)
                  : (isDark
                      ? AppColors.navySurface
                      : AppColors.lightSurfaceVariant.withValues(alpha: 0.35)),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDeficit
                    ? AppColors.danger.withValues(alpha: 0.3)
                    : (isDark ? AppColors.borderDark : AppColors.borderLight),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isDeficit
                          ? Icons.warning_amber_rounded
                          : Icons.lightbulb_outline_rounded,
                      size: 16,
                      color: isDeficit
                          ? AppColors.danger
                          : theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        decisionTitle,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDeficit
                              ? AppColors.danger
                              : (isDark
                                  ? AppColors.textOnDark
                                  : AppColors.textOnLight),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  decisionBody,
                  style: theme.textTheme.bodySmall?.copyWith(
                    height: 1.4,
                    color: isDark
                        ? AppColors.textOnDarkSecondary
                        : AppColors.textOnLightSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.economyImpactDisclaimer,
            style: theme.textTheme.labelSmall?.copyWith(
              color: isDark
                  ? AppColors.textOnDarkTertiary
                  : AppColors.textOnLightSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EconomyErrorView extends StatelessWidget {
  const _EconomyErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.danger),
            const SizedBox(height: 16),
            Text(message, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: Text(l10n.retryAction)),
          ],
        ),
      ),
    );
  }
}
