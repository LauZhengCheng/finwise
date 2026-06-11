// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : dashboard_screen.dart
// Description   : Main dashboard — luxury dark editorial layout.
//                 Custom header, Safe-to-Spend hero, fund PageView,
//                 spending vaults container, spending chart.
// First Written : 21-May-2026
// Edited on     : 10-06-2026
// ============================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_theme.dart';
import '../../models/vault_model.dart';
import '../../providers/vault_provider.dart';
import 'widgets/vault_card.dart';
import 'widgets/fund_card.dart';
import 'widgets/spending_chart.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final PageController _fundPageController = PageController();
  int _currentFundPage = 0;

  @override
  void dispose() {
    _fundPageController.dispose();
    super.dispose();
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  String _firstName() {
    final meta = Supabase.instance.client.auth.currentUser?.userMetadata;
    final full = meta?['full_name'] as String? ?? '';
    return full.split(' ').first.isNotEmpty ? full.split(' ').first : 'there';
  }

  @override
  Widget build(BuildContext context) {
    final vaultState = ref.watch(vaultProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF060504),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
        child: vaultState.isLoading && vaultState.vaults.isEmpty
            ? const Center(
                child:
                    CircularProgressIndicator(color: AppTheme.primaryColor),
              )
            : RefreshIndicator(
                onRefresh: () =>
                    ref.read(vaultProvider.notifier).fetchVaults(),
                color: AppTheme.primaryColor,
                backgroundColor: AppTheme.cardColor,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 108),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header ─────────────────────────────────────
                      _buildHeader(context),
                      const SizedBox(height: 36),

                      // ── Safe-to-Spend hero ──────────────────────────
                      _buildHero(vaultState.spendingVaults),
                      const SizedBox(height: 28),

                      // ── Quick actions ───────────────────────────────
                      _buildQuickActions(context),
                      const SizedBox(height: 36),

                      // ── Saving Funds PageView ───────────────────────
                      if (vaultState.savingFunds.isNotEmpty) ...[
                        _buildFundSection(vaultState.savingFunds),
                        const SizedBox(height: 32),
                      ],

                      // ── MY VAULTS container ─────────────────────────
                      if (vaultState.spendingVaults.isNotEmpty) ...[
                        _buildVaultsContainer(vaultState.spendingVaults),
                        const SizedBox(height: 32),
                      ],

                      // ── Spending chart ──────────────────────────────
                      SpendingChartCard(vaults: vaultState.vaults),
                    ],
                  ),
                ),
              ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // HEADER: greeting + tappable name + bell
  // ─────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting(),
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 2),
              GestureDetector(
                onTap: () => context.push('/profile'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      _firstName(),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.8,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppTheme.primaryColor,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Bell — taps to chat screen where Aria's proactive messages live
        Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: () => context.go('/chat'),
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppTheme.surfaceColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_outlined,
                  color: AppTheme.silverMuted,
                  size: 22,
                ),
              ),
            ),
            // Gold dot — uncomment when proactive notification state is wired in
            // Positioned(
            //   top: 2, right: 2,
            //   child: Container(
            //     width: 9, height: 9,
            //     decoration: const BoxDecoration(
            //       color: AppTheme.primaryColor,
            //       shape: BoxShape.circle,
            //     ),
            //   ),
            // ),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // HERO: gold Safe-to-Spend number
  // ─────────────────────────────────────────────
  Widget _buildHero(List<VaultModel> spendingVaults) {
    final total =
        spendingVaults.fold(0.0, (sum, v) => sum + v.currentBalance);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Safe to Spend',
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'RM ${total.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 46,
            fontWeight: FontWeight.w800,
            color: AppTheme.primaryColor,
            letterSpacing: -2.0,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Spending vaults only · funds excluded',
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textHint,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // FUND SECTION: PageView + dots indicator
  // ─────────────────────────────────────────────
  Widget _buildFundSection(List<VaultModel> funds) {
    return Stack(
      children: [
        SizedBox(
          height: 162,
          child: PageView.builder(
            controller: _fundPageController,
            itemCount: funds.length,
            onPageChanged: (i) => setState(() => _currentFundPage = i),
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FundCard(fund: funds[i]),
            ),
          ),
        ),

        // Dots sit inside the card at the bottom
        if (funds.length > 1)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(funds.length, (i) {
                final active = i == _currentFundPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active
                        ? AppTheme.primaryColor
                        : AppTheme.silverMuted.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // QUICK ACTIONS: Transfer | AI Advisor | Receive
  // ─────────────────────────────────────────────
  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        _QuickActionButton(
          icon: Icons.swap_horiz_rounded,
          label: 'Transfer',
          onTap: () => _showComingSoon(context, 'Transfer'),
        ),
        const SizedBox(width: 12),
        _QuickActionButton(
          icon: Icons.psychology_rounded,
          label: 'AI Advisor',
          isHighlighted: true,
          onTap: () => context.go('/chat'),
        ),
        const SizedBox(width: 12),
        _QuickActionButton(
          icon: Icons.call_received_rounded,
          label: 'Receive',
          onTap: () => _showComingSoon(context, 'Receive'),
        ),
      ],
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          feature,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          '$feature is coming soon. We\'re working hard to bring this feature to FinWise.',
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Got it',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // VAULTS CONTAINER: single dark card, all vaults inside
  // ─────────────────────────────────────────────
  Widget _buildVaultsContainer(List<VaultModel> vaults) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF242018), Color(0xFF0F0D09)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MY VAULTS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: AppTheme.textSecondary,
            ),
          ),

          ...vaults.asMap().entries.map((entry) {
            final isLast = entry.key == vaults.length - 1;
            return Column(
              children: [
                VaultCard(vault: entry.value),
                if (!isLast)
                  const Divider(
                    color: AppTheme.glassBorderColor,
                    height: 1,
                    thickness: 1,
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// QUICK ACTION BUTTON
// Rounded square with icon + label.
// isHighlighted = true → gold gradient (AI Advisor)
// ─────────────────────────────────────────────
class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isHighlighted;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            gradient: isHighlighted
                ? AppTheme.goldGradient
                : const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF242018), Color(0xFF0F0D09)],
                  ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 22,
                color: isHighlighted
                    ? const Color(0xFF080706)
                    : AppTheme.textPrimary,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isHighlighted
                      ? const Color(0xFF080706)
                      : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
