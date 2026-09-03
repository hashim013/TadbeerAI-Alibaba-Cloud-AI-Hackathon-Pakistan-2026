import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_format.dart';
import '../../core/utils/l10n_context.dart';
import '../../core/widgets/app_card.dart';
import '../../domain/entities/finance_data.dart';
import '../../domain/entities/financial_profile.dart';
import '../../domain/entities/goal.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/services/finance_calculations.dart';
import '../../domain/services/financial_health_calculator.dart';
import '../../domain/services/insight_generator.dart';
import '../../providers/finance_providers.dart';
import '../../providers/profile_providers.dart';
import '../../features/auth/auth_controller.dart';
import '../../l10n/app_localizations.dart';
import '../finance/finance_category_visuals.dart';
import '../finance/widgets/finance_widgets.dart';

/// The Home tab: a personal financial command center built from demo data.
///
/// Designed with modern fintech aesthetics:
/// - Dynamic time-aware greeting + notification bell
/// - Prominent Financial Health Score card with circular gauge
/// - Pakistan Economic Pulse card with macroeconomic indicators
/// - AI financial intelligence Insight card
/// - Seamless integration with the midnight dark blue theme and l10n.
class HomeDashboardScreen extends ConsumerWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(financeControllerProvider);
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: AppColors.navyBg,
      body: SafeArea(
        child: asyncData.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.teal),
          ),
          error: (error, _) => Center(
            child: Text(
              l10n.errorTitle,
              style: GoogleFonts.inter(color: Colors.white),
            ),
          ),
          data: (data) => _DashboardContent(data: data),
        ),
      ),
    );
  }
}

class _DashboardContent extends ConsumerWidget {
  const _DashboardContent({required this.data});

  final FinanceData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final now = DateTime.now();
    final health = ref.watch(financialHealthProvider);
    final insight = ref.watch(financeInsightProvider);
    final user = ref.watch(authControllerProvider);
    final profileAsync = ref.watch(financialProfileControllerProvider);

    final income = FinanceCalculations.monthlyIncome(data.transactions, now);
    final expenses =
        FinanceCalculations.monthlyExpenses(data.transactions, now);
    final savings = income - expenses;

    return ListView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        // ── 1. Greeting Header & Notification Bell ─────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _greeting(l10n, user?.name, now.hour),
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Here's your financial overview",
                    style: GoogleFonts.inter(
                      color: AppColors.textOnDarkSecondary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            // Notification Bell with green alert dot
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'No new alerts. Your finances are running smoothly!'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.navyCard,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: const Icon(
                        Icons.notifications_none_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    Positioned(
                      top: 1,
                      right: 1,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.navyBg,
                            width: 1.8,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // ── 2. Financial Profile CTA / Status Card ─────────────────────────
        _ProfileCard(profileAsync: profileAsync),
        const SizedBox(height: 16),

        // ── 3. Financial Health Score Card (Gauge + Breakdown) ───────────────
        _HealthCard(health: health),
        const SizedBox(height: 16),

        // ── 4. Pakistan Economic Pulse Card ────────────────────────────────
        const _EconomicPulseCard(),
        const SizedBox(height: 16),

        // ── 5. Today's Insight (AI Financial Intelligence) ─────────────────
        _TodayInsightCard(insight: insight),
        const SizedBox(height: 20),

        // ── 6. This Month Quick Stats (Income / Expenses / Savings) ────────
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: l10n.income,
                value: CurrencyFormat.pkr(income),
                icon: Icons.south_west_rounded,
                color: AppColors.teal,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                label: l10n.expenses,
                value: CurrencyFormat.pkr(expenses),
                icon: Icons.north_east_rounded,
                color: AppColors.danger,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                label: l10n.savings,
                value: CurrencyFormat.pkr(savings),
                icon: Icons.savings_rounded,
                color: AppColors.mint,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // ── 7. Budget progress ─────────────────────────────────────────────
        if (data.budgets.isNotEmpty) ...[
          _BudgetMiniCard(data: data, now: now),
          const SizedBox(height: 18),
        ],

        // ── 8. Savings trend ───────────────────────────────────────────────
        SectionHeader(
          l10n.savingsTrend,
          actionLabel: l10n.viewAll,
          onAction: () => context.push('/finance/finances'),
        ),
        _SavingsMiniChart(
          series: FinanceCalculations.monthlySeries(
            data.transactions,
            from: now,
            monthCount: 4,
          ),
        ),
        const SizedBox(height: 18),

        // ── 9. Recent transactions ─────────────────────────────────────────
        SectionHeader(
          l10n.recentTransactions,
          actionLabel: l10n.viewAll,
          onAction: () => context.push('/finance/expenses'),
        ),
        ..._recentTransactions(data).map(
          (t) => _RecentTransactionRow(transaction: t),
        ),
        const SizedBox(height: 18),

        // ── 10. Goal progress ──────────────────────────────────────────────
        if (data.goals.isNotEmpty) ...[
          SectionHeader(
            l10n.goalProgressTitle,
            actionLabel: l10n.viewAll,
            onAction: () => context.push('/finance/goals'),
          ),
          for (final goal in data.goals.take(2))
            _GoalMiniRow(goal: goal, now: now),
          const SizedBox(height: 18),
        ],

        // ── 11. Quick actions ──────────────────────────────────────────────
        SectionHeader(l10n.quickActions),
        _QuickActions(data: data),
      ],
    );
  }

