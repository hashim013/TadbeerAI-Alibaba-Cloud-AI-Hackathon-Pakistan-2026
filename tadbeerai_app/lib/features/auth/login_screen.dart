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
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static final _emailPattern = RegExp(r'^[\w.\-+]+@([\w\-]+\.)+[\w\-]{2,}$');

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _guestLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _continueAsGuest() async {
    if (_loading || _guestLoading) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _guestLoading = true);

    final authNotifier = ref.read(authControllerProvider.notifier);
    final success = await authNotifier.signInAsGuest();
    if (!mounted) return;

    if (success) {
      context.go('/home');
    } else {
      setState(() => _guestLoading = false);
      final errorMsg =
          authNotifier.lastErrorMessage ?? context.l10n.errorGeneric;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty || !_emailPattern.hasMatch(email)) {
      return context.l10n.validationEmailInvalid;
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').length < 6) {
      return context.l10n.validationPasswordShort;
    }
    return null;
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    final authNotifier = ref.read(authControllerProvider.notifier);
    final success = await authNotifier.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    if (!mounted) return;

    if (success) {
      context.go('/home');
    } else {
      setState(() => _loading = false);
      final errorMsg =
          authNotifier.lastErrorMessage ?? context.l10n.errorGeneric;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _forgotPassword() {
    final currentEmail = _emailController.text.trim();
    if (currentEmail.isNotEmpty) {
      context.push('/forgot-password', extra: currentEmail);
    } else {
      context.push('/forgot-password');
    }
  }

  void _socialAuth(String provider) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$provider sign-in selected for demo mode.'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: AppColors.navyBg,
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
            // ── Ambient Background Vignette Glow ───────────────────────────
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.45),
                    radius: 1.1,
                    colors: [
                      const Color(0xFF061A2E).withValues(alpha: 0.35),
                      AppColors.navyBg,
                    ],
                  ),
                ),
              ),
            ),

            // ── Main Scrollable Content ────────────────────────────────────
            SafeArea(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),

                      // App Transparent Brand Mark
                      Center(
                        child: Image.asset(
                          AppConstants.assetLogoTransparent,
                          width: 64,
                          height: 64,
                          fit: BoxFit.contain,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Header Title & Subtitle
                      Text(
                        l10n.loginWelcome,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.loginSubtitle,
                        style: GoogleFonts.inter(
                          color: AppColors.textOnDarkSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.1,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 38),

                      // Email or Phone Field
                      AppTextField(
                        label: l10n.fieldEmail,
                        hintText: 'Email or Phone',
                        controller: _emailController,
                        validator: _validateEmail,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        prefixIcon: const Icon(
                          Icons.mail_outline_rounded,
                          color: AppColors.textOnDarkSecondary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Password Field
                      AppTextField(
                        label: l10n.fieldPassword,
                        hintText: 'Password',
                        controller: _passwordController,
                        validator: _validatePassword,
                        obscure: true,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        prefixIcon: const Icon(
                          Icons.lock_outline_rounded,
                          color: AppColors.textOnDarkSecondary,
                          size: 20,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Forgot Password Link
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: GestureDetector(
                          onTap: _loading ? null : _forgotPassword,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              l10n.actionForgotPassword,
                              style: GoogleFonts.inter(
                                color: AppColors.teal,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Primary Call to Action Button with Arrow
                      AppButton(
                        label: l10n.actionSignIn,
                        onPressed: _submit,
                        loading: _loading,
                        trailingIcon: const Icon(
                          Icons.arrow_forward_rounded,
                          size: 20,
                        ),
                      ),

                      const SizedBox(height: 26),

                      // "or continue with" Divider
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: Colors.white.withValues(alpha: 0.10),
                              thickness: 1,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              'or continue with',
                              style: GoogleFonts.inter(
                                color: AppColors.textOnDarkSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: Colors.white.withValues(alpha: 0.12),
                              thickness: 1,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Social Sign-in Card: Google
                      _SocialAuthCard(
                        logo: const _GoogleLogo(),
                        label: 'Continue with Google',
                        onTap: () => _socialAuth('Google'),
                      ),

                      const SizedBox(height: 12),

                      // Guest Sign-in Card
                      _SocialAuthCard(
                        logo: const Icon(
                          Icons.person_outline_rounded,
                          size: 20,
                          color: AppColors.teal,
                        ),
                        label: l10n.actionContinueAsGuest,
                        onTap: _continueAsGuest,
                        loading: _guestLoading,
                      ),

                      const SizedBox(height: 32),

                      // Footer Navigation: Don't have an account? Sign Up
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        children: [
                          Text(
                            l10n.loginNoAccount,
                            style: GoogleFonts.inter(
                              color: AppColors.textOnDarkSecondary,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          GestureDetector(
                            onTap:
                                _loading ? null : () => context.go('/signup'),
                            child: Text(
                              l10n.actionCreateAccount,
                              style: GoogleFonts.inter(
                                color: AppColors.teal,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                    ],
                  ).animate().fadeIn(duration: 350.ms),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Social / Alternative Sign-in card with dark container styling.
class _SocialAuthCard extends StatelessWidget {
  const _SocialAuthCard({
    required this.logo,
    required this.label,
    required this.onTap,
    this.loading = false,
  });

  final Widget logo;
  final String label;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.navyCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1.2,
            ),
          ),
          child: loading
              ? const Center(
                  child: SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.teal,
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    logo,
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Vector-drawn Google 4-color "G" logo.
class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      size: Size(18, 18),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final radius = math.min(w, h) / 2;
    final stroke = radius * 0.38;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    final rect = Rect.fromCircle(center: center, radius: radius - stroke / 2);

    // Blue arc
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -0.75, 1.5, false, paint);

    // Green arc
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 0.75, 1.35, false, paint);

    // Yellow arc
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, 2.1, 1.4, false, paint);

    // Red arc
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, 3.5, 1.45, false, paint);

    // Blue horizontal bar
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    final barRect = Rect.fromLTRB(
      center.dx - stroke * 0.1,
      center.dy - stroke / 2,
      w,
      center.dy + stroke / 2,
    );
    canvas.drawRect(barRect, barPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
