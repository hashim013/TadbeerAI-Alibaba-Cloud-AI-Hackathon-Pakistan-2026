import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/l10n_context.dart';

/// Three-step introductory journey: Understand → Manage → Plan.
///
/// Designed with a deep midnight navy-teal dark theme cohesive with the splash screen,
/// featuring glowing pillar badges, soft artwork dissolves, custom typography,
/// and smooth interactive page transitions.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    // Note: Kept unpersisted during visual testing mode as requested
    // await ref.read(settingsRepositoryProvider).completeOnboarding();
    if (mounted) context.go('/login');
  }

  void _next() {
    if (_page == 2) {
      _finish();
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _previous() {
    if (_page > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgBase = AppColors.navyBg;
    const emeraldAccent = AppColors.emerald;
    const mintAccent = AppColors.teal;

    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final topInset = math.max(16.0, mediaQuery.padding.top);
    final bottomInset = math.max(20.0, mediaQuery.padding.bottom + 12.0);

    final l10n = context.l10n;

    final pages = <({
      String asset,
      String title,
      String description,
      IconData icon,
    })>[
      (
        asset: AppConstants.assetOnboardingUnderstand,
        title: l10n.onboardingTitleUnderstand,
        description:
            "Understand Pakistan's economy, financial trends and what's happening around you.",
        icon: Icons.psychology_rounded,
      ),
      (
        asset: AppConstants.assetOnboardingManage,
        title: l10n.onboardingTitleManage,
        description:
            'Track income and expenses, create budgets, build savings and achieve your financial goals.',
        icon: Icons.account_balance_wallet_rounded,
      ),
      (
        asset: AppConstants.assetOnboardingPlan,
        title: l10n.onboardingTitlePlan,
        description:
            'Simulate different scenarios, get AI insights and plan your financial future with confidence.',
        icon: Icons.lightbulb_rounded,
      ),
    ];

    final isLast = _page == pages.length - 1;

    return Scaffold(
      backgroundColor: bgBase,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Background Ambient Vignette Glow (Midnight Navy + Soft Teal Blend) ──
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.35),
                    radius: 1.15,
                    colors: [
                      const Color(0xFF061A2E).withValues(alpha: 0.35),
                      bgBase,
                    ],
                  ),
                ),
              ),
            ),

            // ── Main Content Area ───────────────────────────────────────────
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // ── Top Navigation Bar (Back & Skip) ───────────────────────
                  Padding(
                    padding:
                        EdgeInsets.fromLTRB(20, topInset > 24 ? 4 : 8, 20, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Back chevron (only on pages 1 & 2)
                        AnimatedOpacity(
                          opacity: _page > 0 ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 250),
                          child: IgnorePointer(
                            ignoring: _page == 0,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _previous,
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.06),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.10),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Skip button (fades on last page)
                        AnimatedOpacity(
                          opacity: isLast ? 0.0 : 1.0,
                          duration: const Duration(milliseconds: 250),
                          child: IgnorePointer(
                            ignoring: isLast,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _finish,
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.10),
                                    ),
                                  ),
                                  child: Text(
                                    l10n.onboardingSkip,
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF94A3B8),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Slide Carousel View ────────────────────────────────────
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      physics: const ClampingScrollPhysics(),
                      itemCount: pages.length,
                      onPageChanged: (index) => setState(() => _page = index),
                      itemBuilder: (context, index) {
                        final page = pages[index];
                        final artworkHeight =
                            (screenHeight * 0.45).clamp(240.0, 420.0);

                        return Column(
                          children: [
                            const Spacer(flex: 1),

                            // Artwork with subtle bottom dissolve into dark background
                            SizedBox(
                              height: artworkHeight,
                              child: Stack(
                                alignment: Alignment.bottomCenter,
                                children: [
                                  // Background subtle glow behind artwork
                                  Positioned(
                                    bottom: 20,
                                    child: Container(
                                      width: artworkHeight * 0.65,
                                      height: artworkHeight * 0.65,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: mintAccent.withValues(
                                                alpha: 0.04),
                                            blurRadius: 36,
                                            spreadRadius: 4,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // The 3D artwork with soft fade
                                  ShaderMask(
                                    shaderCallback: (rect) {
                                      return const LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.black,
                                          Colors.black,
                                          Colors.black,
                                          Colors.transparent,
                                        ],
                                        stops: [0.0, 0.78, 0.92, 1.0],
                                      ).createShader(rect);
                                    },
                                    blendMode: BlendMode.dstIn,
                                    child: Image.asset(
                                      page.asset,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Floating Glowing Pillar Badge
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const RadialGradient(
                                  colors: [
                                    Color(0xFF0D1C34),
                                    Color(0xFF010717),
                                  ],
                                ),
                                border: Border.all(
                                  color: mintAccent.withValues(alpha: 0.55),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        emeraldAccent.withValues(alpha: 0.16),
                                    blurRadius: 12,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Icon(
                                page.icon,
                                color: mintAccent,
                                size: 26,
                              ),
                            )
                                .animate(key: ValueKey('badge_$index'))
                                .scale(
                                  duration: 400.ms,
                                  curve: Curves.easeOutBack,
                                )
                                .fadeIn(duration: 350.ms),

                            const SizedBox(height: 14),

                            // Headline: Understand / Manage / Plan
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [
                                  Color(0xFF34D399),
                                  Color(0xFF2DD4BF),
                                ],
                              ).createShader(bounds),
                              child: Text(
                                page.title,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            )
                                .animate(key: ValueKey('title_$index'))
                                .fadeIn(duration: 400.ms)
                                .slideY(
                                  begin: 0.15,
                                  end: 0,
                                  curve: Curves.easeOutCubic,
                                ),

                            const SizedBox(height: 10),

                            // Description Subtitle
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 28),
                              child: Text(
                                page.description,
                                style: GoogleFonts.inter(
                                  color: const Color(0xFFCBD5E1),
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w400,
                                  height: 1.48,
                                  letterSpacing: 0.15,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            )
                                .animate(key: ValueKey('desc_$index'))
                                .fadeIn(duration: 450.ms),

                            const Spacer(flex: 2),
                          ],
                        );
                      },
                    ),
                  ),

                  // ── Bottom Controls: Indicator + Next / Get Started ──────
                  Padding(
                    padding: EdgeInsets.fromLTRB(24, 0, 24, bottomInset),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Page indicators (active capsule + inactive dots)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(pages.length, (index) {
                            final active = index == _page;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: active ? 32 : 7,
                              height: 6,
                              decoration: BoxDecoration(
                                color: active
                                    ? emeraldAccent
                                    : const Color(0xFF142746),
                                borderRadius: BorderRadius.circular(3),
                                boxShadow: active
                                    ? [
                                        BoxShadow(
                                          color: emeraldAccent.withValues(
                                              alpha: 0.5),
                                          blurRadius: 8,
                                          offset: const Offset(0, 1),
                                        ),
                                      ]
                                    : null,
                              ),
                            );
                          }),
                        ),

                        const SizedBox(height: 22),

                        // Action Button (Gradient CTA)
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _next,
                            borderRadius: BorderRadius.circular(18),
                            child: Ink(
                              height: 56,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF2DD4BF),
                                    Color(0xFF10B981),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF10B981)
                                        .withValues(alpha: 0.4),
                                    blurRadius: 20,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    isLast
                                        ? l10n.onboardingGetStarted
                                        : l10n.onboardingNext,
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF010717),
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    isLast
                                        ? Icons.rocket_launch_rounded
                                        : Icons.arrow_forward_rounded,
                                    color: const Color(0xFF010717),
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
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
