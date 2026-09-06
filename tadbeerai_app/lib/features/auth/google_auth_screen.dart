import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/l10n_context.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../providers/repository_providers.dart';
import 'auth_controller.dart';

/// Predefined Google device account representation.
class _GoogleAccountItem {
  const _GoogleAccountItem({
    required this.name,
    required this.email,
    required this.avatarColor,
    this.badge,
  });

  final String name;
  final String email;
  final Color avatarColor;
  final String? badge;
}

/// Authentic Google Account Chooser screen for Tadbeer AI 2.0.
///
/// Designed to strictly follow Google Identity Services (GIS) design patterns
/// and Material Design guidelines, perfectly integrated into Tadbeer AI's
/// dark theme without synthetic AI design tropes (no floating connector dots
/// or gimmicky glows).
class GoogleAuthScreen extends ConsumerStatefulWidget {
  const GoogleAuthScreen({super.key});

  @override
  ConsumerState<GoogleAuthScreen> createState() => _GoogleAuthScreenState();
}

class _GoogleAuthScreenState extends ConsumerState<GoogleAuthScreen> {
  static final _emailPattern = RegExp(r'^[\w.\-+]+@([\w\-]+\.)+[\w\-]{2,}$');

  // Real device accounts simulation (Google GIS style)
  static const _savedAccounts = [
    _GoogleAccountItem(
      name: 'Ahsan Khan',
      email: 'ahsan.khan@gmail.com',
      avatarColor: Color(0xFF1A73E8), // Authentic Google Blue
      badge: 'Active on device',
    ),
    _GoogleAccountItem(
      name: 'Syed Bilal',
      email: 'bilal.syed@gmail.com',
      avatarColor: Color(0xFF1E8E3E), // Authentic Google Green
    ),
  ];

