import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/l10n_context.dart';
import '../../../domain/services/financial_health_calculator.dart';
import '../../../providers/finance_providers.dart';
import '../../../l10n/app_localizations.dart';
import 'widgets/finance_widgets.dart';

/// The Financial Health Score screen with a modern, human-crafted fintech design:
/// - Prominent circular health gauge with gradient arc and score/rating inside
/// - 5 Component breakdown cards (Savings, Spending, Emergency Fund, Financial Awareness, Goal Progress)
/// - Interactive expandable details on tap
/// - Pinned bottom gradient action button: "Improve My Score ->"
/// - Consistent dark blue midnight theme matching the entire app and logo.
class FinancialHealthScreen extends ConsumerWidget {
  const FinancialHealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(financeControllerProvider);
    final health = ref.watch(financialHealthProvider);
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: AppColors.navyBg,
      appBar: AppBar(
        backgroundColor: AppColors.navyBg,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Text(
          l10n.financialHealthTitle,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: asyncData.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.teal),
        ),
        error: (error, _) => Center(
          child: Text(
            l10n.errorTitle,
            style: GoogleFonts.inter(color: Colors.white),
          ),
        ),
        data: (data) {
          if (health == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.teal),
            );
          }

          // Order components consistently matching the reference mockup:
          // 1. Savings, 2. Spending, 3. Emergency Fund, 4. Budget/Awareness, 5. Goals
          const order = ['savings', 'spending', 'emergency', 'budget', 'goals'];
          final sortedComponents = [...health.components]..sort((a, b) {
              final indexA = order.indexOf(a.key);
              final indexB = order.indexOf(b.key);
              return (indexA == -1 ? 99 : indexA)
                  .compareTo(indexB == -1 ? 99 : indexB);
            });

          return Column(
            children: [
              Expanded(
                child: ListView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                  children: [
                    // ── 1. Hero Score Gauge ────────────────────────────────
                    Center(
                      child: HealthScoreGauge(
                        score: health.score,
                        ratingLabel: _ratingLabel(l10n, health.score),
                        size: 196,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── 2. Component Breakdown Cards ───────────────────────
                    ...sortedComponents.map(
                      (component) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ComponentCard(component: component),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── 3. How It Works Transparency Card ──────────────────
                    _HowItWorks(
                      title: l10n.howScoreWorks,
                      body: l10n.howScoreWorksBody,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),

              // ── 4. Pinned Bottom Action Button ───────────────────────────
              Container(
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  math.max(MediaQuery.of(context).padding.bottom, 16),
                ),
                decoration: BoxDecoration(
                  color: AppColors.navyBg,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.navyBg.withValues(alpha: 0.9),
                      blurRadius: 16,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: Container(
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2DD4BF), Color(0xFF10B981)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(27),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(27),
                      onTap: () {
                        context.push('/ask');
                      },
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Improve My Score',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 16.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _ratingLabel(AppLocalizations l10n, int score) {
    if (score >= 85) return l10n.ratingExcellent;
    if (score >= 65) return l10n.ratingGood;
    if (score >= 45) return l10n.ratingFair;
    return l10n.ratingNeedsAttention;
  }
}

// ── Hero Circular Health Gauge ──────────────────────────────────────────────

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
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _HealthGaugePainter(
          score: score.clamp(0, 100),
          trackColor: const Color(0xFF0F263B),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RichText(
                text: TextSpan(
                  text: '$score',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                  children: [
                    TextSpan(
                      text: ' /100',
                      style: GoogleFonts.inter(
                        color: AppColors.textOnDarkSecondary,
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                ratingLabel,
                style: GoogleFonts.inter(
                  color: const Color(0xFF34D399),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HealthGaugePainter extends CustomPainter {
  const _HealthGaugePainter({
    required this.score,
    required this.trackColor,
  });

  final int score;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const strokeWidth = 14.0;
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

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
  bool shouldRepaint(covariant _HealthGaugePainter oldDelegate) =>
      oldDelegate.score != score;
}

// ── Component Breakdown Card ────────────────────────────────────────────────

class _ComponentCard extends StatefulWidget {
  const _ComponentCard({required this.component});

  final HealthComponent component;

  @override
  State<_ComponentCard> createState() => _ComponentCardState();
}

class _ComponentCardState extends State<_ComponentCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final component = widget.component;
    final config = _getConfig(component.key, component.score);
    final (ratingText, ratingColor) = _ratingInfo(component.score);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.navyCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Component Icon Container
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: config.color.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        config.icon,
                        size: 22,
                        color: config.color,
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Title & Subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            config.title,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            config.subtitle,
                            style: GoogleFonts.inter(
                              color: AppColors.textOnDarkSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Rating badge text (e.g. Good, Moderate, Needs Work)
                    Text(
                      ratingText,
                      style: GoogleFonts.inter(
                        color: ratingColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Component Score (e.g. 80/100)
                    Text(
                      '${component.score}/100',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),

                // Expandable Details (shows explanation, progress bar & weight)
                if (_expanded) ...[
                  const SizedBox(height: 14),
                  ProgressBar(
                    value: component.score / 100,
                    color: config.color,
                    height: 6,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          _componentDetail(l10n, component),
                          style: GoogleFonts.inter(
                            color: AppColors.textOnDarkSecondary,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          l10n.healthWeightLabel(
                            ((component.weight * 100).round()).toString(),
                          ),
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
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
      return ('Good', const Color(0xFF34D399));
    }
    if (score >= 45) {
      return ('Moderate', const Color(0xFFFBBF24));
    }
    return ('Needs Work', const Color(0xFFF87171));
  }

  static ({String title, String subtitle, IconData icon, Color color})
      _getConfig(String key, int score) {
    return switch (key) {
      'savings' => (
          title: 'Savings',
          subtitle: score >= 65 ? 'Consistent' : 'Building',
          icon: Icons.savings_rounded,
          color: const Color(0xFF10B981),
        ),
      'spending' => (
          title: 'Spending',
          subtitle: score >= 65 ? 'Controlled' : 'Moderate',
          icon: Icons.credit_card_rounded,
          color: const Color(0xFFF59E0B),
        ),
      'emergency' => (
          title: 'Emergency Fund',
          subtitle: score >= 65 ? 'Protected' : 'Needs Work',
          icon: Icons.shield_rounded,
          color: const Color(0xFFEF4444),
        ),
      'budget' => (
          title: 'Financial Awareness',
          subtitle: score >= 65 ? 'Good' : 'Review',
          icon: Icons.insights_rounded,
          color: const Color(0xFF0EA5E9),
        ),
      'goals' => (
          title: 'Goal Progress',
          subtitle: score >= 65 ? 'Goal Focus' : 'In Progress',
          icon: Icons.flag_rounded,
          color: const Color(0xFF8B5CF6),
        ),
      _ => (
          title: 'General',
          subtitle: 'Tracking',
          icon: Icons.pie_chart_rounded,
          color: AppColors.teal,
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

// ── How It Works Transparency Card ──────────────────────────────────────────

class _HowItWorks extends StatelessWidget {
  const _HowItWorks({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.navyCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: AppColors.teal,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: GoogleFonts.inter(
              color: AppColors.textOnDarkSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
