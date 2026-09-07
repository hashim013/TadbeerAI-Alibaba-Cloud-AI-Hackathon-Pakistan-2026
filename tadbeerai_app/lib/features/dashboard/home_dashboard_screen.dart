import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_format.dart';
import '../../core/utils/l10n_context.dart';
import '../../core/widgets/app_card.dart';
import '../assistant/widgets/what_if_sheet.dart';
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

/// The Home tab: modern, executive personal financial command center.
///
/// Designed with world-class fintech craftsmanship:
/// - Dynamic time-aware greeting + quick profile avatar
/// - Perfectly aligned 4-action quick launcher (Finance, Economy, Ask Tadbeer, What-If)
/// - Executive Financial Overview Hero Card: Net Savings, single-gauge Financial Health score,
///   and integrated duo-tone cashflow strip (zero duplicate data)
/// - Intelligent contextual AI Insight card with direct exploration CTA
/// - Clean budget pace utilization & recent activity streams
/// - High-contrast legibility across both dark midnight navy & light teal-to-blue themes
class HomeDashboardScreen extends ConsumerWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(financeControllerProvider);
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.navyBg : Colors.transparent,
      body: DecoratedBox(
        decoration: BoxDecoration(
          color: isDark ? AppColors.navyBg : null,
          gradient: isDark ? null : AppColors.lightThemeGradient,
        ),
        child: SafeArea(
          child: asyncData.when(
            loading: () => Center(
              child: CircularProgressIndicator(
                color: isDark ? AppColors.teal : const Color(0xFF0D9488),
              ),
            ),
            error: (error, _) => Center(
              child: Text(
                l10n.errorTitle,
                style: GoogleFonts.inter(
                  color: isDark ? Colors.white : AppColors.textOnLight,
                ),
              ),
            ),
            data: (data) => _DashboardContent(data: data),
          ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final income = FinanceCalculations.monthlyIncome(data.transactions, now);
    final expenses =
        FinanceCalculations.monthlyExpenses(data.transactions, now);
    final savings = income - expenses;

    return ListView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        // ── 1. Greeting Header & Profile Navigation ────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _greetingText(l10n, user?.name, now.hour),
                          style: GoogleFonts.inter(
                            color: isDark ? Colors.white : AppColors.textOnLight,
                            fontSize: 25,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _greetingIcon(now.hour),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Here's your financial overview",
                    style: GoogleFonts.inter(
                      color: isDark
                          ? AppColors.textOnDarkSecondary
                          : AppColors.textOnLightSecondary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            // Notification Bell
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Notifications are active and up to date.'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.navyCard : AppColors.lightCard,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : AppColors.borderLight,
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
                  child: Icon(
                    Icons.notifications_none_rounded,
                    color: isDark ? Colors.white : AppColors.textOnLight,
                    size: 22,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // User Profile Avatar Button
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context.go('/profile'),
                borderRadius: BorderRadius.circular(21),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.navyCard : AppColors.lightCard,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.teal.withValues(alpha: 0.4),
                      width: 1.5,
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
                  child: Center(
                    child: Text(
                      (user?.name.trim().isNotEmpty == true)
                          ? user!.name.trim()[0].toUpperCase()
                          : 'T',
                      style: GoogleFonts.inter(
                        color: isDark ? AppColors.teal : AppColors.tealDeep,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── 2. Financial Profile CTA (hidden once completed) ────────────────
        if (profileAsync.valueOrNull?.profileCompleted != true) ...[
          _ProfileCard(profileAsync: profileAsync),
          const SizedBox(height: 16),
        ],

        // ── 3. Executive Financial Overview Hero Card ───────────────────────
        _FinancialOverviewHeroCard(
          health: health,
          income: income,
          expenses: expenses,
          savings: savings,
        ),
        const SizedBox(height: 16),

        // ── 4. Quick Actions (Finance, Economy, Ask Tadbeer, What-If) ───────
        SectionHeader(l10n.quickActions),
        const _QuickActions(),
        const SizedBox(height: 16),

        // ── 5. Today's AI Insight (Executive Brief) ────────────────────────
        _TodayInsightCard(insight: insight),
        const SizedBox(height: 16),

        // ── 6. Active Budget Utilization ────────────────────────────────────
        if (data.budgets.isNotEmpty) ...[
          _BudgetMiniCard(data: data, now: now),
          const SizedBox(height: 16),
        ],

        // ── 7. Recent Transactions ──────────────────────────────────────────
        SectionHeader(
          l10n.recentTransactions,
          actionLabel: l10n.viewAll,
          onAction: () => context.push('/finance/expenses'),
        ),
        ..._recentTransactions(data).map(
          (t) => _RecentTransactionRow(transaction: t),
        ),
        const SizedBox(height: 16),

        // ── 8. Goal Progress ────────────────────────────────────────────────
        if (data.goals.isNotEmpty) ...[
          SectionHeader(
            l10n.goalProgressTitle,
            actionLabel: l10n.viewAll,
            onAction: () => context.push('/finance/goals'),
          ),
          for (final goal in data.goals.take(2))
            _GoalMiniRow(goal: goal, now: now),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  List<Transaction> _recentTransactions(FinanceData data) {
    final sorted = [...data.transactions]
      ..sort((a, b) => b.date.compareTo(a.date));
    return sorted.take(4).toList();
  }

  String _greetingText(AppLocalizations l10n, String? fullName, int hour) {
    final first = (fullName ?? '').trim().split(RegExp(r'\s+')).first;
    final name = first.isEmpty ? 'Tadbeer' : first;
    if (hour < 12) return l10n.greetingMorning(name);
    if (hour < 17) return l10n.greetingAfternoon(name);
    return l10n.greetingEvening(name);
  }

  Widget _greetingIcon(int hour) {
    if (hour < 12) {
      return const Icon(
        Icons.wb_sunny_rounded,
        color: Color(0xFFF59E0B),
        size: 24,
      );
    }
    if (hour < 17) {
      return const Icon(
        Icons.wb_twilight_rounded,
        color: Color(0xFFFB923C),
        size: 24,
      );
    }
    return const Icon(
      Icons.waving_hand_rounded,
      color: Color(0xFFFBBF24),
      size: 24,
    );
  }
}

// ── Executive Financial Overview Hero Card ──────────────────────────────────

class _FinancialOverviewHeroCard extends StatelessWidget {
  const _FinancialOverviewHeroCard({
    required this.health,
    required this.income,
    required this.expenses,
    required this.savings,
  });

  final FinancialHealthResult? health;
  final double income;
  final double expenses;
  final double savings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final score = health?.score ?? 72;
    final rating = health?.rating ?? HealthRating.good;
    final (ratingLabel, ratingColor) = switch (rating) {
      HealthRating.excellent => (
          l10n.ratingExcellent,
          isDark ? const Color(0xFF34D399) : const Color(0xFF059669)
        ),
      HealthRating.good => (
          l10n.ratingGood,
          isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0D9488)
        ),
      HealthRating.fair => (
          l10n.ratingFair,
          isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706)
        ),
      HealthRating.needsAttention => (
          l10n.ratingNeedsAttention,
          isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626)
        ),
    };

    final savingsRate = income > 0 ? (savings / income * 100).round() : 0;
    final isPositive = savings >= 0;

    return Semantics(
      button: true,
      label: '${l10n.financialHealthTitle}, score $score, $ratingLabel',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            context.push('/finance/health');
          },
          borderRadius: BorderRadius.circular(22),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.navyCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : AppColors.borderLight,
                width: 1,
              ),
              boxShadow: isDark
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : [
                      const BoxShadow(
                        color: AppColors.lightCardShadow,
                        blurRadius: 16,
                        offset: Offset(0, 4),
                      ),
                    ],
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top Header Row: Category Badge & Health Status ──────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color:
                                  (isDark ? AppColors.teal : AppColors.tealDeep)
                                      .withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Icon(
                              Icons.verified_user_rounded,
                              size: 15,
                              color:
                                  isDark ? AppColors.teal : AppColors.tealDeep,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.financialHealthTitle.toUpperCase(),
                              style: GoogleFonts.inter(
                                color: isDark
                                    ? AppColors.textOnDarkSecondary
                                    : AppColors.textOnLightSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Rating Pill with Arrow to show tapability
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: ratingColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: ratingColor.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: ratingColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            ratingLabel,
                            style: GoogleFonts.inter(
                              color: ratingColor,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 9,
                            color: ratingColor,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Main Row: Net Savings Highlight & Single Circular Gauge ─
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Net Monthly Savings',
                            style: GoogleFonts.inter(
                              color: isDark
                                  ? AppColors.textOnDarkSecondary
                                  : AppColors.textOnLightSecondary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            CurrencyFormat.pkr(savings),
                            style: GoogleFonts.inter(
                              color:
                                  isDark ? Colors.white : AppColors.textOnLight,
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: (isPositive
                                      ? (isDark
                                          ? AppColors.mint
                                          : const Color(0xFF059669))
                                      : AppColors.danger)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isPositive
                                      ? Icons.trending_up_rounded
                                      : Icons.trending_down_rounded,
                                  size: 13,
                                  color: isPositive
                                      ? (isDark
                                          ? AppColors.mint
                                          : const Color(0xFF059669))
                                      : AppColors.danger,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    isPositive
                                        ? (income > 0
                                            ? '$savingsRate% saved this month'
                                            : 'Positive cashflow')
                                        : 'Deficit this month',
                                    style: GoogleFonts.inter(
                                      color: isPositive
                                          ? (isDark
                                              ? AppColors.mint
                                              : const Color(0xFF059669))
                                          : AppColors.danger,
                                      fontSize: 11,
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
                    // Circular Gauge showing score exactly ONCE
                    ScoreCircularGauge(score: score, size: 72),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Integrated Cashflow Strip (Income & Expenses) ───────────
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0C192E)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // Income
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981)
                                        .withValues(alpha: 0.16),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.south_west_rounded,
                                    size: 15,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l10n.income,
                                        style: GoogleFonts.inter(
                                          color: isDark
                                              ? AppColors.textOnDarkSecondary
                                              : AppColors.textOnLightSecondary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        CurrencyFormat.pkr(income),
                                        style: GoogleFonts.inter(
                                          color: isDark
                                              ? Colors.white
                                              : AppColors.textOnLight,
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 26,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : const Color(0xFFCBD5E1),
                          ),
                          const SizedBox(width: 10),
                          // Expenses
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444)
                                        .withValues(alpha: 0.16),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.north_east_rounded,
                                    size: 15,
                                    color: Color(0xFFEF4444),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l10n.expenses,
                                        style: GoogleFonts.inter(
                                          color: isDark
                                              ? AppColors.textOnDarkSecondary
                                              : AppColors.textOnLightSecondary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        CurrencyFormat.pkr(expenses),
                                        style: GoogleFonts.inter(
                                          color: isDark
                                              ? Colors.white
                                              : AppColors.textOnLight,
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (income > 0) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: SizedBox(
                            height: 4,
                            child: Row(
                              children: [
                                Flexible(
                                  flex: (expenses.clamp(0, income))
                                      .round()
                                      .clamp(1, 1000000),
                                  child:
                                      Container(color: const Color(0xFFF87171)),
                                ),
                                Flexible(
                                  flex: (savings.clamp(0, income))
                                      .round()
                                      .clamp(1, 1000000),
                                  child:
                                      Container(color: const Color(0xFF34D399)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ScoreGaugePainter(
          score: score.clamp(0, 100),
          trackColor:
              isDark ? const Color(0xFF162B4D) : const Color(0xFFE2E8F0),
        ),
        child: Center(
          child: Text(
            '$score',
            style: GoogleFonts.inter(
              color: isDark ? Colors.white : AppColors.textOnLight,
              fontSize: 19,
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
    const strokeWidth = 7.0;

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

// ── Today's Insight Card (Executive AI Brief) ───────────────────────────────

class _TodayInsightCard extends StatelessWidget {
  const _TodayInsightCard({this.insight});

  final FinanceInsight? insight;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
        : 'Inflation is stable. USD/PKR fluctuations may impact your monthly transportation and imported goods budget.';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.navyCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? AppColors.teal.withValues(alpha: 0.25)
              : AppColors.teal.withValues(alpha: 0.20),
          width: 1.2,
        ),
        boxShadow: isDark
            ? null
            : [
                const BoxShadow(
                  color: AppColors.lightCardShadow,
                  blurRadius: 12,
                  offset: Offset(0, 3),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            context.go('/ask');
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color:
                                  (isDark ? AppColors.teal : AppColors.tealDeep)
                                      .withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.auto_awesome_rounded,
                              size: 16,
                              color:
                                  isDark ? AppColors.teal : AppColors.tealDeep,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'TADBEER AI INSIGHT',
                              style: GoogleFonts.inter(
                                color: isDark
                                    ? AppColors.teal
                                    : AppColors.tealDeep,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.tabAskTadbeer,
                          style: GoogleFonts.inter(
                            color: isDark ? AppColors.teal : AppColors.tealDeep,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: isDark ? AppColors.teal : AppColors.tealDeep,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  text,
                  style: GoogleFonts.inter(
                    color: isDark
                        ? AppColors.textOnDarkSecondary
                        : AppColors.textOnLightSecondary,
                    fontSize: 14,
                    height: 1.45,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final spentByCategory =
        FinanceCalculations.spentByCategory(data.transactions, now);

    final totalLimit =
        data.budgets.fold<double>(0, (sum, b) => sum + b.monthlyLimit);
    final spent = data.budgets
        .fold<double>(0, (sum, b) => sum + (spentByCategory[b.category] ?? 0));
    final utilization = totalLimit > 0 ? spent / totalLimit : 0.0;
    final barColor = budgetUtilizationColor(context, utilization);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.navyCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
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
                  blurRadius: 12,
                  offset: Offset(0, 3),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            context.push('/finance/budget');
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: barColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.pie_chart_outline_rounded,
                        size: 16,
                        color: barColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.budgetLabel,
                        style: GoogleFonts.inter(
                          color: isDark ? Colors.white : AppColors.textOnLight,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: barColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${(utilization * 100).round()}%',
                        style: GoogleFonts.inter(
                          color: barColor,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ProgressBar(
                  value: utilization,
                  color: barColor,
                  height: 6,
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.budgetUsedOf(
                        CurrencyFormat.pkr(spent),
                        CurrencyFormat.pkr(totalLimit),
                      ),
                      style: GoogleFonts.inter(
                        color: isDark
                            ? AppColors.textOnDarkSecondary
                            : AppColors.textOnLightSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 11,
                      color: isDark
                          ? AppColors.textOnDarkTertiary
                          : AppColors.textOnLightSecondary,
                    ),
                  ],
                ),
              ],
            ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isIncome = transaction.type == TransactionType.income;
    final categoryColor = CategoryVisuals.of(transaction.category).color;
    final icon = CategoryVisuals.of(transaction.category).icon;
    final amountColor = isIncome
        ? (isDark ? AppColors.mint : const Color(0xFF059669))
        : (isDark ? Colors.white : AppColors.textOnLight);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
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
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              context.push('/finance/expenses');
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 20, color: categoryColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transaction.title,
                          style: GoogleFonts.inter(
                            color:
                                isDark ? Colors.white : AppColors.textOnLight,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          CategoryVisuals.nameOf(
                              context.l10n, transaction.category),
                          style: GoogleFonts.inter(
                            color: isDark
                                ? AppColors.textOnDarkSecondary
                                : AppColors.textOnLightSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${isIncome ? '+' : '-'}${CurrencyFormat.pkr(transaction.amount)}',
                    style: GoogleFonts.inter(
                      color: amountColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = FinanceCalculations.goalStatus(goal, now);
    final icon = CategoryVisuals.goalIcon(goal.icon);
    final color = status.isComplete
        ? (isDark ? AppColors.mint : const Color(0xFF059669))
        : (isDark ? AppColors.teal : const Color(0xFF0D9488));

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
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
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              context.push('/finance/goals');
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 20, color: color),
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
                                style: GoogleFonts.inter(
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.textOnLight,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${(status.progress * 100).round()}%',
                              style: GoogleFonts.inter(
                                color: color,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ProgressBar(
                            value: status.progress, color: color, height: 6),
                        const SizedBox(height: 6),
                        Text(
                          '${CurrencyFormat.pkr(goal.savedAmount)} of ${CurrencyFormat.pkr(goal.targetAmount)}',
                          style: GoogleFonts.inter(
                            color: isDark
                                ? AppColors.textOnDarkSecondary
                                : AppColors.textOnLightSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Quick Actions (Powerhouse Shortcuts) ───────────────────────────────────

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.navyCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(22),
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
                  blurRadius: 12,
                  offset: Offset(0, 3),
                ),
              ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Finance
          Expanded(
            child: _QuickActionTile(
              label: l10n.tabFinance,
              icon: Icons.account_balance_wallet_rounded,
              iconColor: isDark ? AppColors.teal : const Color(0xFF0D9488),
              iconBgColor: isDark ? AppColors.teal : const Color(0xFFE6F8F5),
              borderColor: isDark
                  ? AppColors.teal.withValues(alpha: 0.35)
                  : const Color(0x330D9488),
              onTap: () => context.go('/finance'),
            ),
          ),
          // 2. Economy
          Expanded(
            child: _QuickActionTile(
              label: l10n.tabEconomy,
              icon: Icons.insights_rounded,
              iconColor:
                  isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
              iconBgColor:
                  isDark ? const Color(0xFF2563EB) : const Color(0xFFEFF4FE),
              borderColor: isDark
                  ? const Color(0xFF2563EB).withValues(alpha: 0.45)
                  : const Color(0x332563EB),
              onTap: () => context.go('/economy'),
            ),
          ),
          // 3. Ask Tadbeer
          Expanded(
            child: _QuickActionTile(
              label: l10n.tabAskTadbeer,
              icon: Icons.auto_awesome_rounded,
              iconColor: isDark ? AppColors.mint : const Color(0xFF0284C7),
              iconBgColor: isDark ? AppColors.mint : const Color(0xFFE0F2FE),
              borderColor: isDark
                  ? AppColors.mint.withValues(alpha: 0.35)
                  : const Color(0x330284C7),
              onTap: () => context.go('/ask'),
            ),
          ),
          // 4. What-If
          Expanded(
            child: _QuickActionTile(
              label: l10n.whatIfButton,
              icon: Icons.lightbulb_rounded,
              iconColor:
                  isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED),
              iconBgColor:
                  isDark ? const Color(0xFF7C3AED) : const Color(0xFFF3E8FF),
              borderColor: isDark
                  ? const Color(0xFF7C3AED).withValues(alpha: 0.45)
                  : const Color(0x337C3AED),
              onTap: () {
                showWhatIfSheet(
                  context,
                  (query) => context.go('/ask', extra: query),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.borderColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final Color borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(16),
          splashColor: iconColor.withValues(alpha: 0.16),
          highlightColor: iconColor.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Fixed-size squircle icon container
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isDark
                        ? iconBgColor.withValues(alpha: 0.14)
                        : iconBgColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: borderColor,
                      width: 1.2,
                    ),
                    boxShadow: isDark
                        ? null
                        : [
                            BoxShadow(
                              color: iconColor.withValues(alpha: 0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      color: iconColor,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Fixed-height text container ensuring mathematical vertical alignment
                SizedBox(
                  height: 32,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: isDark ? Colors.white : AppColors.textOnLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                        height: 1.15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Financial Profile integration card ──────────────────────────────────────

/// Shows a CTA to complete the profile when no profile exists or it is
/// incomplete, or hides when the profile is completed.
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
      // Once completed, do not show edit card on homescreen (available in Profile tab).
      return const SizedBox.shrink();
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
