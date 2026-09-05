import 'dart:async';

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

/// Stepped Forgot Password & Verification Code Reset screen.
///
/// Designed with a modern, human-crafted dark navy aesthetic:
/// Stage 1: Request 6-digit reset code via registered email.
/// Stage 2: Enter 6-digit verification code & define new password.
/// Stage 3: Secure success confirmation with instant redirect to Sign In.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

enum _ResetStage { enterEmail, enterCodeAndPassword, success }

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  static final _emailPattern = RegExp(r'^[\w.\-+]+@([\w\-]+\.)+[\w\-]{2,}$');
  static const _demoCode = '842196';

  _ResetStage _stage = _ResetStage.enterEmail;
  final _emailFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();

  late final TextEditingController _emailController;
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  // 6 individual controllers & focus nodes for the PIN boxes
  late final List<TextEditingController> _codeControllers;
  late final List<FocusNode> _codeFocusNodes;

  bool _loading = false;
  int _resendSeconds = 30;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _emailController =
        TextEditingController(text: widget.initialEmail?.trim() ?? '');
    _codeControllers = List.generate(6, (_) => TextEditingController());
    _codeFocusNodes = List.generate(6, (_) => FocusNode());
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    for (final c in _codeControllers) {
      c.dispose();
    }
    for (final f in _codeFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds > 0) {
        setState(() => _resendSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  String get _currentCode => _codeControllers.map((c) => c.text.trim()).join();

  void _fillDemoCode() {
    HapticFeedback.selectionClick();
    for (int i = 0; i < 6; i++) {
      if (i < _demoCode.length) {
        _codeControllers[i].text = _demoCode[i];
      }
    }
    _codeFocusNodes.last.requestFocus();
    setState(() {});
  }

  void _handleBack() {
    if (_loading) return;
    if (_stage == _ResetStage.enterCodeAndPassword) {
      setState(() => _stage = _ResetStage.enterEmail);
    } else {
      context.go('/login');
    }
  }

  Future<void> _sendCode() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_emailFormKey.currentState!.validate()) return;

    setState(() => _loading = true);
    final email = _emailController.text.trim();
    final authNotifier = ref.read(authControllerProvider.notifier);
    final success = await authNotifier.sendPasswordResetCode(email);

    if (!mounted) return;
    setState(() => _loading = false);

    if (success) {
      setState(() => _stage = _ResetStage.enterCodeAndPassword);
      _startResendTimer();
      // Auto focus first PIN digit box
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_codeFocusNodes.first.canRequestFocus) {
          _codeFocusNodes.first.requestFocus();
        }
      });
    } else {
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

  Future<void> _resendCode() async {
    if (_resendSeconds > 0 || _loading) return;
    setState(() => _loading = true);
    final email = _emailController.text.trim();
    final authNotifier = ref.read(authControllerProvider.notifier);
    final success = await authNotifier.sendPasswordResetCode(email);

    if (!mounted) return;
    setState(() => _loading = false);

    if (success) {
      _startResendTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${context.l10n.codeSentTo} $email',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: AppColors.navyCard,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _submitReset() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final code = _currentCode;
    if (code.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.validationCodeRequired),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!_resetFormKey.currentState!.validate()) return;

    setState(() => _loading = true);
    final email = _emailController.text.trim();
    final newPassword = _passwordController.text;
    final authNotifier = ref.read(authControllerProvider.notifier);
    final success = await authNotifier.resetPasswordWithCode(
      email: email,
      code: code,
      newPassword: newPassword,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (success) {
      setState(() => _stage = _ResetStage.success);
    } else {
      final errorMsg =
          authNotifier.lastErrorMessage ?? context.l10n.validationCodeInvalid;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
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
              // ── Ambient Background Vignette Glow ─────────────────────────
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

              // ── Main Scrollable Content ──────────────────────────────────
              SafeArea(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: _buildStageContent(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStageContent(BuildContext context) {
    switch (_stage) {
      case _ResetStage.enterEmail:
        return _buildEmailStage(context);
      case _ResetStage.enterCodeAndPassword:
        return _buildCodeAndPasswordStage(context);
      case _ResetStage.success:
        return _buildSuccessStage(context);
    }
  }

  // ── Stage 1: Email Input ──────────────────────────────────────────────────
  Widget _buildEmailStage(BuildContext context) {
    final l10n = context.l10n;

    return Form(
      key: _emailFormKey,
      child: Column(
        key: const ValueKey('stage_email'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTopBar(),
          const SizedBox(height: 12),
          _buildLogo(),
          const SizedBox(height: 16),
          Text(
            l10n.forgotPasswordTitle,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.forgotPasswordSubtitle,
            style: GoogleFonts.inter(
              color: AppColors.textOnDarkSecondary,
              fontSize: 14.5,
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 36),

          // Email Field
          AppTextField(
            label: l10n.fieldEmail,
            hintText: 'name@example.com',
            controller: _emailController,
            validator: (val) {
              final v = val?.trim() ?? '';
              if (v.isEmpty || !_emailPattern.hasMatch(v)) {
                return l10n.validationEmailInvalid;
              }
              return null;
            },
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            prefixIcon: const Icon(
              Icons.mail_outline_rounded,
              color: AppColors.textOnDarkSecondary,
              size: 20,
            ),
          ),
          const SizedBox(height: 28),

          // Send Code Button
          AppButton(
            label: l10n.actionSendCode,
            onPressed: _loading ? null : _sendCode,
            loading: _loading,
            trailingIcon: const Icon(Icons.arrow_forward_rounded, size: 20),
          ),
          const SizedBox(height: 32),

          // Return to Login Link
          Center(
            child: GestureDetector(
              onTap: _loading ? null : () => context.go('/login'),
              child: Text(
                l10n.backToSignIn,
                style: GoogleFonts.inter(
                  color: AppColors.teal,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ).animate().fadeIn(duration: 250.ms),
    );
  }

  // ── Stage 2: Code Verification & New Password ────────────────────────────
  Widget _buildCodeAndPasswordStage(BuildContext context) {
    final l10n = context.l10n;
    final email = _emailController.text.trim();

    return Form(
      key: _resetFormKey,
      child: Column(
        key: const ValueKey('stage_code_password'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTopBar(),
          const SizedBox(height: 12),
          _buildLogo(),
          const SizedBox(height: 16),
          Text(
            l10n.verifyCodeTitle,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Target Email Pill with Edit option
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text(
                '${l10n.codeSentTo} $email',
                style: GoogleFonts.inter(
                  color: AppColors.textOnDarkSecondary,
                  fontSize: 13.5,
                ),
              ),
              GestureDetector(
                onTap: _loading
                    ? null
                    : () => setState(() => _stage = _ResetStage.enterEmail),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Change',
                    style: GoogleFonts.inter(
                      color: AppColors.teal,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // 6-digit Code Label & Demo Code Chip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.fieldVerificationCode,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              InkWell(
                onTap: _fillDemoCode,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.teal.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.key_rounded,
                        size: 13,
                        color: AppColors.teal,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l10n.demoCodeHint,
                        style: GoogleFonts.inter(
                          color: AppColors.teal,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 6 Pin Digit Input Boxes
          _buildPinBoxesRow(),
          const SizedBox(height: 14),

          // Resend Timer Row
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: _resendSeconds > 0
                ? Text(
                    l10n.codeResendIn(_resendSeconds),
                    style: GoogleFonts.inter(
                      color: AppColors.textOnDarkSecondary,
                      fontSize: 13,
                    ),
                  )
                : GestureDetector(
                    onTap: _loading ? null : _resendCode,
                    child: Text(
                      l10n.actionResendCode,
                      style: GoogleFonts.inter(
                        color: AppColors.teal,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 24),

          // New Password Field
          AppTextField(
            label: l10n.newPasswordTitle,
            hintText: '••••••••',
            controller: _passwordController,
            validator: (val) {
              if ((val ?? '').length < 6) {
                return l10n.validationPasswordShort;
              }
              return null;
            },
            obscure: true,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            prefixIcon: const Icon(
              Icons.lock_outline_rounded,
              color: AppColors.textOnDarkSecondary,
              size: 20,
            ),
          ),
          const SizedBox(height: 16),

          // Confirm Password Field
          AppTextField(
            label: l10n.fieldConfirmPassword,
            hintText: '••••••••',
            controller: _confirmController,
            validator: (val) {
              if (val != _passwordController.text) {
                return l10n.validationPasswordMismatch;
              }
              return null;
            },
            obscure: true,
            textInputAction: TextInputAction.done,
            prefixIcon: const Icon(
              Icons.lock_reset_rounded,
              color: AppColors.textOnDarkSecondary,
              size: 20,
            ),
          ),
          const SizedBox(height: 28),

          // Submit Reset Button
          AppButton(
            label: l10n.actionResetPassword,
            onPressed: _loading ? null : _submitReset,
            loading: _loading,
            trailingIcon: const Icon(Icons.check_rounded, size: 20),
          ),
          const SizedBox(height: 24),
        ],
      ).animate().fadeIn(duration: 250.ms),
    );
  }

  // ── Stage 3: Success View ─────────────────────────────────────────────────
  Widget _buildSuccessStage(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      key: const ValueKey('stage_success'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 48),
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.teal.withValues(alpha: 0.12),
              border: Border.all(
                color: AppColors.teal.withValues(alpha: 0.45),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.teal.withValues(alpha: 0.25),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.check_rounded,
              color: AppColors.teal,
              size: 48,
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          l10n.passwordResetSuccessTitle,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            l10n.passwordResetSuccessSubtitle,
            style: GoogleFonts.inter(
              color: AppColors.textOnDarkSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w400,
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 40),
        AppButton(
          label: l10n.backToSignIn,
          onPressed: () => context.go('/login'),
          trailingIcon: const Icon(Icons.arrow_forward_rounded, size: 20),
        ),
        const SizedBox(height: 32),
      ],
    ).animate().fadeIn(duration: 350.ms).scale(
          begin: const Offset(0.96, 0.96),
          end: const Offset(1, 1),
          curve: Curves.easeOutCubic,
        );
  }

  // ── PIN Boxes Row ─────────────────────────────────────────────────────────
  Widget _buildPinBoxesRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = ((constraints.maxWidth - 40) / 6).clamp(38.0, 52.0);
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (index) {
            final controller = _codeControllers[index];
            final focusNode = _codeFocusNodes[index];
            final hasFocus = focusNode.hasFocus;
            final hasText = controller.text.isNotEmpty;

            return Container(
              width: boxWidth,
              height: 54,
              decoration: BoxDecoration(
                color: AppColors.navyCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasFocus
                      ? AppColors.teal
                      : (hasText
                          ? Colors.white.withValues(alpha: 0.35)
                          : Colors.white.withValues(alpha: 0.10)),
                  width: hasFocus ? 1.8 : 1.2,
                ),
                boxShadow: hasFocus
                    ? [
                        BoxShadow(
                          color: AppColors.teal.withValues(alpha: 0.28),
                          blurRadius: 8,
                          spreadRadius: 0.5,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: KeyboardListener(
                  focusNode: FocusNode(),
                  onKeyEvent: (event) {
                    if (event is KeyDownEvent &&
                        event.logicalKey == LogicalKeyboardKey.backspace &&
                        controller.text.isEmpty &&
                        index > 0) {
                      _codeFocusNodes[index - 1].requestFocus();
                    }
                  },
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                    onChanged: (val) {
                      if (val.length > 1) {
                        // Handle paste of multiple characters
                        final digits = val.replaceAll(RegExp(r'\D'), '');
                        for (int i = 0;
                            i < digits.length && (index + i) < 6;
                            i++) {
                          _codeControllers[index + i].text = digits[i];
                        }
                        final targetIndex = (index + digits.length).clamp(0, 5);
                        _codeFocusNodes[targetIndex].requestFocus();
                        setState(() {});
                        return;
                      }
                      if (val.isNotEmpty && index < 5) {
                        _codeFocusNodes[index + 1].requestFocus();
                      }
                      setState(() {});
                    },
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  // ── Top Bar & Branding ────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _loading ? null : _handleBack,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.10),
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
    );
  }

  Widget _buildLogo() {
    return Center(
      child: Image.asset(
        AppConstants.assetLogoTransparent,
        width: 64,
        height: 64,
        fit: BoxFit.contain,
      ),
    );
  }
}