  String? _signingInEmail;
  bool _showCustomInput = false;
  final _customEmailController = TextEditingController();
  final _customFormKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _customEmailController.dispose();
    super.dispose();
  }

  void _onCancel() {
    if (_signingInEmail != null) return;
    HapticFeedback.lightImpact();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/login');
    }
  }

  Future<void> _selectAccount(String email, {String? name}) async {
    if (_signingInEmail != null) return;
    HapticFeedback.selectionClick();
    setState(() => _signingInEmail = email);

    final success = await ref
        .read(authControllerProvider.notifier)
        .signInWithGoogle(email: email, name: name);

    if (!mounted) return;

    if (success) {
      final profile =
          await ref.read(financialProfileRepositoryProvider).loadProfile();
      if (!mounted) return;
      if (profile == null || !profile.profileCompleted) {
        context.go('/profile/financial');
      } else {
        context.go('/home');
      }
    } else {
      final error = ref.read(authControllerProvider.notifier).lastErrorMessage;
      setState(() => _signingInEmail = null);
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  void _submitCustomEmail() {
    if (_signingInEmail != null) return;
    if (_customFormKey.currentState?.validate() ?? false) {
      final email = _customEmailController.text.trim();
      _selectAccount(email);
    }
  }

  void _showInfoSheet(String title, String content) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? AppColors.navyCard : AppColors.lightCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Icon(Icons.shield_outlined,
                    color: AppColors.teal, size: 20),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: isDark ? Colors.white : AppColors.textOnLight,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: GoogleFonts.inter(
                color: isDark
                    ? AppColors.textOnDarkSecondary
                    : AppColors.textOnLightSecondary,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: isDark ? AppColors.teal : AppColors.navyBg,
                  foregroundColor: isDark ? AppColors.navyBg : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isBusy = _signingInEmail != null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !isBusy) {
          context.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              // ── Top Navigation Bar (Clean Browser / Native App Header) ──
              _buildTopBar(context, l10n, isBusy),

              // ── Scrollable Auth Container ──────────────────────────────
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Authentic Google Identity Card
                          _buildGoogleIdentityCard(l10n, isBusy),

                          const SizedBox(height: 18),

                          // Google Privacy Notice & Legal Links
                          _buildPrivacyNotice(l10n),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, dynamic l10n, bool isBusy) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : AppColors.borderLight,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Cancel Action
          TextButton(
            onPressed: isBusy ? null : _onCancel,
            style: TextButton.styleFrom(
              foregroundColor: isDark
                  ? AppColors.textOnDarkSecondary
                  : AppColors.textOnLightSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(48, 36),
            ),
            child: Text(
              l10n.googleCancel,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // Browser SSL Security Indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : AppColors.lightSurfaceVariant,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : AppColors.borderLight,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_rounded,
                  size: 12,
                  color: AppColors.teal,
                ),
                const SizedBox(width: 5),
                Text(
                  'accounts.google.com',
                  style: GoogleFonts.inter(
                    color: isDark
                        ? AppColors.textOnDarkTertiary
                        : AppColors.textOnLightTertiary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleIdentityCard(dynamic l10n, bool isBusy) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.25)
                : AppColors.lightCardShadow,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Google Hairline Indeterminate Progress Bar
          if (isBusy)
            const LinearProgressIndicator(
              minHeight: 2.5,
              backgroundColor: Colors.transparent,
              color: AppColors.teal,
            )
          else
            const SizedBox(height: 2.5),

          // Google Header with Single Official 4-Color Logo
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Clean Google 4-Color Mark
                const GoogleLogo(size: 32),

                const SizedBox(height: 14),

                // Main Heading
                Text(
                  l10n.googleSignInTitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: isDark ? Colors.white : AppColors.textOnLight,
                    fontSize: 21,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),

                const SizedBox(height: 6),

                // Destination context: "Choose an account to continue to Tadbeer AI"
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        l10n.googleSignInSubtitle,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: isDark
                              ? AppColors.textOnDarkSecondary
                              : AppColors.textOnLightSecondary,
                          fontSize: 13.5,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Image.asset(
                      AppConstants.assetLogoTransparent,
                      width: 18,
                      height: 18,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
              ],
            ),
          ),

          Divider(
              height: 1,
              color: isDark ? const Color(0x14FFFFFF) : AppColors.borderLight),

          // "Choose an account" Section Subheader
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.googleChooseAccount,
                    style: GoogleFonts.inter(
                      color: isDark
                          ? AppColors.textOnDarkTertiary
                          : AppColors.textOnLightTertiary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isBusy) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      color: AppColors.teal,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.googleSigningIn,
                    style: GoogleFonts.inter(
                      color: AppColors.teal,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Device Accounts List
          for (int i = 0; i < _savedAccounts.length; i++) ...[
            _buildAccountRow(
              account: _savedAccounts[i],
              isBusy: isBusy,
              isSelected: _signingInEmail == _savedAccounts[i].email,
            ),
            Divider(
                height: 1,
                color:
                    isDark ? const Color(0x10FFFFFF) : AppColors.borderLight),
          ],

          // "Use another account" Row
          _buildUseAnotherAccountRow(l10n, isBusy),

          // Custom email entry expanded
          if (_showCustomInput) _buildCustomEmailSection(l10n, isBusy),
        ],
      ),
    );
  }

  Widget _buildAccountRow({
    required _GoogleAccountItem account,
    required bool isBusy,
    required bool isSelected,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final initial =
        account.name.isNotEmpty ? account.name[0].toUpperCase() : 'G';

    return Material(
      color: isSelected
          ? AppColors.teal.withValues(alpha: 0.08)
          : Colors.transparent,
      child: InkWell(
        onTap: isBusy
            ? null
            : () => _selectAccount(account.email, name: account.name),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          child: Row(
            children: [
              // Google User Letter Avatar
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: account.avatarColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 14),

              // Name & Email
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            account.name,
                            style: GoogleFonts.inter(
                              color:
                                  isDark ? Colors.white : AppColors.textOnLight,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (account.badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : AppColors.lightSurfaceVariant,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              account.badge!,
                              style: GoogleFonts.inter(
                                color: isDark
                                    ? AppColors.textOnDarkTertiary
                                    : AppColors.textOnLightTertiary,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      account.email,
                      style: GoogleFonts.inter(
                        color: isDark
                            ? AppColors.textOnDarkSecondary
                            : AppColors.textOnLightSecondary,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              if (isSelected)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.teal,
                  ),
                )
              else
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.2)
                      : AppColors.textOnLightTertiary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUseAnotherAccountRow(dynamic l10n, bool isBusy) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isBusy
            ? null
            : () {
                HapticFeedback.selectionClick();
                setState(() => _showCustomInput = !_showCustomInput);
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : AppColors.lightSurfaceVariant,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : AppColors.borderLight,
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.person_add_alt_1_outlined,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.8)
                      : AppColors.textOnLightSecondary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  l10n.googleUseAnotherAccount,
                  style: GoogleFonts.inter(
                    color: isDark ? Colors.white : AppColors.textOnLight,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                _showCustomInput
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.4)
                    : AppColors.textOnLightTertiary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomEmailSection(dynamic l10n, bool isBusy) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
      color: isDark
          ? Colors.white.withValues(alpha: 0.02)
          : AppColors.lightSurfaceVariant.withValues(alpha: 0.3),
      child: Form(
        key: _customFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Divider(
              height: 1,
              color: isDark ? const Color(0x10FFFFFF) : AppColors.borderLight,
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _customEmailController,
              label: l10n.googleEnterEmailHint,
              hintText: 'username@gmail.com',
              keyboardType: TextInputType.emailAddress,
              prefixIcon: const Icon(
                Icons.alternate_email_rounded,
                color: AppColors.teal,
                size: 18,
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Please enter your email address.';
                }
                if (!_emailPattern.hasMatch(val.trim())) {
                  return 'Please enter a valid email address.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            AppButton(
              label: l10n.googleContinueButton,
              loading: isBusy &&
                  _signingInEmail == _customEmailController.text.trim(),
              onPressed: isBusy ? null : _submitCustomEmail,
              trailingIcon: const Icon(Icons.arrow_forward_rounded, size: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyNotice(dynamic l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.shield_outlined,
                size: 14,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.5)
                    : AppColors.textOnLightTertiary,
              ),
              const SizedBox(width: 6),
              Text(
                'Google Privacy & Disclosure',
                style: GoogleFonts.inter(
                  color: isDark
                      ? AppColors.textOnDarkTertiary
                      : AppColors.textOnLightTertiary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.googlePrivacyNotice,
            style: GoogleFonts.inter(
              color: isDark
                  ? AppColors.textOnDarkTertiary
                  : AppColors.textOnLightTertiary,
              fontSize: 11.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              GestureDetector(
                onTap: () => _showInfoSheet(
                  'Privacy Policy',
                  'Tadbeer AI respects your privacy. Your Google profile information (name and email) is securely encrypted and used strictly to personalize your financial intelligence dashboard.',
                ),
                child: Text(
                  'Privacy Policy',
                  style: GoogleFonts.inter(
                    color: isDark ? AppColors.teal : AppColors.blue,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                    decorationColor: isDark ? AppColors.teal : AppColors.blue,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  '•',
                  style: TextStyle(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.3)
                        : AppColors.textOnLightTertiary,
                    fontSize: 11,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _showInfoSheet(
                  'Terms of Service',
                  'By signing in with Google, you agree to Tadbeer AI’s Terms of Service for financial guidance, planning models, and budgeting intelligence.',
                ),
                child: Text(
                  'Terms of Service',
                  style: GoogleFonts.inter(
                    color: isDark ? AppColors.teal : AppColors.blue,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                    decorationColor: isDark ? AppColors.teal : AppColors.blue,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Standalone, scalable 4-color Google "G" logo painter.
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: const _GoogleLogoPainter(),
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

    // Blue arc (top-right to mid-right)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -0.75, 1.5, false, paint);

    // Green arc (bottom-right to bottom)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 0.75, 1.35, false, paint);

    // Yellow arc (bottom to bottom-left)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, 2.1, 1.4, false, paint);

    // Red arc (bottom-left to top)
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
