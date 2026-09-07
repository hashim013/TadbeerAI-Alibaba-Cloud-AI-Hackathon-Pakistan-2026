import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/l10n_context.dart';
import '../../../domain/services/financial_health_calculator.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/finance_providers.dart';
import 'widgets/finance_widgets.dart';

/// The Financial Health Score screen with a modern, human-crafted fintech design:
/// - Precision-calibrated radial dial with micro-ticks, radial glow, and dynamic resilience tier
/// - High-density 3-stat metric strip (Savings Rate, Emergency Buffer, Budget Adherence)
/// - 5 Core Financial Resilience Pillars with live metric readouts, dual-tone progress bars,
///   weight badges, and expandable deep dives with actionable improvement tips
/// - Score Optimizer with targeted high-impact point levers and direct What-If simulator launch
/// - Transparent, deterministic scoring methodology card
/// - Floating executive copilot consultation dock
/// - Full theme support for Midnight Navy dark mode and Teal-to-Blue light mode
class FinancialHealthScreen extends ConsumerWidget {
  const FinancialHealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(financeControllerProvider);
    final health = ref.watch(financialHealthProvider);
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.navyBg : Colors.transparent,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.navyBg : Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white : AppColors.textOnLight,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          l10n.financialHealthTitle,
          style: GoogleFonts.inter(
            color: isDark ? Colors.white : AppColors.textOnLight,
            fontSize: 18.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: l10n.howScoreWorks,
            icon: Icon(
              Icons.help_outline_rounded,
              color: isDark
                  ? AppColors.textOnDarkSecondary
                  : AppColors.textOnLightSecondary,
              size: 22,
            ),
            onPressed: () => _showMethodologySheet(context, l10n, isDark),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          color: isDark ? AppColors.navyBg : null,
          gradient: isDark ? null : AppColors.lightThemeGradient,
        ),
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
          data: (data) {
            if (health == null) {
              return Center(
                child: CircularProgressIndicator(
                  color: isDark ? AppColors.teal : const Color(0xFF0D9488),
                ),
              );
            }

            // Order components consistently:
            // 1. Savings, 2. Budget Discipline, 3. Emergency Fund, 4. Goal Progress, 5. Spending
            const order = [
              'savings',
              'budget',
              'emergency',
              'goals',
              'spending'
            ];
            final sortedComponents = [...health.components]..sort((a, b) {
                final indexA = order.indexOf(a.key);
                final indexB = order.indexOf(b.key);
                return (indexA == -1 ? 99 : indexA)
                    .compareTo(indexB == -1 ? 99 : indexB);
              });

            // Locate components for the quick metrics strip
            HealthComponent? findComp(String k) {
              for (final c in health.components) {
                if (c.key == k) return c;
              }
              return null;
            }

            final savingsComp = findComp('savings');
            final budgetComp = findComp('budget');
            final emergencyComp = findComp('emergency');

            // Find lowest component for score optimizer
            HealthComponent? lowestComp;
            for (final c in health.components) {
              if (lowestComp == null || c.score < lowestComp.score) {
                lowestComp = c;
              }
            }

            return Column(
              children: [
                Expanded(
                  child: ListView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    children: [
                      // ── 1. Hero Calibrated Gauge ───────────────────────────
                      Center(
                        child: HealthScoreGauge(
                          score: health.score,
                          ratingLabel: _ratingLabel(l10n, health.score),
                          size: 204,
                        ),
                      ),
                      const SizedBox(height: 18),

                      // ── 2. High-Density 3-Stat Metric Strip ────────────────
                      _HeroMetricStrip(
                        savingsComp: savingsComp,
                        emergencyComp: emergencyComp,
                        budgetComp: budgetComp,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 24),

                      // ── 3. Score Optimizer / High-Impact Opportunity ──────
                      if (lowestComp != null && health.score < 90) ...[
                        _ScoreOptimizerCard(
                          lowestComponent: lowestComp,
                          overallScore: health.score,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 24),
                      ],

                      // ── 4. 5 Core Financial Resilience Pillars ─────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'RESILIENCE PILLARS',
                            style: GoogleFonts.inter(
                              color: isDark
                                  ? AppColors.textOnDarkSecondary
                                  : AppColors.textOnLightSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                            ),
                          ),
                          Text(
                            '100% Deterministic',
                            style: GoogleFonts.inter(
                              color: isDark
                                  ? AppColors.teal
                                  : const Color(0xFF0D9488),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      ...sortedComponents.map(
                        (component) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _PillarCard(
                            component: component,
                            isDark: isDark,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── 5. How It Works Transparency Card ──────────────────
                      _MethodologyCard(
                        title: l10n.howScoreWorks,
                        body: l10n.howScoreWorksBody,
                        isDark: isDark,
                        onViewDetails: () =>
                            _showMethodologySheet(context, l10n, isDark),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),

                // ── 6. Pinned Executive Copilot Dock ─────────────────────────
                _ExecutiveCopilotDock(
                  isDark: isDark,
                  score: health.score,
                  lowestKey: lowestComp?.key ?? 'savings',
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _ratingLabel(AppLocalizations l10n, int score) {
    if (score >= 85) return l10n.ratingExcellent;
    if (score >= 65) return l10n.ratingGood;
    if (score >= 45) return l10n.ratingFair;
    return l10n.ratingNeedsAttention;
  }

  static void _showMethodologySheet(
      BuildContext context, AppLocalizations l10n, bool isDark) {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _MethodologyModalSheet(isDark: isDark, l10n: l10n),
    );
  }
}

// ── Hero Calibrated Health Score Gauge ──────────────────────────────────────

class HealthScoreGauge extends StatelessWidget {
  const HealthScoreGauge({
    super.key,
    required this.score,
    required this.ratingLabel,
    this.size = 196,
  });

  final int score;
  final String ratingLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (tierColor, tierBadge) = _tierDetails(score);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CalibratedGaugePainter(
          score: score.clamp(0, 100),
          isDark: isDark,
          accentColor: tierColor,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Resilience Tier Sub-badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: tierColor.withValues(alpha: isDark ? 0.16 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: tierColor.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: tierColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      tierBadge.toUpperCase(),
                      style: GoogleFonts.inter(
                        color: tierColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),

              // Score Number & Denominator
              Text.rich(
                TextSpan(
                  text: '$score',
                  style: GoogleFonts.inter(
                    color: isDark ? Colors.white : AppColors.textOnLight,
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.5,
                  ),
                  children: [
                    TextSpan(
                      text: ' /100',
                      style: GoogleFonts.inter(
                        color: isDark
                            ? AppColors.textOnDarkSecondary
                            : AppColors.textOnLightSecondary,
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),

              // Localized Rating Label (Excellent, Good, Fair, Needs Attention)
              Text(
                ratingLabel,
                style: GoogleFonts.inter(
                  color: tierColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static (Color, String) _tierDetails(int score) {
    if (score >= 85) {
      return (const Color(0xFF10B981), 'Resilient');
    }
    if (score >= 65) {
      return (const Color(0xFF2DD4BF), 'Stable');
    }
    if (score >= 45) {
      return (const Color(0xFFF59E0B), 'Moderate');
    }
    return (const Color(0xFFEF4444), 'Vulnerable');
  }
}

class _CalibratedGaugePainter extends CustomPainter {
  const _CalibratedGaugePainter({
    required this.score,
    required this.isDark,
    required this.accentColor,
  });

  final int score;
  final bool isDark;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const strokeWidth = 13.0;
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    // 1. Subtle Calibrated Micro-Ticks (like a Swiss instrument)
    final tickRadius = radius + 4;
    const totalTicks = 60;
    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < totalTicks; i++) {
      final angle = (2 * math.pi) * (i / totalTicks) - math.pi / 2;
      final isMajor = i % 12 == 0; // major tick every 20%
      final tickLength = isMajor ? 5.5 : 3.0;

      tickPaint.strokeWidth = isMajor ? 1.5 : 0.9;
      tickPaint.color = isMajor
          ? (isDark
              ? Colors.white.withValues(alpha: 0.25)
              : const Color(0xFF94A3B8))
          : (isDark
              ? Colors.white.withValues(alpha: 0.10)
              : const Color(0xFFCBD5E1));

      final startOffset = Offset(
        center.dx + (tickRadius + 1) * math.cos(angle),
        center.dy + (tickRadius + 1) * math.sin(angle),
      );
      final endOffset = Offset(
        center.dx + (tickRadius + 1 + tickLength) * math.cos(angle),
        center.dy + (tickRadius + 1 + tickLength) * math.sin(angle),
      );
      canvas.drawLine(startOffset, endOffset, tickPaint);
    }

    // 2. Background Track Ring
    final trackColor =
        isDark ? const Color(0xFF0C1B2F) : const Color(0xFFE2E8F0);
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // 3. Active Progress Arc with Gradient
    if (score > 0) {
      final gradientColors = score >= 65
          ? [const Color(0xFF2DD4BF), const Color(0xFF10B981)]
          : (score >= 45
              ? [const Color(0xFFFBBF24), const Color(0xFFF59E0B)]
              : [const Color(0xFFF87171), const Color(0xFFEF4444)]);

      final progressPaint = Paint()
        ..shader = LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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
  bool shouldRepaint(covariant _CalibratedGaugePainter oldDelegate) =>
      oldDelegate.score != score ||
      oldDelegate.isDark != isDark ||
      oldDelegate.accentColor != accentColor;
}

// ── High-Density 3-Stat Metric Strip ────────────────────────────────────────

class _HeroMetricStrip extends StatelessWidget {
  const _HeroMetricStrip({
    required this.savingsComp,
    required this.emergencyComp,
    required this.budgetComp,
    required this.isDark,
  });

  final HealthComponent? savingsComp;
  final HealthComponent? emergencyComp;
  final HealthComponent? budgetComp;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final savingsRate = savingsComp?.detailParams['rate'] ?? '0%';
    final emergencyMonths = emergencyComp?.detailParams['months'] ?? '0.0';
    final onTrack = budgetComp?.detailParams['onTrack'] ?? '0';
    final totalBudgets = budgetComp?.detailParams['total'] ?? '0';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.navyCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppColors.borderLight,
          width: 1.2,
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
      child: Row(
        children: [
          // 1. Savings Rate Metric
          Expanded(
            child: _MetricItem(
              label: 'Savings Rate',
              value: savingsRate,
              benchmark: 'Ideal ≥ 20%',
              color: const Color(0xFF10B981),
              isDark: isDark,
            ),
          ),
          _verticalDivider(isDark),

          // 2. Emergency Cushion Metric
          Expanded(
            child: _MetricItem(
              label: 'Emergency',
              value: '$emergencyMonths mo',
              benchmark: 'Target 6.0 mo',
              color: const Color(0xFF0EA5E9),
              isDark: isDark,
            ),
          ),
          _verticalDivider(isDark),

          // 3. Budget Discipline Metric
          Expanded(
            child: _MetricItem(
              label: 'Budgets',
              value: '$onTrack/$totalBudgets',
              benchmark: 'On Track',
              color: const Color(0xFF8B5CF6),
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider(bool isDark) {
    return Container(
      width: 1,
      height: 38,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color:
          isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.borderLight,
    );
  }
}

class _MetricItem extends StatelessWidget {
  const _MetricItem({
    required this.label,
    required this.value,
    required this.benchmark,
    required this.color,
    required this.isDark,
  });

  final String label;
  final String value;
  final String benchmark;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: isDark
                ? AppColors.textOnDarkSecondary
                : AppColors.textOnLightSecondary,
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: GoogleFonts.inter(
            color: isDark ? Colors.white : AppColors.textOnLight,
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                benchmark,
                style: GoogleFonts.inter(
                  color: color,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Score Optimizer Card ────────────────────────────────────────────────────

class _ScoreOptimizerCard extends StatelessWidget {
  const _ScoreOptimizerCard({
    required this.lowestComponent,
    required this.overallScore,
    required this.isDark,
  });

  final HealthComponent lowestComponent;
  final int overallScore;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final recommendation = _getRecommendation(lowestComponent.key);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.navyCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: (isDark ? AppColors.teal : const Color(0xFF0D9488))
              .withValues(alpha: 0.35),
          width: 1.2,
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: (isDark ? AppColors.teal : const Color(0xFF0D9488))
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.trending_up_rounded,
                      size: 18,
                      color: isDark ? AppColors.teal : const Color(0xFF0D9488),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FASTEST PATH TO 85+ (EXCELLENT)',
                          style: GoogleFonts.inter(
                            color: isDark
                                ? AppColors.teal
                                : const Color(0xFF0D9488),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          recommendation.title,
                          style: GoogleFonts.inter(
                            color:
                                isDark ? Colors.white : AppColors.textOnLight,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      recommendation.gain,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF10B981),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                recommendation.action,
                style: GoogleFonts.inter(
                  color: isDark
                      ? AppColors.textOnDarkSecondary
                      : AppColors.textOnLightSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              // Action triggers
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            isDark ? Colors.white : AppColors.textOnLight,
                        side: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : AppColors.borderLight,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.tune_rounded, size: 16),
                      label: Text(
                        'Test in What-If',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        context.push('/ask');
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isDark ? AppColors.teal : const Color(0xFF0D9488),
                        foregroundColor:
                            isDark ? AppColors.navyBg : Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                      label: Text(
                        'Ask Copilot',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        context.push('/ask');
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static ({String title, String gain, String action}) _getRecommendation(
      String key) {
    return switch (key) {
      'emergency' => (
          title: 'Strengthen Emergency Cushion',
          gain: '+8 to +15 pts',
          action:
              'Building liquid reserves toward 3–6 months gives the single biggest resilience boost against unexpected life events.',
        ),
      'savings' => (
          title: 'Elevate Monthly Savings',
          gain: '+6 to +12 pts',
          action:
              'Increasing your monthly savings rate to 20% accelerates capital accumulation and boosts your foundation score.',
        ),
      'budget' => (
          title: 'Realign Category Limits',
          gain: '+5 to +10 pts',
          action:
              'Reviewing overspent categories and maintaining limits protects your daily surplus from lifestyle inflation.',
        ),
      'goals' => (
          title: 'Fund Active Milestones',
          gain: '+4 to +8 pts',
          action:
              'Assigning consistent contributions to your top financial target converts intent into measurable momentum.',
        ),
      _ => (
          title: 'Optimize Discretionary Spending',
          gain: '+4 to +8 pts',
          action:
              'Keeping non-essential lifestyle expenses within 10% to 30% of income preserves maximum cash flexibility.',
        ),
    };
  }
}

// ── 5 Core Financial Resilience Pillar Cards ────────────────────────────────

class _PillarCard extends StatefulWidget {
  const _PillarCard({
    required this.component,
    required this.isDark,
  });

  final HealthComponent component;
  final bool isDark;

  @override
  State<_PillarCard> createState() => _PillarCardState();
}

class _PillarCardState extends State<_PillarCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = widget.isDark;
    final component = widget.component;
    final config = _getConfig(component.key, component.score);
    final (ratingText, ratingColor) = _ratingInfo(component.score);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.navyCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppColors.borderLight,
          width: 1.2,
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
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _expanded = !_expanded);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Icon Box
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: config.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        config.icon,
                        size: 21,
                        color: config.color,
                      ),
                    ),
                    const SizedBox(width: 13),

                    // Pillar Name & Primary Metric Readout
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            config.title,
                            style: GoogleFonts.inter(
                              color:
                                  isDark ? Colors.white : AppColors.textOnLight,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            config.metricText(component),
                            style: GoogleFonts.inter(
                              color: isDark
                                  ? AppColors.textOnDarkSecondary
                                  : AppColors.textOnLightSecondary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Rating Pill + Numerical Score
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7.5, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: ratingColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            ratingText,
                            style: GoogleFonts.inter(
                              color: ratingColor,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${component.score}/100',
                          style: GoogleFonts.inter(
                            color:
                                isDark ? Colors.white : AppColors.textOnLight,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: isDark
                          ? AppColors.textOnDarkSecondary
                          : AppColors.textOnLightSecondary,
                      size: 20,
                    ),
                  ],
                ),

                // Expandable Deep-Dive Details
                if (_expanded) ...[
                  const SizedBox(height: 14),
                  // Dual-tone progress bar
                  ProgressBar(
                    value: component.score / 100,
                    color: config.color,
                    height: 6.5,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          _componentDetail(l10n, component),
                          style: GoogleFonts.inter(
                            color: isDark
                                ? AppColors.textOnDarkSecondary
                                : AppColors.textOnLightSecondary,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : AppColors.lightSurfaceVariant
                                  .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          l10n.healthWeightLabel(
                            ((component.weight * 100).round()).toString(),
                          ),
                          style: GoogleFonts.inter(
                            color:
                                isDark ? Colors.white : AppColors.textOnLight,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Actionable Tip Sub-Card
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.navyElevated.withValues(alpha: 0.6)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lightbulb_outline_rounded,
                          size: 16,
                          color: config.color,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            config.tipText,
                            style: GoogleFonts.inter(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.85)
                                  : AppColors.textOnLight,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static (String, Color) _ratingInfo(int score) {
    if (score >= 65) {
      return ('Good', const Color(0xFF10B981));
    }
    if (score >= 45) {
      return ('Moderate', const Color(0xFFF59E0B));
    }
    return ('Needs Work', const Color(0xFFEF4444));
  }

  static ({
    String title,
    IconData icon,
    Color color,
    String Function(HealthComponent) metricText,
    String tipText,
  }) _getConfig(String key, int score) {
    return switch (key) {
      'savings' => (
          title: 'Savings Behavior',
          icon: Icons.savings_rounded,
          color: const Color(0xFF10B981),
          metricText: (c) =>
              '${c.detailParams['rate'] ?? '0%'} of income saved (Ideal ≥ 20%)',
          tipText:
              'Automating a transfer into savings on payday ensures disciplined accumulation.',
        ),
      'budget' => (
          title: 'Budget Discipline',
          icon: Icons.account_balance_wallet_rounded,
          color: const Color(0xFF0EA5E9),
          metricText: (c) =>
              '${c.detailParams['onTrack'] ?? '0'} of ${c.detailParams['total'] ?? '0'} categories on track',
          tipText:
              'Set realistic category limits and track discretionary expenses weekly.',
        ),
      'emergency' => (
          title: 'Emergency Cushion',
          icon: Icons.shield_rounded,
          color:
              score >= 65 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
          metricText: (c) =>
              '${c.detailParams['months'] ?? '0'} months covered (Target 6 mo)',
          tipText:
              'Keep emergency savings in liquid, low-risk accounts easily accessible during shocks.',
        ),
      'goals' => (
          title: 'Goal Progress',
          icon: Icons.flag_rounded,
          color: const Color(0xFF8B5CF6),
          metricText: (c) =>
              '${c.detailParams['percent'] ?? '0'}% average milestone completion',
          tipText:
              'Consistent monthly progress towards active targets turns ambitions into reality.',
        ),
      'spending' => (
          title: 'Spending Discipline',
          icon: Icons.pie_chart_rounded,
          color: const Color(0xFFF59E0B),
          metricText: (c) =>
              '${c.detailParams['percent'] ?? '0'}% spent on wants (Ideal 10–30%)',
          tipText:
              'Balancing lifestyle desires with essential priorities prevents budget creep.',
        ),
      _ => (
          title: 'General',
          icon: Icons.pie_chart_rounded,
          color: AppColors.teal,
          metricText: (c) => 'Financial health dimension',
          tipText: 'Maintain balanced cash flow and track monthly spending.',
        ),
    };
  }

  static String _componentDetail(
      AppLocalizations l10n, HealthComponent component) {
    final params = component.detailParams;
    return switch (component.key) {
      'savings' => l10n.healthDetailSavings(params['rate'] ?? '0'),
      'budget' => l10n.healthDetailBudget(
          params['onTrack'] ?? '0', params['total'] ?? '0'),
      'emergency' => l10n.healthDetailEmergency(params['months'] ?? '0'),
      'goals' => l10n.healthDetailGoals(params['percent'] ?? '0'),
      _ => l10n.healthDetailSpending(params['percent'] ?? '0'),
    };
  }
}

// ── Methodology Card ────────────────────────────────────────────────────────

class _MethodologyCard extends StatelessWidget {
  const _MethodologyCard({
    required this.title,
    required this.body,
    required this.isDark,
    required this.onViewDetails,
  });

  final String title;
  final String body;
  final bool isDark;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.navyCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppColors.borderLight,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.verified_rounded,
                size: 18,
                color: isDark ? AppColors.teal : const Color(0xFF0D9488),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    color: isDark ? Colors.white : AppColors.textOnLight,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              InkWell(
                onTap: onViewDetails,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Details',
                        style: GoogleFonts.inter(
                          color:
                              isDark ? AppColors.teal : const Color(0xFF0D9488),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color:
                            isDark ? AppColors.teal : const Color(0xFF0D9488),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: GoogleFonts.inter(
              color: isDark
                  ? AppColors.textOnDarkSecondary
                  : AppColors.textOnLightSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Methodology Modal Sheet ─────────────────────────────────────────────────

class _MethodologyModalSheet extends StatelessWidget {
  const _MethodologyModalSheet({
    required this.isDark,
    required this.l10n,
  });

  final bool isDark;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        math.max(MediaQuery.of(context).padding.bottom, 24),
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.navyElevated : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.2)
                    : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            l10n.howScoreWorks,
            style: GoogleFonts.inter(
              color: isDark ? Colors.white : AppColors.textOnLight,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The Tadbeer Financial Health Score is calculated deterministically through 5 verified personal finance pillars. No language model or speculative AI touches this math.',
            style: GoogleFonts.inter(
              color: isDark
                  ? AppColors.textOnDarkSecondary
                  : AppColors.textOnLightSecondary,
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          _methodologyRow('Savings Behavior', '25%',
              'Monthly savings rate vs 20% benchmark', isDark),
          _methodologyRow('Budget Discipline', '25%',
              'Category limit adherence and variance control', isDark),
          _methodologyRow('Emergency Cushion', '20%',
              'Liquid living expense coverage vs 6.0 months target', isDark),
          _methodologyRow('Goal Progress', '15%',
              'Average funding velocity across active goals', isDark),
          _methodologyRow('Spending Discipline', '15%',
              'Discretionary want ratio within 10–30% band', isDark),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isDark ? AppColors.teal : const Color(0xFF0D9488),
                foregroundColor: isDark ? AppColors.navyBg : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Got It',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _methodologyRow(
      String title, String weight, String description, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              color: (isDark ? AppColors.teal : const Color(0xFF0D9488))
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                weight,
                style: GoogleFonts.inter(
                  color: isDark ? AppColors.teal : const Color(0xFF0D9488),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: isDark ? Colors.white : AppColors.textOnLight,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    color: isDark
                        ? AppColors.textOnDarkSecondary
                        : AppColors.textOnLightSecondary,
                    fontSize: 12,
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

// ── Pinned Executive Copilot Dock ───────────────────────────────────────────

class _ExecutiveCopilotDock extends StatelessWidget {
  const _ExecutiveCopilotDock({
    required this.isDark,
    required this.score,
    required this.lowestKey,
  });

  final bool isDark;
  final int score;
  final String lowestKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        math.max(MediaQuery.of(context).padding.bottom, 16),
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.navyElevated : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? const [Color(0xFF2DD4BF), Color(0xFF10B981)]
                : const [Color(0xFF010717), Color(0xFF0D1C34)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? const Color(0xFF10B981).withValues(alpha: 0.3)
                  : AppColors.navyBg.withValues(alpha: 0.25),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(26),
            onTap: () {
              HapticFeedback.lightImpact();
              context.push('/ask');
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: isDark ? AppColors.navyBg : Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Improve My Score with AI Copilot',
                        style: GoogleFonts.inter(
                          color: isDark ? AppColors.navyBg : Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: isDark ? AppColors.navyBg : Colors.white,
                      size: 17,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
