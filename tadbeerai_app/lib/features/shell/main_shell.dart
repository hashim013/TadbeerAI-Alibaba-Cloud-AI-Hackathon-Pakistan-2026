import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/l10n_context.dart';

/// Main app shell hosting the five primary areas with an ultra-modern,
/// professionally aligned bottom navigation bar and silky-smooth tab switching.
class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.012),
      end: Offset.zero,
    ).animate(_fadeAnimation);
    _fadeController.value = 1.0;
  }

  @override
  void didUpdateWidget(covariant MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.navigationShell.currentIndex !=
        oldWidget.navigationShell.currentIndex) {
      _fadeController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final destinations = [
      _NavDestination(
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
        label: l10n.tabHome,
      ),
      _NavDestination(
        icon: Icons.account_balance_wallet_outlined,
        selectedIcon: Icons.account_balance_wallet_rounded,
        label: l10n.tabFinance,
      ),
      _NavDestination(
        icon: Icons.insights_outlined,
        selectedIcon: Icons.insights_rounded,
        label: l10n.tabEconomy,
      ),
      _NavDestination(
        icon: Icons.auto_awesome_outlined,
        selectedIcon: Icons.auto_awesome_rounded,
        label: l10n.tabAskTadbeer,
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.navyBg,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: widget.navigationShell,
        ),
      ),
      bottomNavigationBar: _ModernBottomNavBar(
        currentIndex: widget.navigationShell.currentIndex,
        onDestinationSelected: (index) => widget.navigationShell.goBranch(
          index,
          initialLocation: index == widget.navigationShell.currentIndex,
        ),
        destinations: destinations,
      ),
    );
  }
}

class _NavDestination {
  const _NavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class _ModernBottomNavBar extends StatelessWidget {
  const _ModernBottomNavBar({
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<_NavDestination> destinations;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.navyCard,
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1.0,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (int i = 0; i < destinations.length; i++)
                Expanded(
                  child: _NavItem(
                    destination: destinations[i],
                    isSelected: currentIndex == i,
                    onTap: () => onDestinationSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.isSelected,
    required this.onTap,
  });

  final _NavDestination destination;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.teal.withValues(alpha: 0.14),
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top active glowing pill indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: isSelected ? 22 : 0,
              height: 3,
              decoration: BoxDecoration(
                color:
                    isSelected ? const Color(0xFF2DD4BF) : Colors.transparent,
                borderRadius: BorderRadius.circular(1.5),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color:
                              const Color(0xFF2DD4BF).withValues(alpha: 0.55),
                          blurRadius: 6,
                          spreadRadius: 0.5,
                        ),
                      ]
                    : null,
              ),
            ),

            // Perfectly centered Icon + Label block
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedScale(
                    scale: isSelected ? 1.08 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    child: TweenAnimationBuilder<Color?>(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      tween: ColorTween(
                        begin: const Color(0xFF64748B),
                        end: isSelected
                            ? const Color(0xFF2DD4BF)
                            : const Color(0xFF64748B),
                      ),
                      builder: (context, color, _) {
                        return Icon(
                          isSelected
                              ? destination.selectedIcon
                              : destination.icon,
                          size: 22,
                          color: color,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? const Color(0xFF2DD4BF)
                            : const Color(0xFF94A3B8),
                        letterSpacing: 0.1,
                        height: 1.15,
                      ),
                      child: Text(
                        destination.label,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 3),
          ],
        ),
      ),
    );
  }
}
