import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/financial_profile.dart';
import '../../providers/app_settings_providers.dart';
import '../../providers/profile_providers.dart';
import '../auth/auth_controller.dart';

/// Modern, production-grade User Profile and Settings screen.
///
/// Implements Tadbeer AI's signature dark aesthetic, rich identity card,
/// grouped configuration options, interactive sheets for data viewing/editing,
/// live language switching, and secure sign out.
class UserProfileScreen extends ConsumerWidget {
  const UserProfileScreen({super.key});

  String _formatPersonaTitle(Persona? persona) {
    if (persona == null) return 'Financial Explorer';
    switch (persona) {
      case Persona.salaried:
        return 'Salaried Professional';
      case Persona.student:
        return 'Student';
      case Persona.businessOwner:
        return 'Business Owner';
      case Persona.shopOwner:
        return 'Shop Owner / Retailer';
    }
  }

  String _formatCurrency(double? amount) {
    if (amount == null) return 'Rs. 0';
    final intAmount = amount.toInt();
    final buffer = StringBuffer();
    final str = intAmount.toString();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(str[i]);
    }
    return 'Rs. $buffer';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider);
    final profileAsync = ref.watch(financialProfileControllerProvider);
    final profile = profileAsync.valueOrNull;
    final currentLocale = ref.watch(appLocaleProvider);
    final currentLanguage = AppLanguage.fromLocale(currentLocale);

    final displayName = (user?.name.trim().isNotEmpty == true)
        ? user!.name.trim()
        : (profile?.name?.trim().isNotEmpty == true
            ? profile!.name!.trim()
            : 'Tadbeer User');

    final displayEmail = (user?.email.trim().isNotEmpty == true)
        ? user!.email.trim()
        : 'guest@tadbeer.ai';

    final personaTitle = _formatPersonaTitle(profile?.persona);
    final isGuest = user?.isGuest ?? true;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.navyBg : Colors.transparent,
      body: DecoratedBox(
        decoration: BoxDecoration(
          color: isDark ? AppColors.navyBg : null,
          gradient: isDark ? null : AppColors.lightThemeGradient,
        ),
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Top Navigation Bar ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      _NavBackButton(
                        onTap: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/home');
                          }
                        },
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'My Profile',
                        style: GoogleFonts.inter(
                          color: isDark ? Colors.white : AppColors.textOnLight,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const Spacer(),
                      // Quick edit shortcut
                      IconButton(
                        icon: const Icon(
                          Icons.mode_edit_outline_rounded,
                          color: AppColors.teal,
                          size: 20,
                        ),
                        tooltip: 'Edit Personal Details',
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          _showPersonalInfoSheet(context, ref, user, profile);
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // ── Hero Identity Card ────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.navyCard : AppColors.lightCard,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : AppColors.borderLight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.28)
                              : AppColors.lightCardShadow
                                  .withValues(alpha: 0.8),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        // Avatar with gradient border
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [AppColors.teal, AppColors.emerald],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.teal.withValues(alpha: 0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(2.5),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark
                                  ? AppColors.navyElevated
                                  : AppColors.lightSurface,
                            ),
                            child: Center(
                              child: Text(
                                displayName.isNotEmpty
                                    ? displayName[0].toUpperCase()
                                    : 'U',
                                style: GoogleFonts.inter(
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.textOnLight,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // User name, persona, and account badge
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.textOnLight,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                personaTitle,
                                style: GoogleFonts.inter(
                                  color: isDark
                                      ? AppColors.textOnDarkSecondary
                                      : AppColors.textOnLightSecondary,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Status Pill
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isGuest
                                      ? const Color(0xFFF59E0B)
                                          .withValues(alpha: 0.12)
                                      : AppColors.teal.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isGuest
                                        ? const Color(0xFFF59E0B)
                                            .withValues(alpha: 0.35)
                                        : AppColors.teal
                                            .withValues(alpha: 0.35),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isGuest
                                          ? Icons.lock_clock_rounded
                                          : Icons.verified_rounded,
                                      size: 13,
                                      color: isGuest
                                          ? const Color(0xFFF59E0B)
                                          : AppColors.teal,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      isGuest
                                          ? 'Guest Session • Local'
                                          : 'Verified • Alerts Active',
                                      style: GoogleFonts.inter(
                                        color: isGuest
                                            ? const Color(0xFFF59E0B)
                                            : AppColors.teal,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.2,
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
                ),
              ),

              // ── Group 1: Account & Finances ───────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
                  child: Text(
                    'ACCOUNT & FINANCES',
                    style: GoogleFonts.inter(
                      color: isDark
                          ? AppColors.textOnDarkTertiary
                          : AppColors.textOnLightSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _MenuGroupCard(
                    items: [
                      _ProfileMenuItem(
                        icon: Icons.person_outline_rounded,
                        iconBgColor: AppColors.emerald,
                        title: 'Personal Information',
                        subtitle: displayEmail,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _showPersonalInfoSheet(context, ref, user, profile);
                        },
                      ),
                      _ProfileMenuItem(
                        icon: Icons.account_balance_wallet_outlined,
                        iconBgColor: AppColors.teal,
                        title: 'Financial Information',
                        subtitle:
                            '$personaTitle • ${_formatCurrency(profile?.monthlyIncome)}/mo',
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _showFinancialInfoSheet(context, profile);
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // ── Group 2: Preferences & Settings ───────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
                  child: Text(
                    'PREFERENCES & SYSTEM',
                    style: GoogleFonts.inter(
                      color: isDark
                          ? AppColors.textOnDarkTertiary
                          : AppColors.textOnLightSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _MenuGroupCard(
                    items: [
                      _ProfileMenuItem(
                        icon: Icons.tune_rounded,
                        iconBgColor: const Color(0xFF06B6D4),
                        title: 'App Settings',
                        subtitle: 'Notifications, Alerts & Theme',
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _showAppSettingsSheet(context, ref);
                        },
                      ),
                      _ProfileMenuItem(
                        icon: Icons.language_rounded,
                        iconBgColor: const Color(0xFF3B82F6),
                        title: 'Language',
                        subtitle: currentLanguage.displayName,
                        trailingWidget: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF3B82F6).withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF3B82F6)
                                  .withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.public_rounded,
                                size: 13,
                                color: Color(0xFF60A5FA),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                currentLanguage.displayName,
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF93C5FD),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _showLanguageSelectorSheet(context, ref);
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // ── Group 3: Support & Information ────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
                  child: Text(
                    'SUPPORT & INFORMATION',
                    style: GoogleFonts.inter(
                      color: isDark
                          ? AppColors.textOnDarkTertiary
                          : AppColors.textOnLightSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _MenuGroupCard(
                    items: [
                      _ProfileMenuItem(
                        icon: Icons.help_outline_rounded,
                        iconBgColor: const Color(0xFFF59E0B),
                        title: 'Help & Support',
                        subtitle: 'FAQs, Guidelines & Contact',
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _showHelpSupportSheet(context);
                        },
                      ),
                      _ProfileMenuItem(
                        icon: Icons.info_outline_rounded,
                        iconBgColor: const Color(0xFF6366F1),
                        title: 'About Tadbeer AI',
                        subtitle: 'v2.0.0 • Alibaba Cloud AI 2026',
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _showAboutSheet(context);
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // ── Sign Out Action ───────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 36),
                  child: _SignOutButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      _showSignOutDialog(context, ref);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Modal Bottom Sheets ──────────────────────────────────────────────────

  void _showPersonalInfoSheet(
    BuildContext context,
    WidgetRef ref,
    AppUser? user,
    FinancialProfile? profile,
  ) {
    final nameController = TextEditingController(
      text: user?.name.trim().isNotEmpty == true
          ? user!.name.trim()
          : (profile?.name ?? ''),
    );
    final phoneController = TextEditingController(
      text: user?.phone ?? '',
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return _ModalContainer(
          title: 'Personal Information',
          icon: Icons.person_rounded,
          iconColor: AppColors.emerald,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _InfoTile(
                label: 'User ID',
                value: user?.id ?? 'guest_session',
                icon: Icons.fingerprint_rounded,
              ),
              const SizedBox(height: 12),
              _InfoTile(
                label: 'Email Address',
                value: user?.email.isNotEmpty == true
                    ? user!.email
                    : 'guest@tadbeer.ai',
                icon: Icons.email_outlined,
              ),
              const SizedBox(height: 16),
              Text(
                'Full Name',
                style: GoogleFonts.inter(
                  color: isDark
                      ? AppColors.textOnDarkSecondary
                      : AppColors.textOnLightSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: nameController,
                style: GoogleFonts.inter(
                  color: isDark ? Colors.white : AppColors.textOnLight,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor:
                      isDark ? AppColors.navyElevated : AppColors.lightBg,
                  hintText: 'Enter your name',
                  hintStyle: GoogleFonts.inter(
                    color: isDark
                        ? AppColors.textOnDarkTertiary
                        : AppColors.textOnLightTertiary,
                  ),
                  prefixIcon: const Icon(
                    Icons.badge_outlined,
                    color: AppColors.teal,
                    size: 19,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : AppColors.borderLight,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : AppColors.borderLight,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: AppColors.teal,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Phone Number',
                style: GoogleFonts.inter(
                  color: isDark
                      ? AppColors.textOnDarkSecondary
                      : AppColors.textOnLightSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                style: GoogleFonts.inter(
                  color: isDark ? Colors.white : AppColors.textOnLight,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor:
                      isDark ? AppColors.navyElevated : AppColors.lightBg,
                  hintText: '+92 300 1234567',
                  hintStyle: GoogleFonts.inter(
                    color: isDark
                        ? AppColors.textOnDarkTertiary
                        : AppColors.textOnLightTertiary,
                  ),
                  prefixIcon: const Icon(
                    Icons.phone_android_rounded,
                    color: AppColors.teal,
                    size: 19,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : AppColors.borderLight,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : AppColors.borderLight,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: AppColors.teal,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    final newName = nameController.text.trim();
                    final newPhone = phoneController.text.trim();
                    if (newName.isNotEmpty) {
                      ref
                          .read(authControllerProvider.notifier)
                          .updateUserProfile(
                            name: newName,
                            phone: newPhone,
                          );
                      if (profile != null) {
                        ref
                            .read(financialProfileControllerProvider.notifier)
                            .saveProfile(profile.copyWith(name: newName));
                      }
                    }
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Profile details updated successfully.'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: isDark ? AppColors.teal : AppColors.navyBg,
                    foregroundColor: isDark ? AppColors.navyBg : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Save Changes',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _showFinancialInfoSheet(
      BuildContext context, FinancialProfile? profile) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ModalContainer(
        title: 'Financial Information',
        icon: Icons.account_balance_wallet_rounded,
        iconColor: AppColors.teal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _InfoTile(
              label: 'Assigned Persona',
              value: _formatPersonaTitle(profile?.persona),
              icon: Icons.badge_outlined,
            ),
            const SizedBox(height: 10),
            _InfoTile(
              label: 'Monthly Income',
              value: _formatCurrency(profile?.monthlyIncome),
              icon: Icons.trending_up_rounded,
            ),
            const SizedBox(height: 10),
            _InfoTile(
              label: 'Monthly Essential Expenses',
              value: _formatCurrency(profile?.monthlyEssentialExpenses),
              icon: Icons.receipt_long_rounded,
            ),
            const SizedBox(height: 10),
            _InfoTile(
              label: 'Total Savings Stash',
              value: _formatCurrency(profile?.totalSavings),
              icon: Icons.savings_outlined,
            ),
            const SizedBox(height: 10),
            _InfoTile(
              label: 'Primary Financial Goal',
              value: profile?.primaryGoal?.name ?? 'Emergency Fund',
              icon: Icons.flag_outlined,
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.push('/profile/financial');
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.teal.withValues(alpha: 0.16),
                  foregroundColor: AppColors.teal,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Edit in Financial Wizard',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showAppSettingsSheet(BuildContext context, WidgetRef ref) {
    final pushNotifications = ref.watch(pushNotificationsProvider);
    final marketAlerts = ref.watch(marketAlertsProvider);
    final haptics = ref.watch(hapticsEnabledProvider);
    final themeMode = ref.watch(appThemeModeProvider);
    final user = ref.watch(authControllerProvider);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Consumer(
        builder: (context, ref, _) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return _ModalContainer(
            title: 'App Settings',
            icon: Icons.tune_rounded,
            iconColor: const Color(0xFF06B6D4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SettingsToggleRow(
                  title: 'Push Notifications',
                  subtitle: 'Daily financial digests and market insights',
                  value: pushNotifications,
                  onChanged: (val) {
                    ref.read(pushNotificationsProvider.notifier).set(val);
                  },
                ),
                Divider(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : AppColors.borderLight,
                  height: 16,
                ),
                _SettingsToggleRow(
                  title: 'Market & Commodity Alerts',
                  subtitle:
                      'Immediate alerts when essential food or fuel shifts',
                  value: marketAlerts,
                  onChanged: (val) {
                    ref.read(marketAlertsProvider.notifier).set(val);
                  },
                ),
                Divider(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : AppColors.borderLight,
                  height: 16,
                ),
                _SettingsToggleRow(
                  title: 'Haptic Feedback',
                  subtitle: 'Tactile vibrations on key app interactions',
                  value: haptics,
                  onChanged: (val) {
                    ref.read(hapticsEnabledProvider.notifier).set(val);
                  },
                ),
                Divider(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : AppColors.borderLight,
                  height: 20,
                ),
                Text(
                  'Theme Appearance',
                  style: GoogleFonts.inter(
                    color: isDark ? Colors.white : AppColors.textOnLight,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Choose how Tadbeer AI looks on your device',
                  style: GoogleFonts.inter(
                    color: isDark
                        ? AppColors.textOnDarkSecondary
                        : AppColors.textOnLightSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _ThemeOptionCard(
                      title: 'Dark',
                      subtitle: 'Navy & Teal',
                      icon: Icons.dark_mode_rounded,
                      isSelected: themeMode == ThemeMode.dark,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref
                            .read(appThemeModeProvider.notifier)
                            .setThemeMode(ThemeMode.dark, userId: user?.id);
                      },
                    ),
                    const SizedBox(width: 8),
                    _ThemeOptionCard(
                      title: 'Light',
                      subtitle: 'Clean & Navy',
                      icon: Icons.light_mode_rounded,
                      isSelected: themeMode == ThemeMode.light,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref
                            .read(appThemeModeProvider.notifier)
                            .setThemeMode(ThemeMode.light, userId: user?.id);
                      },
                    ),
                    const SizedBox(width: 8),
                    _ThemeOptionCard(
                      title: 'System',
                      subtitle: 'Auto Match',
                      icon: Icons.brightness_auto_rounded,
                      isSelected: themeMode == ThemeMode.system,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref
                            .read(appThemeModeProvider.notifier)
                            .setThemeMode(ThemeMode.system, userId: user?.id);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showLanguageSelectorSheet(BuildContext context, WidgetRef ref) {
    final activeLocale = ref.watch(appLocaleProvider);
    final activeLanguage = AppLanguage.fromLocale(activeLocale);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return _ModalContainer(
          title: 'Select Language',
          icon: Icons.language_rounded,
          iconColor: const Color(0xFF3B82F6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: AppLanguage.values.map((lang) {
              final isSelected = lang == activeLanguage;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.teal.withValues(alpha: isDark ? 0.12 : 0.10)
                      : (isDark ? AppColors.navyElevated : AppColors.lightBg),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.teal
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : AppColors.borderLight),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: ListTile(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(appLocaleProvider.notifier).setLanguage(lang);
                    Navigator.of(ctx).pop();
                  },
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? AppColors.teal.withValues(alpha: 0.2)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : AppColors.teal.withValues(alpha: 0.08)),
                    ),
                    child: Center(
                      child: Text(
                        lang == AppLanguage.english
                            ? 'EN'
                            : (lang == AppLanguage.urdu ? 'UR' : 'RU'),
                        style: GoogleFonts.inter(
                          color: isSelected
                              ? AppColors.teal
                              : (isDark
                                  ? Colors.white70
                                  : AppColors.textOnLightSecondary),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    lang.displayName,
                    style: GoogleFonts.inter(
                      color: isDark ? Colors.white : AppColors.textOnLight,
                      fontSize: 15,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    lang.nativeSubtitle,
                    style: GoogleFonts.inter(
                      color: isDark
                          ? AppColors.textOnDarkSecondary
                          : AppColors.textOnLightSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.teal,
                          size: 20,
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showHelpSupportSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ModalContainer(
        title: 'Help & Support',
        icon: Icons.help_outline_rounded,
        iconColor: const Color(0xFFF59E0B),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const _HelpFaqTile(
              question: 'How does Tadbeer forecast market inflation?',
              answer:
                  'Tadbeer combines Pakistan Bureau of Statistics weekly SPI feeds with Qwen/Groq deep analysis to pinpoint real-world price pressures for your persona.',
            ),
            const SizedBox(height: 8),
            const _HelpFaqTile(
              question: 'Are my financial records private?',
              answer:
                  'Yes! Your data is stored securely on your device with local encryption. Sensitive bank credentials are never stored or transferred.',
            ),
            const SizedBox(height: 8),
            const _HelpFaqTile(
              question: 'Can I get alerts via WhatsApp or SMS?',
              answer:
                  'Real-time alerts via SMS and push are enabled for registered accounts. Guest mode sessions maintain local offline alerts.',
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.navyElevated : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : AppColors.borderLight,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.headset_mic_rounded,
                    color: Color(0xFFF59E0B),
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Need technical assistance?',
                          style: GoogleFonts.inter(
                            color:
                                isDark ? Colors.white : AppColors.textOnLight,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'support@tadbeer.ai',
                          style: GoogleFonts.inter(
                            color: isDark ? AppColors.teal : AppColors.tealDeep,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showAboutSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ModalContainer(
        title: 'About Tadbeer AI',
        icon: Icons.info_outline_rounded,
        iconColor: const Color(0xFF6366F1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      isDark ? AppColors.navyElevated : AppColors.lightSurface,
                  border: Border.all(
                    color: AppColors.teal.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.teal,
                    size: 28,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Tadbeer AI 2.0',
                style: GoogleFonts.inter(
                  color: isDark ? Colors.white : AppColors.textOnLight,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Center(
              child: Text(
                'Alibaba Cloud AI Hackathon Pakistan 2026',
                style: GoogleFonts.inter(
                  color: isDark
                      ? AppColors.textOnDarkSecondary
                      : AppColors.textOnLightSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Tadbeer AI is Pakistan’s premier personalized financial intelligence co-pilot. Built with on-device resilience, multi-agent LLM reasoning, and official Pakistan Bureau of Statistics economic telemetry.',
              style: GoogleFonts.inter(
                color: isDark
                    ? AppColors.textOnDarkSecondary
                    : AppColors.textOnLightSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            const _InfoTile(
              label: 'App Version',
              value: '2.0.0 (Build 2026)',
              icon: Icons.terminal_rounded,
            ),
            const SizedBox(height: 8),
            const _InfoTile(
              label: 'Architecture',
              value: 'Flutter • FastAPI • Multi-Agent Qwen',
              icon: Icons.cloud_done_rounded,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showSignOutDialog(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ModalContainer(
        title: 'Sign Out',
        icon: Icons.logout_rounded,
        iconColor: AppColors.danger,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Are you sure you want to sign out? Your financial records on this device will remain secure.',
              style: GoogleFonts.inter(
                color: isDark
                    ? AppColors.textOnDarkSecondary
                    : AppColors.textOnLightSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.16)
                            : AppColors.borderLight,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(
                        color: isDark ? Colors.white : AppColors.textOnLight,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      await ref.read(authControllerProvider.notifier).signOut();
                      if (context.mounted) {
                        context.go('/login');
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    child: Text(
                      'Sign Out',
                      style: GoogleFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

// ── Supporting Widgets ───────────────────────────────────────────────────────

class _ThemeOptionCard extends StatelessWidget {
  const _ThemeOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.teal.withValues(alpha: isDark ? 0.16 : 0.12)
                  : (isDark ? AppColors.navyElevated : AppColors.lightBg),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? AppColors.teal
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : AppColors.borderLight),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: isSelected
                      ? (isDark ? AppColors.teal : AppColors.tealDeep)
                      : (isDark
                          ? AppColors.textOnDarkSecondary
                          : AppColors.textOnLightSecondary),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: isSelected
                        ? (isDark ? AppColors.teal : AppColors.tealDeep)
                        : (isDark ? Colors.white : AppColors.textOnLight),
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: isDark
                        ? AppColors.textOnDarkTertiary
                        : AppColors.textOnLightSecondary,
                    fontSize: 10.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBackButton extends StatelessWidget {
  const _NavBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.navyCard
                : AppColors.lightCard.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : AppColors.borderLight,
            ),
          ),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : AppColors.textOnLight,
            size: 17,
          ),
        ),
      ),
    );
  }
}

class _MenuGroupCard extends StatelessWidget {
  const _MenuGroupCard({required this.items});

  final List<_ProfileMenuItem> items;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.navyCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
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
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            items[i],
            if (i < items.length - 1)
              Divider(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : AppColors.borderLight,
                height: 1,
                indent: 58,
                endIndent: 16,
              ),
          ],
        ],
      ),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  const _ProfileMenuItem({
    required this.icon,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailingWidget,
  });

  final IconData icon;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailingWidget;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: AppColors.teal.withValues(alpha: 0.12),
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Icon container with colored glow
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBgColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconBgColor, size: 20),
              ),
              const SizedBox(width: 14),

              // Title and subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        color: isDark ? Colors.white : AppColors.textOnLight,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: isDark
                            ? AppColors.textOnDarkSecondary
                            : AppColors.textOnLightSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              if (trailingWidget != null) trailingWidget!,
              const SizedBox(width: 4),

              Icon(
                Icons.chevron_right_rounded,
                color: isDark
                    ? AppColors.textOnDarkTertiary
                    : AppColors.textOnLightTertiary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        splashColor: AppColors.danger.withValues(alpha: 0.15),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.danger.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.danger.withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.logout_rounded,
                color: AppColors.danger,
                size: 19,
              ),
              const SizedBox(width: 8),
              Text(
                'Sign Out',
                style: GoogleFonts.inter(
                  color: AppColors.danger,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModalContainer extends StatelessWidget {
  const _ModalContainer({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final maxSheetHeight = mediaQuery.size.height * 0.88;

    return Container(
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      decoration: BoxDecoration(
        color: isDark ? AppColors.navyCard : AppColors.lightCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : AppColors.borderLight,
        ),
        boxShadow: isDark
            ? null
            : [
                const BoxShadow(
                  color: AppColors.lightCardShadow,
                  blurRadius: 20,
                  offset: Offset(0, -4),
                ),
              ],
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.inter(
                  color: isDark ? Colors.white : AppColors.textOnLight,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  color:
                      isDark ? Colors.white54 : AppColors.textOnLightTertiary,
                  size: 20,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.navyElevated : AppColors.lightBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : AppColors.borderLight,
        ),
      ),
      child: Row(
        children: [
          Icon(icon,
              color: isDark ? AppColors.teal : AppColors.tealDeep, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: isDark
                        ? AppColors.textOnDarkTertiary
                        : AppColors.textOnLightSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    color: isDark ? Colors.white : AppColors.textOnLight,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
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

class _SettingsToggleRow extends StatelessWidget {
  const _SettingsToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  color: isDark ? Colors.white : AppColors.textOnLight,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
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
        Switch(
          value: value,
          activeThumbColor: AppColors.teal,
          onChanged: (val) {
            HapticFeedback.selectionClick();
            onChanged(val);
          },
        ),
      ],
    );
  }
}

class _HelpFaqTile extends StatelessWidget {
  const _HelpFaqTile({
    required this.question,
    required this.answer,
  });

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.navyElevated : AppColors.lightBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: GoogleFonts.inter(
              color: isDark ? Colors.white : AppColors.textOnLight,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            answer,
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
    );
  }
}
