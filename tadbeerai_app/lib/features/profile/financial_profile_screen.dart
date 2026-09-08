import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/config/api_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/l10n_context.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/financial_profile.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/profile_providers.dart';
import '../auth/auth_controller.dart';

/// User Persona & Financial Profile setup screen.
///
/// Implements the complete 4-step modern fintech onboarding questionnaire:
/// - Step 1 of 4: "Tell us about yourself" (Persona selection)
/// - Step 2 of 4: "Tell us about your finances" (Income & Essential spending inputs)
/// - Step 3 of 4: "Almost there! What are your primary financial goals?" (Primary goal selection)
/// - Step 4 of 4: "Review & confirm your information" (Comprehensive profile review & complete profile)
///
/// Also supports single-page mode ([isStepped] = false) for compact profile editing.
class FinancialProfileScreen extends ConsumerStatefulWidget {
  const FinancialProfileScreen({
    super.key,
    this.isStepped,
  });

  /// When true, displays the modern 4-step wizard.
  /// When false, displays the single-page form for direct profile edits.
  /// When null (default), displays direct edit mode if profile is already completed,
  /// or multi-step wizard if starting from scratch.
  final bool? isStepped;

  @override
  ConsumerState<FinancialProfileScreen> createState() =>
      _FinancialProfileScreenState();
}