  List<Transaction> _recentTransactions(FinanceData data) {
    final sorted = [...data.transactions]
      ..sort((a, b) => b.date.compareTo(a.date));
    return sorted.take(4).toList();
  }

  String _greeting(AppLocalizations l10n, String? fullName, int hour) {
    final first = (fullName ?? '').trim().split(RegExp(r'\s+')).first;
    final name = first.isEmpty ? 'Hashim' : first;
    if (hour < 12) return '${l10n.greetingMorning(name)} ☀️';
    if (hour < 17) return '${l10n.greetingAfternoon(name)} 🌤️';
    return '${l10n.greetingEvening(name)} 👋';
  }
}

// ── Financial Health Score Card with Circular Gauge ─────────────────────────

class _HealthCard extends StatelessWidget {
  const _HealthCard({required this.health});

  final FinancialHealthResult? health;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final score = health?.score ?? 72;
    final rating = health?.rating ?? HealthRating.good;
    final ratingLabel = switch (rating) {
      HealthRating.excellent => l10n.ratingExcellent,
      HealthRating.good => l10n.ratingGood,
      HealthRating.fair => l10n.ratingFair,
      HealthRating.needsAttention => l10n.ratingNeedsAttention,
    };

    return AppCard(
      onTap: () => context.push('/finance/health'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.financialHealthTitle,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      text: '$score',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                      ),
                      children: [
                        TextSpan(
                          text: ' /100',
                          style: GoogleFonts.inter(
                            color: AppColors.textOnDarkSecondary,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.40),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      ratingLabel,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF34D399),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              ScoreCircularGauge(score: score, size: 76),
            ],
          ),
        ],
      ),
    );
  }
}

/// Circular Gauge for score display matching modern fintech aesthetic.
class ScoreCircularGauge extends StatelessWidget {
  const ScoreCircularGauge({
    super.key,
    required this.score,
    this.size = 76,
  });

  final int score;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ScoreGaugePainter(
          score: score.clamp(0, 100),
          trackColor: const Color(0xFF162B4D),
        ),
        child: Center(
          child: Text(
            '$score',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreGaugePainter extends CustomPainter {
  const _ScoreGaugePainter({
    required this.score,
    required this.trackColor,
  });

  final int score;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - 8) / 2;
    const strokeWidth = 7.5;

    // Background track ring
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Active progress arc
    if (score > 0) {
      final progressPaint = Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF2DD4BF), Color(0xFF10B981)],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      const startAngle = -math.pi / 2;
      final sweepAngle = (2 * math.pi) * (score / 100);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScoreGaugePainter oldDelegate) =>
      oldDelegate.score != score;
}

// ── Pakistan Economic Pulse Card ────────────────────────────────────────────

class _EconomicPulseCard extends StatelessWidget {
  const _EconomicPulseCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const usdPkr = 277.75;
    const policyRate = 11.50;

