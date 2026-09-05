import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/assistant/ask_tadbeer_screen.dart';
import '../../features/auth/forgot_password_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/signup_screen.dart';
import '../../features/dashboard/home_dashboard_screen.dart';
import '../../features/economy/economic_detail_screen.dart';
import '../../features/economy/economic_pulse_screen.dart';
import '../../features/finance/budget_screen.dart';
import '../../features/finance/expenses_screen.dart';
import '../../features/finance/finance_overview_screen.dart';
import '../../features/finance/financial_health_screen.dart';
import '../../features/finance/goals_screen.dart';
import '../../features/finance/my_finances_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/profile/financial_profile_screen.dart';
import '../../features/shell/main_shell.dart';
import '../../features/shell/tabs.dart';
import '../../features/splash/splash_screen.dart';

/// Smooth fade + subtle horizontal slide transition for primary screen switches.
CustomTransitionPage<void> _buildSmoothTransitionPage({
  required GoRouterState state,
  required Widget child,
  Offset slideOffset = const Offset(0.04, 0),
  Duration duration = const Duration(milliseconds: 280),
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final fade = Tween<double>(begin: 0.0, end: 1.0).animate(curved);
      final slide =
          Tween<Offset>(begin: slideOffset, end: Offset.zero).animate(curved);
      return FadeTransition(
        opacity: fade,
        child: SlideTransition(
          position: slide,
          child: child,
        ),
      );
    },
  );
}

/// Slide + fade transition for sub-routes / detail views.
CustomTransitionPage<void> _buildDetailTransitionPage({
  required GoRouterState state,
  required Widget child,
  Duration duration = const Duration(milliseconds: 280),
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final slide = Tween<Offset>(
        begin: const Offset(0.06, 0),
        end: Offset.zero,
      ).animate(curved);
      final fade = Tween<double>(begin: 0.0, end: 1.0).animate(curved);

      return FadeTransition(
        opacity: fade,
        child: SlideTransition(
          position: slide,
          child: child,
        ),
      );
    },
  );
}

/// App navigation graph.
///
/// `/splash` gates the first-launch flow (onboarding → login → shell);
/// the five main areas live in a stateful shell so tab state survives
/// navigation.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) => _buildSmoothTransitionPage(
          state: state,
          child: const OnboardingScreen(),
        ),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => _buildSmoothTransitionPage(
          state: state,
          child: const LoginScreen(),
          slideOffset: const Offset(-0.04, 0),
        ),
      ),
      GoRoute(
        path: '/signup',
        pageBuilder: (context, state) => _buildSmoothTransitionPage(
          state: state,
          child: const SignupScreen(),
          slideOffset: const Offset(0.04, 0),
        ),
      ),
      GoRoute(
        path: '/forgot-password',
        pageBuilder: (context, state) {
          final email = state.extra as String?;
          return _buildSmoothTransitionPage(
            state: state,
            child: ForgotPasswordScreen(initialEmail: email),
            slideOffset: const Offset(0.04, 0),
          );
        },
      ),
      GoRoute(
        path: '/profile/financial',
        pageBuilder: (context, state) => _buildSmoothTransitionPage(
          state: state,
          child: const FinancialProfileScreen(),
        ),
      ),
      // Standalone route preserving the Market screen for future phases
      GoRoute(
        path: '/market',
        pageBuilder: (context, state) => _buildSmoothTransitionPage(
          state: state,
          child: const MarketTab(),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/finance',
                builder: (context, state) => const FinanceOverviewScreen(),
                routes: [
                  GoRoute(
                    path: 'health',
                    pageBuilder: (context, state) => _buildDetailTransitionPage(
                      state: state,
                      child: const FinancialHealthScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'finances',
                    pageBuilder: (context, state) => _buildDetailTransitionPage(
                      state: state,
                      child: const MyFinancesScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'expenses',
                    pageBuilder: (context, state) => _buildDetailTransitionPage(
                      state: state,
                      child: const ExpensesScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'budget',
                    pageBuilder: (context, state) => _buildDetailTransitionPage(
                      state: state,
                      child: const BudgetScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'goals',
                    pageBuilder: (context, state) => _buildDetailTransitionPage(
                      state: state,
                      child: const GoalsScreen(),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/economy',
                builder: (context, state) => const EconomicPulseScreen(),
                routes: [
                  GoRoute(
                    path: 'indicator/:id',
                    pageBuilder: (context, state) => _buildDetailTransitionPage(
                      state: state,
                      child: EconomicDetailScreen(
                        indicatorId: state.pathParameters['id']!,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/ask',
                builder: (context, state) {
                  final extra = state.extra;
                  String? initialQuery;
                  if (extra is Map) {
                    initialQuery = extra['initialQuery'] as String?;
                  } else if (extra is String) {
                    initialQuery = extra;
                  }
                  return AskTadbeerScreen(initialQuery: initialQuery);
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
