// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : app_router.dart
// Description   : App navigation routing for FinWise.
//                 StatefulShellRoute for 4 persistent tabs:
//                 Home | Grow | Discover | Profile.
//                 Scanner, salary, merchant, and feature sub-routes
//                 push on top of the shell (no bottom nav).
// First Written : 21-May-2026
// Edited on     : 19-06-2026
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
import '../screens/transaction/general_deposit_screen.dart';
import '../screens/transaction/transaction_history_screen.dart';
import '../screens/transaction/vault_detail_screen.dart';
import '../screens/transaction/transfer_screen.dart';
import '../screens/transaction/receive_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/account_profile_screen.dart';
import '../screens/profile/achievements_screen.dart';
import '../screens/profile/bill_reminders_screen.dart';
import '../screens/grow/grow_screen.dart';
import '../screens/grow/debt_screen.dart';
import '../screens/grow/debt_strategy_screen.dart';
import '../screens/grow/investment_screen.dart';
import '../screens/grow/holdings_edit_screen.dart';
import '../screens/grow/tradingview_screen.dart';
import '../screens/grow/protection_screen.dart';
import '../screens/grow/health_score_screen.dart';
import '../screens/discover/discover_screen.dart';
import '../screens/discover/fd_marketplace_screen.dart';
import '../screens/discover/deals_screen.dart';
import '../screens/discover/news_screen.dart';
import '../screens/discover/loan_calculator_screen.dart';
import '../screens/discover/spending_forecast_screen.dart';
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

      // ── 4-tab shell (Home · Grow · Discover · Profile) ──────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainScaffold(navigationShell: navigationShell),
        branches: [
          // Branch 0 — Home
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/dashboard',
              builder: (context, state) => const DashboardScreen(),
            ),
          ]),
          // Branch 1 — Grow
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/grow',
              builder: (context, state) => const GrowScreen(),
            ),
          ]),
          // Branch 2 — Discover
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/discover',
              builder: (context, state) => const DiscoverScreen(),
            ),
          ]),
          // Branch 3 — Profile
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/account-profile',
              builder: (context, state) => const AccountProfileScreen(),
            ),
          ]),
        ],
      ),

      // ── Chat (push — no bottom nav) ───────────────────────────────
      GoRoute(
        path: '/chat',
        builder: (context, state) => const ChatScreen(),
      ),

      // ── Transactions (push — no bottom nav) ───────────────────────
      GoRoute(
        path: '/transactions',
        builder: (context, state) => const TransactionHistoryScreen(),
      ),
      GoRoute(
        path: '/grow/health-score',
        builder: (context, state) => const HealthScoreScreen(),
      ),
      GoRoute(
        path: '/grow/debt',
        builder: (context, state) => const DebtScreen(),
      ),
      GoRoute(
        path: '/grow/debt/strategy',
        builder: (context, state) => const DebtStrategyScreen(),
      ),
      GoRoute(
        path: '/grow/invest',
        builder: (context, state) => const InvestmentScreen(),
      ),
      GoRoute(
        path: '/grow/invest/holdings',
        builder: (context, state) => const HoldingsEditScreen(),
      ),
      GoRoute(
        path: '/grow/invest/chart',
        builder: (context, state) => const TradingViewScreen(),
      ),
      GoRoute(
        path: '/grow/protection',
        builder: (context, state) => const ProtectionScreen(),
      ),
      // ── Discover sub-routes (push — no bottom nav) ────────────────
      GoRoute(
        path: '/discover/fd-rates',
        builder: (context, state) => const FdMarketplaceScreen(),
      ),
      GoRoute(
        path: '/discover/deals',
        builder: (context, state) => const DealsScreen(),
      ),
      GoRoute(
        path: '/discover/news',
        builder: (context, state) => const NewsScreen(),
      ),
      GoRoute(
        path: '/discover/loan-calc',
        builder: (context, state) => const LoanCalculatorScreen(),
      ),
      GoRoute(
        path: '/discover/forecast',
        builder: (context, state) => const SpendingForecastScreen(),
      ),

      // ── Profile push routes ───────────────────────────────────────
      GoRoute(
        path: '/achievements',
        builder: (context, state) => const AchievementsScreen(),
      ),
      GoRoute(
        path: '/bills',
        builder: (context, state) => const BillRemindersScreen(),
      ),
      // ── Vault detail (push — no bottom nav) ──────────────────────
      GoRoute(
        path: '/vault-detail/:id',
        builder: (context, state) {
          final vaultId = state.pathParameters['id']!;
          return VaultDetailScreen(vaultId: vaultId);
        },
      ),

      // ── Financial profile (push — no nav bar) ────────────────────
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),

      // ── QR / income / payment flows (push) ───────────────────────
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
          final amount = (state.extra as double?) ?? 0.0;
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
      GoRoute(
        path: '/general-deposit',
        builder: (context, state) {
          final payload = state.extra as Map<String, dynamic>? ?? {};
          return GeneralDepositScreen(qrPayload: payload);
        },
      ),
      GoRoute(
        path: '/transfer',
        builder: (context, state) {
          final prefilledPhone = state.extra as String?;
          return TransferScreen(prefilledPhone: prefilledPhone);
        },
      ),
      GoRoute(
        path: '/receive',
        builder: (context, state) => const ReceiveScreen(),
      ),
    ],
  );
});
