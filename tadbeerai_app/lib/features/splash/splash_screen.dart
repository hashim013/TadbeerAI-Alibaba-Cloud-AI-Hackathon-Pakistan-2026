import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';

/// Redesigned brand splash screen for Tadbeer AI 2.0.
///
/// Features a dark ambient background with a 3D perspective particle mesh,
/// glowing brand mark, modern typography hierarchy, and active indicator.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveController;

  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _bootstrap();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    // Brand moment before routing (comfortable testing duration)
    await Future<void>.delayed(AppConstants.splashDuration);
    _navigateToOnboarding();
  }

  void _navigateToOnboarding() {
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;
    // Always route to onboarding for testing without checking saved settings
    context.go('/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    const bgBase = AppColors.navyBg;
    const tealAccent = AppColors.teal;
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final bottomInset = math.max(24.0, mediaQuery.padding.bottom + 16.0);
    final topInset = math.max(20.0, mediaQuery.padding.top + 8.0);

    // Proportional sizing tailored to utilize full vertical screen estate
    final logoSize = (screenHeight * 0.22).clamp(170.0, 220.0);

    return Scaffold(
      backgroundColor: bgBase,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _navigateToOnboarding,
        child: AnnotatedRegion<SystemUiOverlayStyle>(
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
                      center: const Alignment(0, -0.28),
                      radius: 1.1,
                      colors: [
                        const Color(0xFF061A2E).withValues(alpha: 0.35),
                        bgBase,
                      ],
                    ),
                  ),
                ),
              ),

              // ── 3D Particle Wave Field (Expanded Bottom Half Mesh) ───────────
              Positioned.fill(
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _waveController,
                    builder: (context, _) => CustomPaint(
                      painter: _ParticleWavePainter(
                        phase: _waveController.value * 2 * math.pi,
                      ),
                    ),
                  ),
                ),
              ),

              // ── Foreground Branding & Content (Full-Screen Proportioned) ─────
              Padding(
                padding: EdgeInsets.only(
                  top: topInset,
                  bottom: bottomInset,
                  left: 28.0,
                  right: 28.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Spacer(flex: 2),

                    // Brand Emblem with Subtle Ambient Glow
                    Container(
                      width: logoSize,
                      height: logoSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: tealAccent.withValues(alpha: 0.08),
                            blurRadius: 36,
                            spreadRadius: 4,
                          ),
                          BoxShadow(
                            color: AppColors.teal.withValues(alpha: 0.04),
                            blurRadius: 54,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: Image.asset(
                        AppConstants.assetLogoTransparent,
                        fit: BoxFit.contain,
                      ),
                    )
                        .animate()
                        .scale(
                          duration: 700.ms,
                          curve: Curves.easeOutBack,
                        )
                        .fadeIn(duration: 600.ms),

                    SizedBox(height: (screenHeight * 0.03).clamp(20.0, 30.0)),

                    // App Title: TADBEER AI
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'TADBEER',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.4,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'AI',
                          style: GoogleFonts.inter(
                            color: tealAccent,
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.6,
                          ),
                        ),
                      ],
                    ).animate(delay: 200.ms).fadeIn(duration: 500.ms).slideY(
                          begin: 0.18,
                          end: 0,
                          curve: Curves.easeOutCubic,
                        ),

                    SizedBox(height: (screenHeight * 0.018).clamp(12.0, 18.0)),

                    // Primary Subtitle (split onto 2 lines so it fits neatly within the title width)
                    Text(
                      'Your AI Financial Intelligence Companion',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: const Color(0xFFE2E8F0),
                        fontSize: 10,
                        fontWeight: FontWeight.w300,
                        height: 1.35,
                        letterSpacing: 0.35,
                      ),
                    ).animate(delay: 350.ms).fadeIn(duration: 500.ms).slideY(
                          begin: 0.15,
                          end: 0,
                          curve: Curves.easeOutCubic,
                        ),

                    const Spacer(flex: 4),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom painter that renders the futuristic 3D perspective particle mesh
/// sweeping upward to the right across the lower portion of the screen.
class _ParticleWavePainter extends CustomPainter {
  final double phase;

  _ParticleWavePainter({required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    const numRows = 24;
    const numCols = 34;
    const meshTopRatio = 0.65;
    final meshHeight = size.height * (1.0 - meshTopRatio);

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    for (int r = 0; r < numRows; r++) {
      // 0.0 (near foreground / bottom) to 1.0 (far background / lower third)
      final tRow = r / (numRows - 1);
      final yBase =
          size.height - (1.0 - math.pow(1.0 - tRow, 1.35)) * meshHeight;

      for (int c = 0; c < numCols; c++) {
        // 0.0 (left) to 1.0 (right)
        final tCol = c / (numCols - 1);

        // Sinusoidal wave combined with upward curvature to the right
        final wave = math.sin(tCol * 3.6 - tRow * 2.1 + phase) *
            (15.0 * (1.0 - tRow * 0.45));
        final elevation =
            -math.pow(tCol, 1.7) * (size.height * 0.09) * (1.0 - tRow * 0.35);

        // Slight perspective skew across horizontal axis
        final px = tCol * size.width + (tRow * 24.0);
        final py = yBase + elevation + wave;

        // Fades gracefully at top and left
        final fadeTop = math.pow(1.0 - tRow, 0.75);
        final fadeLeft = 0.22 + 0.78 * tCol;
        final topFade =
            ((py - size.height * 0.62) / (size.height * 0.10)).clamp(0.0, 1.0);
        final alpha = (0.75 * fadeTop * fadeLeft * topFade).clamp(0.0, 0.88);

        final radius = 1.1 + (1.0 - tRow) * 1.8;

        if (px >= -radius &&
            px <= size.width + radius &&
            py >= size.height * 0.60 &&
            py <= size.height + radius &&
            alpha > 0.02) {
          paint.color = AppColors.teal.withValues(alpha: alpha);
          canvas.drawCircle(Offset(px, py), radius, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ParticleWavePainter oldDelegate) {
    return oldDelegate.phase != phase;
  }
}
