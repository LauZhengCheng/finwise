// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : app_router.dart
// Description   : App navigation routing for FinWise.
//                 StatefulShellRoute for 4 persistent tabs.
//                 Scanner, salary, and merchant flows push on top.
// First Written : 21-May-2026
// Edited on     : 10-06-2026
// ============================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/auth/welcome_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/transaction/qr_scanner_screen.dart';
import '../screens/transaction/salary_deposit_screen.dart';
import '../screens/transaction/salary_preview_screen.dart';
import '../screens/transaction/merchant_pay_screen.dart';
import '../screens/transaction/transaction_history_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/account_profile_screen.dart';
import '../screens/main_scaffold.dart';

// Smooth fade transition used for auth routes
Page<void> _fadePage(Widget child, GoRouterState state) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isLoggedIn = session != null;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/';

      if (!isLoggedIn && !isAuthRoute) return '/';
      if (isLoggedIn && state.matchedLocation == '/') return '/dashboard';
      if (isLoggedIn && state.matchedLocation == '/register') return null;
      return null;
    },
    routes: [
      // ── Auth routes (fade transition) ────────────────────────────
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => _fadePage(const WelcomeScreen(), state),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => _fadePage(const LoginScreen(), state),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) =>
            _fadePage(const RegisterScreen(), state),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) =>
            _fadePage(const OnboardingScreen(), state),
      ),

      // ── 4-tab shell (Dashboard · Chat · Transactions · Account) ──
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/dashboard',
              builder: (context, state) => const DashboardScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/chat',
              builder: (context, state) => const ChatScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/transactions',
              builder: (context, state) => const TransactionHistoryScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/account-profile',
              builder: (context, state) => const AccountProfileScreen(),
            ),
          ]),
        ],
      ),

      // ── Action routes (push on top — no bottom nav) ───────────────
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/qr-scanner',
        pageBuilder: (context, state) =>
            _fadePage(const QrScannerScreen(), state),
      ),
      GoRoute(
        path: '/salary-deposit',
        builder: (context, state) {
          final payload = state.extra as Map<String, dynamic>? ?? {};
          return SalaryDepositScreen(qrPayload: payload);
        },
      ),
      GoRoute(
        path: '/salary-preview',
        builder: (context, state) {
          final amount = state.extra as double;
          return SalaryPreviewScreen(amount: amount);
        },
      ),
      GoRoute(
        path: '/merchant-pay',
        builder: (context, state) {
          final payload = state.extra as Map<String, dynamic>? ?? {};
          return MerchantPayScreen(qrPayload: payload);
        },
      ),
    ],
  );
});