class _FinancialProfileScreenState
    extends ConsumerState<FinancialProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _incomeController = TextEditingController();
  final _expensesController = TextEditingController();
  final _savingsController = TextEditingController();

  int _currentStep = 1;
  Persona? _persona;
  PrimaryGoal? _goal;
  bool _saving = false;
  bool _submitted = false;
  bool _showExpenseWarning = false;
  bool _prefilled = false;
  bool? _overrideStepped;

  bool get _isSteppedMode {
    if (_overrideStepped != null) return _overrideStepped!;
    if (widget.isStepped != null) return widget.isStepped!;
    final profile = ref.read(financialProfileControllerProvider).valueOrNull;
    if (profile != null && profile.profileCompleted) {
      return false;
    }
    return true;
  }

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    _incomeController.addListener(_onAmountChanged);
    _expensesController.addListener(_onAmountChanged);
    _savingsController.addListener(_onAmountChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = ref.read(authControllerProvider);
      if (user != null &&
          user.name.isNotEmpty &&
          user.name != 'Guest User' &&
          _nameController.text.isEmpty) {
        setState(() => _nameController.text = user.name);
      }
    });
  }

  void _prefill(FinancialProfile profile) {
    setState(() {
      if (profile.name != null && profile.name!.trim().isNotEmpty) {
        _nameController.text = profile.name!;
      }
      _persona = profile.persona;
      _goal = profile.primaryGoal;
      if (profile.monthlyIncome != null) {
        _incomeController.text =
            profile.monthlyIncome! > 0 || profile.monthlyIncome == 0
                ? profile.monthlyIncome!.toStringAsFixed(0)
                : '';
      }
      if (profile.monthlyEssentialExpenses != null) {
        _expensesController.text = profile.monthlyEssentialExpenses! > 0 ||
                profile.monthlyEssentialExpenses == 0
            ? profile.monthlyEssentialExpenses!.toStringAsFixed(0)
            : '';
      }
      if (profile.totalSavings != null) {
        _savingsController.text =
            profile.totalSavings! > 0 || profile.totalSavings == 0
                ? profile.totalSavings!.toStringAsFixed(0)
                : '';
      }
    });
  }

  void _onAmountChanged() {
    final income =
        double.tryParse(_incomeController.text.replaceAll(',', '').trim()) ?? 0;
    final expenses =
        double.tryParse(_expensesController.text.replaceAll(',', '').trim()) ??
            0;
    final shouldWarn = expenses > income && income >= 0 && expenses > 0;
    if (shouldWarn != _showExpenseWarning) {
      setState(() => _showExpenseWarning = shouldWarn);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _incomeController.dispose();
    _expensesController.dispose();
    _savingsController.dispose();
    super.dispose();
  }

  // ── Currency Formatting Helper ─────────────────────────────────────────

  String _formatAmount(String text) {
    final parsed = double.tryParse(text.replaceAll(',', '').trim()) ?? 0;
    final integerPart = parsed.toStringAsFixed(0);
    final chars = integerPart.split('');
    final formatted = <String>[];
    for (int i = 0; i < chars.length; i++) {
      if (i > 0 && (chars.length - i) % 3 == 0) {
        formatted.add(',');
      }
      formatted.add(chars[i]);
    }
    return 'PKR ${formatted.join()}';
  }

  // ── Validators ─────────────────────────────────────────────────────────

  String? _validateIncome(String? value) {
    final l10n = context.l10n;
    final text = (value ?? '').replaceAll(',', '').trim();
    if (text.isEmpty) return l10n.profileValidationIncome;
    final parsed = double.tryParse(text);
    if (parsed == null) return l10n.profileValidationIncome;
    if (parsed < 0) return l10n.profileValidationIncomeNegative;
    return null;
  }

  String? _validateExpenses(String? value) {
    final l10n = context.l10n;
    final text = (value ?? '').replaceAll(',', '').trim();
    if (text.isEmpty) return l10n.profileValidationExpenses;
    final parsed = double.tryParse(text);
    if (parsed == null) return l10n.profileValidationExpenses;
    if (parsed < 0) return l10n.profileValidationExpensesNegative;
    return null;
  }

  // ── Save Profile ───────────────────────────────────────────────────────

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _submitted = true);

    if (_isSteppedMode) {
      if (_persona == null || _goal == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _persona == null
                  ? context.l10n.profileValidationPersona
                  : context.l10n.profileValidationGoal,
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    } else {
      final formValid = _formKey.currentState?.validate() ?? false;
      if (!formValid || _persona == null || _goal == null) return;
    }

    setState(() => _saving = true);

    final incomeText = _incomeController.text.replaceAll(',', '').trim();
    final expensesText = _expensesController.text.replaceAll(',', '').trim();
    final savingsText = _savingsController.text.replaceAll(',', '').trim();

    final nameText = _nameController.text.trim();
    final profile = FinancialProfile(
      name: nameText.isNotEmpty ? nameText : null,
      persona: _persona,
      monthlyIncome: double.tryParse(incomeText) ?? 0,
      monthlyEssentialExpenses: double.tryParse(expensesText) ?? 0,
      totalSavings:
          savingsText.isNotEmpty ? double.tryParse(savingsText) : null,
      primaryGoal: _goal,
      profileCompleted: true,
    );

    try {
      await ref
          .read(financialProfileControllerProvider.notifier)
          .saveProfile(profile);
      if (!mounted) return;

      if (nameText.isNotEmpty) {
        ref.read(authControllerProvider.notifier).updateUserName(nameText);
      }

      final currentUser = ref.read(authControllerProvider);
      if (currentUser != null && !currentUser.isGuest) {
        _syncPersonaToBackend(currentUser, profile);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.profileSaved),
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        context.go('/home');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.errorGeneric),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _syncPersonaToBackend(AppUser user, FinancialProfile profile) {
    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          connectTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );
      dio.post(
        '/users/persona',
        data: {
          'user_id': user.id,
          'persona': profile.persona?.name,
          'primary_goal': profile.primaryGoal?.name,
          'monthly_income': profile.monthlyIncome,
          'monthly_essential_expenses': profile.monthlyEssentialExpenses,
          'total_savings': profile.totalSavings,
          'is_guest': false,
          'name': profile.name ?? user.name,
          'email': user.email,
        },
      ).catchError((_) {
        return Response(requestOptions: RequestOptions(path: ''));
      });
    } catch (_) {}
  }

  // ── Stepped Navigation Handlers ────────────────────────────────────────

  void _onContinueStep1() {
    if (_persona == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.profileValidationPersona),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _currentStep = 2);
  }

  void _onContinueStep2() {
    setState(() => _currentStep = 3);
  }

  void _onContinueStep3() {
    if (_goal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.profileValidationGoal),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _currentStep = 4);
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(financialProfileControllerProvider);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    ref.listen<AsyncValue<FinancialProfile?>>(
      financialProfileControllerProvider,
      (prev, next) {
        if (_prefilled) return;
        final profile = next.valueOrNull;
        if (profile != null && profile.profileCompleted) {
          _prefilled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _prefill(profile);
          });
        }
      },
    );

    final currentUser = ref.watch(authControllerProvider);
    final isGuest = currentUser?.isGuest ?? false;

    return Scaffold(
      backgroundColor: isDark ? AppColors.navyBg : Colors.transparent,
      body: DecoratedBox(
        decoration: BoxDecoration(
          color: isDark ? AppColors.navyBg : null,
          gradient: isDark ? null : AppColors.lightThemeGradient,
        ),
        child: SafeArea(
          child: profileAsync.when(
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
            data: (_) => _isSteppedMode
                ? _buildSteppedWizard(l10n,
                    isGuest: isGuest, currentUser: currentUser)
                : _buildSinglePageForm(l10n, theme, scheme),
          ),
        ),
      ),
    );
  }

  // ── Multi-Step Wizard View (Steps 1 to 4) ──────────────────────────────

  Widget _buildSteppedWizard(
    AppLocalizations l10n, {
    required bool isGuest,
    required AppUser? currentUser,
  }) {
    return Column(
      children: [
        // ── Top Navigation Bar & 4 Progress Segments ─────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 20, 6),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded,
                    color: isDark ? Colors.white : AppColors.textOnLight),
                onPressed: () {
                  if (_currentStep > 1) {
                    setState(() => _currentStep--);
                  } else {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    } else {
                      context.go('/home');
                    }
                  }
                },
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Row(
                  children: [
                    for (int i = 1; i <= 4; i++) ...[
                      Expanded(
                        child: Container(
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: i <= _currentStep
                                ? const Color(0xFF10B981)
                                : const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'Step $_currentStep of 4',
                style: GoogleFonts.inter(
                  color: isDark
                      ? AppColors.textOnDarkSecondary
                      : AppColors.textOnLightSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        // ── Mode Indicator Pill (Guest vs Registered) ────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(
            children: [
              // Flexible so the pill is capped at the row width on narrow
              // screens instead of overflowing by its natural size.
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isGuest
                        ? const Color(0xFF334155).withValues(alpha: 0.5)
                        : const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isGuest
                          ? const Color(0xFF475569)
                          : const Color(0xFF10B981).withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isGuest
                            ? Icons.person_outline_rounded
                            : Icons.verified_user_outlined,
                        size: 13,
                        color: isGuest
                            ? const Color(0xFFCBD5E1)
                            : isDark
                                ? const Color(0xFF10B981)
                                : AppColors.tealOnLight,
                      ),
                      const SizedBox(width: 6),
                      // Flexible lets the long guest label wrap onto a second
                      // line instead of pushing the pill past the right edge.
                      Flexible(
                        child: Text(
                          isGuest
                              ? 'Guest Mode · Saved locally on device · Alerts inactive'
                              : 'Registered Account · Price alerts active',
                          style: GoogleFonts.inter(
                            color: isGuest
                                ? const Color(0xFFCBD5E1)
                                : isDark
                                    ? const Color(0xFF10B981)
                                    : AppColors.tealOnLight,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => setState(() => _overrideStepped = false),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isDark ? AppColors.teal : const Color(0xFF0D9488))
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: (isDark ? AppColors.teal : const Color(0xFF0D9488))
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.edit_note_rounded,
                        size: 14,
                        color:
                            isDark ? AppColors.teal : const Color(0xFF0D9488),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Direct Edit Mode',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color:
                              isDark ? AppColors.teal : const Color(0xFF0D9488),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Step Content ──────────────────────────────────────────────
        Expanded(
          child: switch (_currentStep) {
            1 => _buildStep1(l10n),
            2 => _buildStep2(l10n),
            3 => _buildStep3(l10n),
            _ => _buildStep4(l10n, isGuest: isGuest, currentUser: currentUser),
          },
        ),
      ],
    );
  }

  // ── Step 1: Tell Us About Yourself ──────────────────────────────────────

  Widget _buildStep1(AppLocalizations l10n) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Text.rich(
                TextSpan(
                  text: 'Tell us about\n',
                  style: GoogleFonts.inter(
                    color: isDark ? Colors.white : AppColors.textOnLight,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    height: 1.2,
                  ),
                  children: [
                    TextSpan(
                      text: 'yourself',
                      style: TextStyle(
                        color: isDark
                            ? const Color(0xFF10B981)
                            : AppColors.tealOnLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'This helps Tadbeer AI personalize your financial insights.',
                style: GoogleFonts.inter(
                  color: isDark
                      ? AppColors.textOnDarkSecondary
                      : AppColors.textOnLightSecondary,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),

              // Full Name Input
              Text(
                'What should Tadbeer call you?',
                style: GoogleFonts.inter(
                  color: isDark ? Colors.white : AppColors.textOnLight,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              AppTextField(
                label: 'Your Name',
                controller: _nameController,
                hintText: 'e.g. Hashim',
                prefixIcon: const Icon(
                  Icons.person_outline_rounded,
                  color: Color(0xFF10B981),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 24),

              Text(
                'What best describes you?',
                style: GoogleFonts.inter(
                  color: isDark ? Colors.white : AppColors.textOnLight,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              _SteppedPersonaCard(
                persona: Persona.student,
                title: l10n.profilePersonaStudent,
                subtitle: 'Managing allowance, education costs and savings.',
                icon: Icons.school_rounded,
                iconColor: const Color(0xFF10B981),
                isSelected: _persona == Persona.student,
                onTap: () => setState(() => _persona = Persona.student),
              ),
              _SteppedPersonaCard(
                persona: Persona.salaried,
                title: l10n.profilePersonaSalaried,
                subtitle: 'Managing salary, bills, savings and goals.',
                icon: Icons.work_rounded,
                iconColor: const Color(0xFF2DD4BF),
                isSelected: _persona == Persona.salaried,
                onTap: () => setState(() => _persona = Persona.salaried),
              ),
              _SteppedPersonaCard(
                persona: Persona.shopOwner,
                title: l10n.profilePersonaShopOwner,
                subtitle:
                    'Managing sales, inventory and daily business expenses.',
                icon: Icons.store_rounded,
                iconColor: const Color(0xFF38BDF8),
                isSelected: _persona == Persona.shopOwner,
                onTap: () => setState(() => _persona = Persona.shopOwner),
              ),
              _SteppedPersonaCard(
                persona: Persona.businessOwner,
                title: l10n.profilePersonaBusinessOwner,
                subtitle: 'Managing business income, expenses and cash flow.',
                icon: Icons.apartment_rounded,
                iconColor: const Color(0xFFA78BFA),
                isSelected: _persona == Persona.businessOwner,
                onTap: () => setState(() => _persona = Persona.businessOwner),
              ),
              const SizedBox(height: 12),
              const _SecurityBanner(),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            math.max(MediaQuery.of(context).padding.bottom, 16),
          ),
          child: _ContinueButton(onPressed: _onContinueStep1),
        ),
      ],
    );
  }

  // ── Step 2: Tell Us About Your Finances ─────────────────────────────────

  Widget _buildStep2(AppLocalizations l10n) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Text.rich(
                TextSpan(
                  text: 'Tell us about\n',
                  style: GoogleFonts.inter(
                    color: isDark ? Colors.white : AppColors.textOnLight,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    height: 1.2,
                  ),
                  children: [
                    TextSpan(
                      text: 'your finances',
                      style: TextStyle(
                        color: isDark
                            ? const Color(0xFF10B981)
                            : AppColors.tealOnLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "What's your typical monthly income?",
                style: GoogleFonts.inter(
                  color: isDark ? Colors.white : AppColors.textOnLight,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              _AmountInputCard(
                label: 'Income',
                controller: _incomeController,
                onChanged: _onAmountChanged,
              ),
              const SizedBox(height: 8),
              _QuickAmountPresets(
                controller: _incomeController,
                presets: const [50000, 100000, 200000, 350000],
                onSelected: _onAmountChanged,
              ),
              const SizedBox(height: 6),
              Text(
                "Enter 0 if you don't have a regular income.",
                style: GoogleFonts.inter(
                  color: isDark
                      ? AppColors.textOnDarkSecondary
                      : AppColors.textOnLightSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "What's your typical monthly essential spending?",
                style: GoogleFonts.inter(
                  color: isDark ? Colors.white : AppColors.textOnLight,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              _AmountInputCard(
                label: 'Essential Expenses',
                controller: _expensesController,
                onChanged: _onAmountChanged,
              ),
              const SizedBox(height: 8),
              _QuickAmountPresets(
                controller: _expensesController,
                presets: const [30000, 60000, 120000, 200000],
                onSelected: _onAmountChanged,
              ),
              const SizedBox(height: 6),
              Text(
                'This includes rent, bills, groceries, transport, etc.',
                style: GoogleFonts.inter(
                  color: isDark
                      ? AppColors.textOnDarkSecondary
                      : AppColors.textOnLightSecondary,
                  fontSize: 13,
                ),
              ),
              if (_showExpenseWarning) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.profileExpensesWarning,
                          style: GoogleFonts.inter(
                            color: AppColors.warning,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text(
                "What's your current total savings? (Optional)",
                style: GoogleFonts.inter(
                  color: isDark ? Colors.white : AppColors.textOnLight,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              _AmountInputCard(
                label: 'Total Savings',
                controller: _savingsController,
                onChanged: _onAmountChanged,
              ),
              const SizedBox(height: 6),
              Text(
                'Used to estimate your emergency fund runway in months.',
                style: GoogleFonts.inter(
                  color: isDark
                      ? AppColors.textOnDarkSecondary
                      : AppColors.textOnLightSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),
              const _TipBanner(
                text:
                    'You can update this information anytime from your profile.',
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            math.max(MediaQuery.of(context).padding.bottom, 12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ContinueButton(onPressed: _onContinueStep2),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => setState(() => _currentStep = 1),
                child: Text(
                  'Back',
                  style: GoogleFonts.inter(
                    color: isDark
                        ? const Color(0xFF10B981)
                        : AppColors.tealOnLight,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Step 3: What Are Your Primary Financial Goals? ──────────────────────

  Widget _buildStep3(AppLocalizations l10n) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Text(
                'Almost there!',
                style: GoogleFonts.inter(
                  color: isDark ? Colors.white : AppColors.textOnLight,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'What are your primary\nfinancial goals?',
                style: GoogleFonts.inter(
                  color:
                      isDark ? const Color(0xFF10B981) : AppColors.tealOnLight,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select what matters most to you right now.',
                style: GoogleFonts.inter(
                  color: isDark
                      ? AppColors.textOnDarkSecondary
                      : AppColors.textOnLightSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),

              // 6 Goals (2x3 Grid)
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.78,
                children: [
                  _GoalDetailedCard(
                    goal: PrimaryGoal.emergencyFund,
                    title: 'Emergency\nFund',
                    subtitle: 'Build a safety net for unexpected expenses.',
                    icon: Icons.shield_rounded,
                    iconColor: const Color(0xFF10B981),
                    isSelected: _goal == PrimaryGoal.emergencyFund,
                    onTap: () =>
                        setState(() => _goal = PrimaryGoal.emergencyFund),
                  ),
                  _GoalDetailedCard(
                    goal: PrimaryGoal.saveMore,
                    title: 'Save More\n',
                    subtitle: 'Grow my savings and build wealth.',
                    icon: Icons.savings_rounded,
                    iconColor: const Color(0xFFF472B6),
                    isSelected: _goal == PrimaryGoal.saveMore,
                    onTap: () => setState(() => _goal = PrimaryGoal.saveMore),
                  ),
                  _GoalDetailedCard(
                    goal: PrimaryGoal.education,
                    title: 'Education\n',
                    subtitle:
                        "Save for my education or my children's education.",
                    icon: Icons.school_rounded,
                    iconColor: const Color(0xFF38BDF8),
                    isSelected: _goal == PrimaryGoal.education,
                    onTap: () => setState(() => _goal = PrimaryGoal.education),
                  ),
                  _GoalDetailedCard(
                    goal: PrimaryGoal.newDevice,
                    title: 'New Laptop /\nDevice',
                    subtitle: 'Save for a new laptop or device.',
                    icon: Icons.laptop_mac_rounded,
                    iconColor: const Color(0xFF22D3EE),
                    isSelected: _goal == PrimaryGoal.newDevice,
                    onTap: () => setState(() => _goal = PrimaryGoal.newDevice),
                  ),
                  _GoalDetailedCard(
                    goal: PrimaryGoal.businessGrowth,
                    title: 'Business\nGrowth',
                    subtitle: 'Invest in my business and grow it.',
                    icon: Icons.trending_up_rounded,
                    iconColor: const Color(0xFF34D399),
                    isSelected: _goal == PrimaryGoal.businessGrowth,
                    onTap: () =>
                        setState(() => _goal = PrimaryGoal.businessGrowth),
                  ),
                  _GoalDetailedCard(
                    goal: PrimaryGoal.reduceSpending,
                    title: 'Reduce\nSpending',
                    subtitle: 'Reduce debt and control my expenses.',
                    icon: Icons.south_rounded,
                    iconColor: const Color(0xFFF87171),
                    isSelected: _goal == PrimaryGoal.reduceSpending,
                    onTap: () =>
                        setState(() => _goal = PrimaryGoal.reduceSpending),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Full-width "Other" Card
              _GoalOtherCard(
                isSelected: _goal == PrimaryGoal.other,
                onTap: () => setState(() => _goal = PrimaryGoal.other),
              ),
              const SizedBox(height: 18),

              const _TipBanner(
                text: 'You can change your goals anytime from your profile.',
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            math.max(MediaQuery.of(context).padding.bottom, 12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ContinueButton(onPressed: _onContinueStep3),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => setState(() => _currentStep = 2),
                child: Text(
                  'Back',
                  style: GoogleFonts.inter(
                    color: isDark
                        ? const Color(0xFF10B981)
                        : AppColors.tealOnLight,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Step 4: Review & Confirm Your Information ───────────────────────────

  Widget _buildStep4(
    AppLocalizations l10n, {
    required bool isGuest,
    required AppUser? currentUser,
  }) {
    final incomeStr = _incomeController.text.trim().isEmpty
        ? 'PKR 0'
        : _formatAmount(_incomeController.text);
    final expensesStr = _expensesController.text.trim().isEmpty
        ? 'PKR 0'
        : _formatAmount(_expensesController.text);
    final savingsStr = _savingsController.text.trim().isEmpty
        ? 'Not specified'
        : _formatAmount(_savingsController.text);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Text(
                'Review & confirm',
                style: GoogleFonts.inter(
                  color: isDark ? Colors.white : AppColors.textOnLight,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'your information',
                style: GoogleFonts.inter(
                  color:
                      isDark ? const Color(0xFF10B981) : AppColors.tealOnLight,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please review your information before completing your profile.',
                style: GoogleFonts.inter(
                  color: isDark
                      ? AppColors.textOnDarkSecondary
                      : AppColors.textOnLightSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),

              // Profile Summary Section Title
              Text(
                'Your Profile Summary',
                style: GoogleFonts.inter(
                  color:
                      isDark ? const Color(0xFF2DD4BF) : AppColors.tealOnLight,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),

              // Summary Card with Rows
              Container(
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
                  children: [
                    if (_nameController.text.trim().isNotEmpty) ...[
                      _SummaryRow(
                        icon: Icons.badge_outlined,
                        label: 'Full Name',
                        value: _nameController.text.trim(),
                      ),
                      Divider(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : AppColors.borderLight,
                        height: 1,
                      ),
                    ],
                    _SummaryRow(
                      icon: Icons.person_outline_rounded,
                      label: 'You are',
                      value: _personaLabel(_persona ?? Persona.student),
                    ),
                    Divider(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : AppColors.borderLight,
                      height: 1,
                    ),
                    _SummaryRow(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Monthly Income',
                      value: incomeStr,
                    ),
                    Divider(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : AppColors.borderLight,
                      height: 1,
                    ),
                    _SummaryRow(
                      icon: Icons.shopping_bag_outlined,
                      label: 'Essential Monthly Spending',
                      value: expensesStr,
                    ),
                    Divider(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : AppColors.borderLight,
                      height: 1,
                    ),
                    _SummaryRow(
                      icon: Icons.savings_outlined,
                      label: 'Current Savings',
                      value: savingsStr,
                    ),
                    Divider(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : AppColors.borderLight,
                      height: 1,
                    ),
                    _SummaryRow(
                      icon: Icons.track_changes_rounded,
                      label: 'Primary Goal',
                      value: _goalLabel(_goal ?? PrimaryGoal.emergencyFund),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Alert Eligibility & Notification Status Card
              _buildAlertEligibilityCard(isGuest, currentUser),
              const SizedBox(height: 16),

              // Security Trust Card
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.navyCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : AppColors.borderLight,
                    width: 1.2,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        color: Color(0xFF10B981),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your information is secure',
                            style: GoogleFonts.inter(
                              color:
                                  isDark ? Colors.white : AppColors.textOnLight,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Your data is encrypted and will only be used to personalize your experience.',
                            style: GoogleFonts.inter(
                              color: isDark
                                  ? AppColors.textOnDarkSecondary
                                  : AppColors.textOnLightSecondary,
                              fontSize: 12.5,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        // Complete Profile Button
        Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            math.max(MediaQuery.of(context).padding.bottom, 12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CompleteProfileButton(
                onPressed: _save,
                loading: _saving,
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed:
                    _saving ? null : () => setState(() => _currentStep = 3),
                child: Text(
                  'Back',
                  style: GoogleFonts.inter(
                    color: isDark
                        ? const Color(0xFF10B981)
                        : AppColors.tealOnLight,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAlertEligibilityCard(bool isGuest, AppUser? currentUser) {
    if (isGuest) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFEAB308).withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFEAB308).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_off_outlined,
                color: Color(0xFFEAB308),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Alerts Disabled in Guest Mode',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFFDE047),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your persona is saved locally on this device. Real-time SMS and Push price alerts are reserved for registered accounts. You can create an account anytime to activate alerts.',
                    style: GoogleFonts.inter(
                      color: isDark
                          ? const Color(0xFFCBD5E1)
                          : AppColors.textOnLightSecondary,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.3),
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_active_outlined,
              color: Color(0xFF10B981),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Real-Time Alerts Enabled',
                  style: GoogleFonts.inter(
                    color: isDark ? Colors.white : AppColors.textOnLight,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your account is registered for timely alerts when fuel, gold, exchange rates, or essential commodity prices change.',
                  style: GoogleFonts.inter(
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : AppColors.textOnLightSecondary,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Single-Page Form (Preserved for Tests & Quick Editing) ───────────────

  Widget _buildSinglePageForm(
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme scheme,
  ) {
    return Form(
      key: _formKey,
      child: ListView(
        key: const ValueKey('profile_form_list'),
        physics: const ClampingScrollPhysics(),
        cacheExtent: 3000,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Row(
            children: [
              if (!_saving)
                IconButton(
                  icon: Icon(Icons.arrow_back,
                      color: isDark ? Colors.white : AppColors.textOnLight),
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    } else {
                      context.go('/home');
                    }
                  },
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.profileTitle,
                  style: GoogleFonts.inter(
                    color: isDark ? Colors.white : AppColors.textOnLight,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              InkWell(
                onTap: () => setState(() => _overrideStepped = true),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isDark ? AppColors.teal : const Color(0xFF0D9488))
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: (isDark ? AppColors.teal : const Color(0xFF0D9488))
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_stories_outlined,
                        size: 14,
                        color:
                            isDark ? AppColors.teal : const Color(0xFF0D9488),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Step Wizard',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color:
                              isDark ? AppColors.teal : const Color(0xFF0D9488),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.profileBody,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          AppTextField(
            label: 'Your Name',
            controller: _nameController,
            hintText: 'e.g. Hashim Khan',
            prefixIcon: const Icon(
              Icons.person_outline_rounded,
              color: AppColors.teal,
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              l10n.profileWhoAreYou,
              style: theme.textTheme.titleMedium,
            ),
          ),
          _PersonaGrid(
            selected: _persona,
            onSelect: (p) => setState(() => _persona = p),
            personaLabel: _personaLabel,
            personaIcon: _personaIcon,
          ),
          if (_persona == null && _submitted) ...[
            const SizedBox(height: 8),
            Text(
              l10n.profileValidationPersona,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.error,
              ),
            ),
          ],
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              l10n.profileMonthlyFinances,
              style: theme.textTheme.titleMedium,
            ),
          ),
          AppTextField(
            label: l10n.profileIncomeLabel,
            controller: _incomeController,
            validator: _validateIncome,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              l10n.profileIncomeHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: l10n.profileExpensesLabel,
            controller: _expensesController,
            validator: _validateExpenses,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              l10n.profileExpensesHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Total Savings (Optional)',
            controller: _savingsController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Used to estimate emergency runway (months). Leave blank if none.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          if (_showExpenseWarning) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.profileExpensesWarning,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.warning,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              l10n.profileGoalSection,
              style: theme.textTheme.titleMedium,
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: PrimaryGoal.values.map((goal) {
              final isSelected = _goal == goal;
              return _GoalCard(
                goal: goal,
                label: _goalLabel(goal),
                icon: _goalIcon(goal),
                isSelected: isSelected,
                onTap: () => setState(() => _goal = goal),
              );
            }).toList(),
          ),
          if (_goal == null && _submitted) ...[
            const SizedBox(height: 8),
            Text(
              l10n.profileValidationGoal,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.error,
              ),
            ),
          ],
          const SizedBox(height: 32),
          AppButton(
            label: l10n.profileSave,
            onPressed: _save,
            loading: _saving,
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed:
                  _saving ? null : () => Navigator.of(context).maybePop(),
              child: Text(l10n.profileNotNow),
            ),
          ),
        ],
      ),
    );
  }

  String _personaLabel(Persona p) {
    final l10n = context.l10n;
    return switch (p) {
      Persona.student => l10n.profilePersonaStudent,
      Persona.salaried => l10n.profilePersonaSalaried,
      Persona.businessOwner => l10n.profilePersonaBusinessOwner,
      Persona.shopOwner => l10n.profilePersonaShopOwner,
    };
  }

  IconData _personaIcon(Persona p) => switch (p) {
        Persona.student => Icons.school_rounded,
        Persona.salaried => Icons.work_rounded,
        Persona.businessOwner => Icons.business_center_rounded,
        Persona.shopOwner => Icons.store_rounded,
      };

  String _goalLabel(PrimaryGoal g) {
    final l10n = context.l10n;
    return switch (g) {
      PrimaryGoal.emergencyFund => l10n.profileGoalEmergencyFund,
      PrimaryGoal.saveMore => l10n.profileGoalSaveMore,
      PrimaryGoal.education => l10n.profileGoalEducation,
      PrimaryGoal.newDevice => l10n.profileGoalNewDevice,
      PrimaryGoal.businessGrowth => l10n.profileGoalBusinessGrowth,
      PrimaryGoal.reduceSpending => l10n.profileGoalReduceSpending,
      PrimaryGoal.other => l10n.profileGoalOther,
    };
  }

  IconData _goalIcon(PrimaryGoal g) => switch (g) {
        PrimaryGoal.emergencyFund => Icons.shield_rounded,
        PrimaryGoal.saveMore => Icons.savings_rounded,
        PrimaryGoal.education => Icons.school_rounded,
        PrimaryGoal.newDevice => Icons.laptop_mac_rounded,
        PrimaryGoal.businessGrowth => Icons.trending_up_rounded,
        PrimaryGoal.reduceSpending => Icons.south_rounded,
        PrimaryGoal.other => Icons.more_horiz_rounded,
      };
}

// ── Step 1 Persona Card ─────────────────────────────────────────────────────

class _SteppedPersonaCard extends StatelessWidget {
  const _SteppedPersonaCard({
    required this.persona,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.isSelected,
    required this.onTap,
  });

  final Persona persona;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF10B981).withValues(alpha: 0.10)
            : (isDark ? AppColors.navyCard : AppColors.lightCard),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF10B981)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : AppColors.borderLight),
          width: isSelected ? 1.5 : 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, size: 22, color: iconColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          color: isDark ? Colors.white : AppColors.textOnLight,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          color: isDark
                              ? AppColors.textOnDarkSecondary
                              : AppColors.textOnLightSecondary,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF10B981)
                          : const Color(0xFF475569),
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Center(
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Step 2 Amount Input Card ────────────────────────────────────────────────

class _AmountInputCard extends StatelessWidget {
  const _AmountInputCard({
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.navyCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppColors.borderLight,
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: Color(0xFF10B981),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: isDark
                        ? AppColors.textOnDarkSecondary
                        : AppColors.textOnLightSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      'PKR ',
                      style: GoogleFonts.inter(
                        color: isDark ? Colors.white : AppColors.textOnLight,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Expanded(
                      child: TextFormField(
                        controller: controller,
                        onChanged: (_) => onChanged(),
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.inter(
                          color: isDark ? Colors.white : AppColors.textOnLight,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                        cursorColor: AppColors.teal,
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, val, __) {
              if (val.text.isEmpty) return const SizedBox.shrink();
              return GestureDetector(
                onTap: () {
                  controller.clear();
                  onChanged();
                },
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.close_rounded,
                    color:
                        isDark ? Colors.white54 : AppColors.textOnLightTertiary,
                    size: 18,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Step 2 Quick Amount Presets ──────────────────────────────────────────────

class _QuickAmountPresets extends StatelessWidget {
  const _QuickAmountPresets({
    required this.controller,
    required this.presets,
    required this.onSelected,
  });

  final TextEditingController controller;
  final List<int> presets;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: presets.map((amount) {
          final label = amount >= 1000000
              ? '${(amount / 1000000).toStringAsFixed(1)}M'
              : '${(amount / 1000).toStringAsFixed(0)}k';
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                HapticFeedback.selectionClick();
                controller.text = amount.toString();
                onSelected();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B).withValues(alpha: 0.7)
                      : AppColors.lightSurfaceVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : AppColors.borderLight,
                    width: 1,
                  ),
                ),
                child: Text(
                  'PKR $label',
                  style: GoogleFonts.inter(
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : AppColors.textOnLightSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Step 3 Detailed Goal Card (with Subtitles) ──────────────────────────────

class _GoalDetailedCard extends StatelessWidget {
  const _GoalDetailedCard({
    required this.goal,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.isSelected,
    required this.onTap,
  });

  final PrimaryGoal goal;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF10B981).withValues(alpha: 0.12)
            : (isDark ? AppColors.navyCard : AppColors.lightCard),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF10B981)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : AppColors.borderLight),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Stack(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      color: isSelected ? const Color(0xFF10B981) : iconColor,
                      size: 24,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: isDark ? Colors.white : AppColors.textOnLight,
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w600,
                        height: 1.15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: isDark
                            ? AppColors.textOnDarkSecondary
                            : AppColors.textOnLightSecondary,
                        fontSize: 9.5,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Positioned(
                  top: 6,
                  right: 6,
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF10B981),
                    size: 16,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Step 3 Full-Width "Other" Goal Card ─────────────────────────────────────

class _GoalOtherCard extends StatelessWidget {
  const _GoalOtherCard({
    required this.isSelected,
    required this.onTap,
  });

  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF10B981).withValues(alpha: 0.12)
            : (isDark ? AppColors.navyCard : AppColors.lightCard),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF10B981)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : AppColors.borderLight),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : AppColors.lightSurfaceVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.more_horiz_rounded,
                    color: isSelected
                        ? const Color(0xFF10B981)
                        : (isDark
                            ? AppColors.textOnDarkSecondary
                            : AppColors.textOnLightSecondary),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Other',
                        style: GoogleFonts.inter(
                          color: isDark ? Colors.white : AppColors.textOnLight,
                          fontSize: 14.5,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'I have a different goal in mind.',
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
                if (isSelected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF10B981),
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Step 4 Summary Row Widget ───────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF10B981), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: isDark ? Colors.white : AppColors.textOnLight,
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              color: isDark ? Colors.white : AppColors.textOnLight,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Security Trust Banner ───────────────────────────────────────────────────

class _SecurityBanner extends StatelessWidget {
  const _SecurityBanner();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.navyCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppColors.borderLight,
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: Color(0xFF10B981),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your information is secure and will only be used to personalize your experience.',
              style: GoogleFonts.inter(
                color: isDark
                    ? AppColors.textOnDarkSecondary
                    : AppColors.textOnLightSecondary,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tip Banner ──────────────────────────────────────────────────────────────

class _TipBanner extends StatelessWidget {
  const _TipBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.navyCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppColors.borderLight,
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFFBBF24).withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lightbulb_outline_rounded,
              color: Color(0xFFFBBF24),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                color: isDark
                    ? AppColors.textOnDarkSecondary
                    : AppColors.textOnLightSecondary,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Continue Gradient Pill Button ───────────────────────────────────────────

class _ContinueButton extends StatelessWidget {
  const _ContinueButton({
    required this.onPressed,
  });

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 54,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF2DD4BF), Color(0xFF10B981)]
              : const [Color(0xFF010717), Color(0xFF0D1C34)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(27),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? const Color(0xFF10B981).withValues(alpha: 0.35)
                : AppColors.navyBg.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(27),
          onTap: onPressed,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Continue',
                  style: GoogleFonts.inter(
                    color: isDark ? AppColors.navyBg : Colors.white,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: isDark ? AppColors.navyBg : Colors.white,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Complete Profile Gradient Pill Button (Step 4 CTA) ──────────────────────

class _CompleteProfileButton extends StatelessWidget {
  const _CompleteProfileButton({
    required this.onPressed,
    this.loading = false,
  });

  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 54,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF2DD4BF), Color(0xFF10B981)]
              : const [Color(0xFF010717), Color(0xFF0D1C34)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(27),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? const Color(0xFF10B981).withValues(alpha: 0.35)
                : AppColors.navyBg.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(27),
          onTap: loading ? null : onPressed,
          child: Center(
            child: loading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: isDark ? AppColors.navyBg : Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Complete Profile',
                        style: GoogleFonts.inter(
                          color: isDark ? AppColors.navyBg : Colors.white,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.check_rounded,
                        color: isDark ? AppColors.navyBg : Colors.white,
                        size: 22,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ── Single-Page Form Helpers (Preserved for Tests & Quick Editing) ──────────

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.isSelected,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final PrimaryGoal goal;
  final bool isSelected;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SelectionCard(
      label: label,
      icon: icon,
      isSelected: isSelected,
      onTap: onTap,
    );
  }
}

class _PersonaGrid extends StatelessWidget {
  const _PersonaGrid({
    required this.selected,
    required this.onSelect,
    required this.personaLabel,
    required this.personaIcon,
  });

  final Persona? selected;
  final ValueChanged<Persona> onSelect;
  final String Function(Persona) personaLabel;
  final IconData Function(Persona) personaIcon;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.55,
      children: Persona.values.map((persona) {
        return _SelectionCard(
          label: personaLabel(persona),
          icon: personaIcon(persona),
          isSelected: selected == persona,
          onTap: () => onSelect(persona),
        );
      }).toList(),
    );
  }
}

class _SelectionCard extends StatelessWidget {
  const _SelectionCard({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? scheme.primary.withValues(alpha: 0.12)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? scheme.primary
                : scheme.outline.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? scheme.primary : null,
                  ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: scheme.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