    return AppCard(
      onTap: () => context.push('/economy'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pakistan Economic Pulse',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Updated: Today, 10:30 AM',
                    style: GoogleFonts.inter(
                      color: AppColors.textOnDarkSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.trending_up_rounded,
                  color: Color(0xFF10B981),
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _IndicatorRow(
            label: 'Inflation (CPI)',
            value: '5.8%',
            arrowColor: Color(0xFFF87171), // Red for rising inflation
            isUp: true,
          ),
          const SizedBox(height: 14),
          _IndicatorRow(
            label: l10n.indicatorUsdPkr,
            value: usdPkr.toStringAsFixed(2),
            arrowColor: const Color(0xFF34D399), // Green
            isUp: true,
          ),
          const SizedBox(height: 14),
          _IndicatorRow(
            label: l10n.indicatorPolicyRate,
            value: '${policyRate.toStringAsFixed(2)}%',
            arrowColor: const Color(0xFFFBBF24), // Amber/Yellow
            isUp: true,
          ),
          const SizedBox(height: 14),
          const _IndicatorRow(
            label: 'KSE-100 Index',
            value: '80,104',
            arrowColor: Color(0xFFFBBF24), // Amber/Yellow
            isUp: true,
          ),
        ],
      ),
    );
  }
}

class _IndicatorRow extends StatelessWidget {
  const _IndicatorRow({
    required this.label,
    required this.value,
    required this.arrowColor,
    required this.isUp,
  });

  final String label;
  final String value;
  final Color arrowColor;
  final bool isUp;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: AppColors.textOnDarkSecondary,
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
          color: arrowColor,
          size: 16,
        ),
      ],
    );
  }
}

// ── Today's Insight Card ────────────────────────────────────────────────────

class _TodayInsightCard extends StatelessWidget {
  const _TodayInsightCard({this.insight});

  final FinanceInsight? insight;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = insight != null
        ? switch (insight!.type) {
            InsightType.positive =>
              l10n.insightGoodPaceBody(insight!.params['rate'] ?? '0'),
            InsightType.warning => insight!.key == 'overBudget'
                ? l10n.insightOverBudgetBody(
                    int.tryParse(insight!.params['count'] ?? '0') ?? 0)
                : l10n.insightLowSavingsBody(insight!.params['rate'] ?? '0'),
            InsightType.tip =>
              l10n.insightEmergencyBody(insight!.params['months'] ?? '0'),
          }
        : 'Inflation is stable, but rise in USD/PKR may impact your transport and imported goods expenses.';

