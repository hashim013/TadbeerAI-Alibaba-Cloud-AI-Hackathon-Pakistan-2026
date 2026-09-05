import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/assistant/ask_tadbeer_screen.dart';
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
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/profile/financial',
        builder: (context, state) => const FinancialProfileScreen(),
      ),
      // Standalone route preserving the Market screen for future phases
      GoRoute(
        path: '/market',
        builder: (context, state) => const MarketTab(),
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
                    builder: (context, state) => const FinancialHealthScreen(),
                  ),
                  GoRoute(
                    path: 'finances',
                    builder: (context, state) => const MyFinancesScreen(),
                  ),
                  GoRoute(
                    path: 'expenses',
                    builder: (context, state) => const ExpensesScreen(),
                  ),
                  GoRoute(
                    path: 'budget',
                    builder: (context, state) => const BudgetScreen(),
                  ),
                  GoRoute(
                    path: 'goals',
                    builder: (context, state) => const GoalsScreen(),
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
                    builder: (context, state) => EconomicDetailScreen(
                      indicatorId: state.pathParameters['id']!,
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