    return AppCard(
      onTap: () => context.push('/ask'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Today's Insight",
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  text,
                  style: GoogleFonts.inter(
                    color: AppColors.textOnDarkSecondary,
                    fontSize: 14.5,
                    height: 1.45,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.signal_cellular_alt_rounded,
                  color: Color(0xFF10B981),
                  size: 24,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Budget Mini Card ────────────────────────────────────────────────────────

class _BudgetMiniCard extends StatelessWidget {
  const _BudgetMiniCard({required this.data, required this.now});

  final FinanceData data;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final spentByCategory =
        FinanceCalculations.spentByCategory(data.transactions, now);

    final totalLimit =
        data.budgets.fold<double>(0, (sum, b) => sum + b.monthlyLimit);
    final spent = data.budgets
        .fold<double>(0, (sum, b) => sum + (spentByCategory[b.category] ?? 0));
    final utilization = totalLimit > 0 ? spent / totalLimit : 0.0;

    return AppCard(
      onTap: () => context.push('/finance/budget'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.data_usage_rounded,
                  size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child:
                    Text(l10n.budgetLabel, style: theme.textTheme.titleSmall),
              ),
              Text(
                '${(utilization * 100).round()}%',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: budgetUtilizationColor(context, utilization),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ProgressBar(
            value: utilization,
            color: budgetUtilizationColor(context, utilization),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.budgetUsedOf(
              CurrencyFormat.pkr(spent),
              CurrencyFormat.pkr(totalLimit),
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Savings Mini Chart ──────────────────────────────────────────────────────

class _SavingsMiniChart extends StatelessWidget {
  const _SavingsMiniChart({required this.series});

  final List<MonthlyPoint> series;

  static const _monthLabels = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final maxY = series
        .map((p) => math.max(p.income, p.expenses))
        .fold<double>(0, math.max);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: SizedBox(
        height: 140,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxY * 1.15,
            barTouchData: const BarTouchData(enabled: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= series.length) {
                      return const SizedBox.shrink();
                    }
                    final m = series[index].month.month;
                    final label =
                        (m >= 1 && m <= 12) ? _monthLabels[m - 1] : '';
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.textOnDarkSecondary
                              : AppColors.textOnLightSecondary,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            barGroups: [
              for (var i = 0; i < series.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: series[i].income,
                      color: AppColors.teal,
                      width: 9,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    BarChartRodData(
                      toY: series[i].expenses,
                      color: AppColors.danger,
                      width: 9,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Recent Transaction Row ──────────────────────────────────────────────────

class _RecentTransactionRow extends StatelessWidget {
  const _RecentTransactionRow({required this.transaction});

  final Transaction transaction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIncome = transaction.type == TransactionType.income;
    final color = isIncome
        ? AppColors.mint
        : CategoryVisuals.of(transaction.category).color;
    final icon = CategoryVisuals.of(transaction.category).icon;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        onTap: () => context.push('/finance/expenses'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 19, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.title,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    CategoryVisuals.nameOf(context.l10n, transaction.category),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${isIncome ? '+' : '-'}${CurrencyFormat.pkr(transaction.amount)}',
              style: theme.textTheme.titleSmall?.copyWith(
                color: isIncome ? AppColors.mint : theme.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Goal Mini Row ───────────────────────────────────────────────────────────

class _GoalMiniRow extends StatelessWidget {
  const _GoalMiniRow({required this.goal, required this.now});

  final Goal goal;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = FinanceCalculations.goalStatus(goal, now);
    final icon = CategoryVisuals.goalIcon(goal.icon);
    final color = status.isComplete ? AppColors.mint : AppColors.teal;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        onTap: () => context.push('/finance/goals'),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 19, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          goal.title,
                          style: theme.textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${(status.progress * 100).round()}%',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ProgressBar(value: status.progress, color: color, height: 7),
                  const SizedBox(height: 6),
                  Text(
                    '${CurrencyFormat.pkr(goal.savedAmount)} of ${CurrencyFormat.pkr(goal.targetAmount)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Quick Actions ───────────────────────────────────────────────────────────

class _QuickActions extends ConsumerWidget {
  const _QuickActions({required this.data});

  final FinanceData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _ActionChip(
            icon: Icons.remove_circle_outline_rounded,
            label: l10n.actionAddExpense,
            onTap: () => context.push('/finance/expenses'),
          ),
          const SizedBox(width: 8),
          _ActionChip(
            icon: Icons.add_circle_outline_rounded,
            label: l10n.actionAddIncome,
            onTap: () => context.push('/finance/expenses'),
          ),
          const SizedBox(width: 8),
          _ActionChip(
            icon: Icons.flag_outlined,
            label: l10n.actionNewGoal,
            onTap: () => context.push('/finance/goals'),
          ),
          const SizedBox(width: 8),
          _ActionChip(
            icon: Icons.account_balance_wallet_outlined,
            label: l10n.actionViewFinances,
            onTap: () => context.push('/finance/finances'),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: scheme.primary.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: scheme.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Financial Profile integration card ──────────────────────────────────────

/// Shows a CTA to complete the profile when no profile exists or it is
/// incomplete, or a small status card when the profile is completed.
/// Gracefully hides on loading / error so Home is never blocked.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profileAsync});

  final AsyncValue<FinancialProfile?> profileAsync;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // While loading or on error, render nothing — Home must not be blocked.
    final profile = profileAsync.valueOrNull;
    final isCompleted = profile?.profileCompleted == true;

    if (isCompleted) {
      // ── Completed: subtle status row with Edit action ────────────────
      return AppCard(
        onTap: () => context.push('/profile/financial'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.teal.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.fact_check_rounded,
                size: 19,
                color: AppColors.teal,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.homeProfileCompletedTitle,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.homeProfileCompletedBody,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => context.push('/profile/financial'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              child: Text(l10n.homeProfileEditButton),
            ),
          ],
        ),
      );
    }

    // ── Not completed: CTA card ────────────────────────────────────────
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 20,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.homeProfileCtaTitle,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.homeProfileCtaBody,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FilledButton.tonal(
                    onPressed: () => context.push('/profile/financial'),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                    child: Text(l10n.homeProfileCtaButton),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
