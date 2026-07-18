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
import '../../providers/notification_provider.dart';
import '../main_scaffold.dart';
import '../../providers/pending_income_provider.dart';
import '../../services/api/income_api.dart';
import 'widgets/vault_card.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/goal_celebration_overlay.dart';
import '../../services/api/vault_api.dart';
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationProvider.notifier).fetch();
      ref.read(pendingIncomeProvider.notifier).fetchPending();
    });
    homeTabRefresh.addListener(_onTabRefresh);
  }

  void _onTabRefresh() {
    ref.read(vaultProvider.notifier).fetchVaults();
    ref.read(notificationProvider.notifier).fetch();
    ref.read(pendingIncomeProvider.notifier).fetchPending();
  }

  @override
  void dispose() {
    homeTabRefresh.removeListener(_onTabRefresh);
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
    final notification = ref.watch(notificationProvider);
    final pendingIncome = ref.watch(pendingIncomeProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF060504),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () => ref.read(vaultProvider.notifier).fetchVaults(),
            color: AppTheme.primaryColor,
            backgroundColor: AppTheme.cardColor,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 108),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header always visible ───────────────────────
                  _buildHeader(context, notification.unreadCount),
                  const SizedBox(height: 20),

                  if (vaultState.isLoading) ...[
                    const SkeletonHero(),
                    const SizedBox(height: 28),
                    _buildQuickActions(context),
                    const SizedBox(height: 36),
                    const SkeletonFundCard(),
                    const SizedBox(height: 32),
                    const SkeletonVaultList(),
                  ] else ...[
                    // ── Income choice card (highest priority) ──────
                    if (pendingIncome.hasPending)
                      _buildIncomeChoiceCard(context, pendingIncome, vaultState.savingFunds),
                    if (pendingIncome.hasPending)
                      const SizedBox(height: 20),

                    // ── Proactive notification card ─────────────────
                    if (!pendingIncome.hasPending && notification.latestUnreadMessage != null)
                      _buildNotificationCard(context, notification.latestUnreadMessage!),
                    if (!pendingIncome.hasPending && notification.latestUnreadMessage != null)
                      const SizedBox(height: 20),

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
                    SpendingChartCard(
                      vaults: vaultState.vaults,
                      onViewAll: () => context.push('/transactions'),
                    ),
                  ],
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
  Widget _buildHeader(BuildContext context, int unreadCount) {
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

        // Bell — opens notification history sheet
        Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: () => _showNotificationHistory(context),
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
            if (unreadCount > 0)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // NOTIFICATION CARD: Aion proactive message
  // ─────────────────────────────────────────────
  Widget _buildNotificationCard(BuildContext context, String message) {
    return GestureDetector(
      onTap: () => context.push('/chat'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryColor.withValues(alpha: 0.12),
              AppTheme.primaryColor.withValues(alpha: 0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.primaryColor,
              child: Text('A', style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Aion has a message for you',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryColor, letterSpacing: 0.2)),
                  const SizedBox(height: 4),
                  Text(message,
                      style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, height: 1.4),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  const Text('Tap to view full advice →',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // NOTIFICATION HISTORY SHEET
  // ─────────────────────────────────────────────
  void _showNotificationHistory(BuildContext context) {
    final notifications = ref.read(notificationProvider).notifications;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.glassBorderColor, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Notifications', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: notifications.isEmpty
                    ? const Center(child: Text('No notifications yet', style: TextStyle(color: AppTheme.textSecondary)))
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: notifications.length,
                        itemBuilder: (_, i) {
                          final n = notifications[i];
                          final isReplied = n['is_replied'] == true;
                          final message = n['message'] as String? ?? '';
                          final createdAt = DateTime.tryParse(n['created_at'] as String? ?? '')?.toLocal();
                          final timeStr = createdAt != null
                              ? '${createdAt.day}/${createdAt.month} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}'
                              : '';
                          return GestureDetector(
                            onTap: isReplied ? null : () {
                              Navigator.pop(context);
                              context.push('/chat');
                            },
                            child: Opacity(
                              opacity: isReplied ? 0.45 : 1.0,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppTheme.cardColor,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isReplied ? AppTheme.glassBorderColor : AppTheme.primaryColor.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: isReplied
                                          ? AppTheme.silverMuted.withValues(alpha: 0.15)
                                          : AppTheme.primaryColor.withValues(alpha: 0.15),
                                      child: Text('A',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: isReplied ? AppTheme.silverMuted : AppTheme.primaryColor)),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(message,
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  color: isReplied ? AppTheme.textSecondary : AppTheme.textPrimary,
                                                  height: 1.4),
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis),
                                          const SizedBox(height: 4),
                                          Text(timeStr,
                                              style: const TextStyle(fontSize: 11, color: AppTheme.textHint)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // INCOME CHOICE CARD: salary staged, awaiting sweep/carry-over decision
  // ─────────────────────────────────────────────
  Widget _buildIncomeChoiceCard(
    BuildContext context,
    PendingIncomeState pending,
    List<VaultModel> goalFunds,
  ) {
    final amount = pending.amount ?? 0;
    final carryover = pending.totalCarryover ?? 0;
    final hasCarryover = carryover > 0.009;

    final msg = hasCarryover
        ? 'Your salary of RM ${amount.toStringAsFixed(2)} is ready! You have RM ${carryover.toStringAsFixed(2)} unspent across your spending vaults. Keep it or sweep it into a savings goal?'
        : 'Your salary of RM ${amount.toStringAsFixed(2)} is ready to be distributed. Apply it to your vaults now.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.14),
            AppTheme.primaryColor.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.primaryColor,
                child: Text('A', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              SizedBox(width: 10),
              Text(
                'Aion · Salary Ready',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryColor, letterSpacing: 0.2),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(msg, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, height: 1.4)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _IncomeActionButton(
                  label: 'Keep existing',
                  isPrimary: !hasCarryover,
                  onPressed: () async {
                    final result = await IncomeApi().applyIncome(
                      injectionId: pending.injectionId!,
                      mode: 'carry_over',
                    );
                    final completedGoals = result['completed_goals'] as List<dynamic>? ?? [];
                    bool wantsChat = false;
                    for (final goal in completedGoals) {
                      if (!context.mounted) break;
                      final tappedChat = await GoalCelebrationOverlay.show(
                        context,
                        vaultName: goal['vault_name'] as String,
                        goalTargetAmount: (goal['goal_target_amount'] as num).toDouble(),
                        allocationPercentage: (goal['allocation_percentage'] as num?)?.toInt() ?? 0,
                      );
                      if (tappedChat) wantsChat = true;
                    }
                    ref.read(pendingIncomeProvider.notifier).clear();
                    ref.read(vaultProvider.notifier).fetchVaults();
                    if (wantsChat && context.mounted) context.push('/chat');
                  },
                ),
              ),
              if (hasCarryover) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: _IncomeActionButton(
                    label: 'Sweep to goal →',
                    isPrimary: true,
                    onPressed: () async => _showSweepSheet(context, pending, goalFunds),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showSweepSheet(
    BuildContext context,
    PendingIncomeState pending,
    List<VaultModel> goalFunds,
  ) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (_) => _SweepGoalSheet(
        pending: pending,
        goalFunds: goalFunds,
        onSuccess: () {
          ref.read(pendingIncomeProvider.notifier).clear();
          ref.read(vaultProvider.notifier).fetchVaults();
          Navigator.of(context, rootNavigator: true).pop();
        },
      ),
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
  String? _archivingGoalId;

  Future<void> _archiveGoal(VaultModel fund) async {
    if (_archivingGoalId != null) return;
    setState(() => _archivingGoalId = fund.id);
    try {
      await VaultApi().archiveGoal(fund.id!);
      await ref.read(vaultProvider.notifier).fetchVaults();
      if (mounted) {
        final funds = ref.read(vaultProvider).savingFunds;
        if (_currentFundPage >= funds.length) {
          setState(() => _currentFundPage = funds.isEmpty ? 0 : funds.length - 1);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppTheme.errorColor,
        ));
      }
    } finally {
      if (mounted) setState(() => _archivingGoalId = null);
    }
  }

  Widget _buildFundSection(List<VaultModel> funds) {
    const cardHeight = 162.0;

    return Stack(
      children: [
        SizedBox(
          height: cardHeight,
          child: PageView.builder(
            controller: _fundPageController,
            itemCount: funds.length,
            onPageChanged: (i) => setState(() => _currentFundPage = i),
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () => context.push('/vault-detail/${funds[i].id}'),
                child: FundCard(
                  fund: funds[i],
                  isArchiving: _archivingGoalId == funds[i].id,
                  onArchive: funds[i].completedAt != null
                      ? () => _archiveGoal(funds[i])
                      : null,
                ),
              ),
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
          onTap: () => context.push('/transfer'),
        ),
        const SizedBox(width: 12),
        _QuickActionButton(
          icon: Icons.auto_awesome_rounded,
          label: 'Aion',
          isHighlighted: true,
          onTap: () => context.push('/chat'),
        ),
        const SizedBox(width: 12),
        _QuickActionButton(
          icon: Icons.call_received_rounded,
          label: 'Receive',
          onTap: () => context.push('/receive'),
        ),
      ],
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
            final vaultId = entry.value.id;
            return Column(
              children: [
                GestureDetector(
                  onTap: vaultId != null
                      ? () => context.push('/vault-detail/$vaultId')
                      : null,
                  behavior: HitTestBehavior.opaque,
                  child: VaultCard(vault: entry.value),
                ),
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

// ─── Income choice action button ─────────────
class _IncomeActionButton extends StatefulWidget {
  final String label;
  final bool isPrimary;
  final Future<void> Function()? onPressed;

  const _IncomeActionButton({
    required this.label,
    required this.isPrimary,
    this.onPressed,
  });

  @override
  State<_IncomeActionButton> createState() => _IncomeActionButtonState();
}

class _IncomeActionButtonState extends State<_IncomeActionButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ElevatedButton(
        onPressed: _loading || widget.onPressed == null
            ? null
            : () async {
                setState(() => _loading = true);
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await widget.onPressed!();
                } catch (e) {
                  if (mounted) {
                    messenger.showSnackBar(SnackBar(
                      content: Text(e.toString().replaceFirst('Exception: ', '')),
                      backgroundColor: AppTheme.errorColor,
                    ));
                  }
                } finally {
                  if (mounted) setState(() => _loading = false);
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: widget.isPrimary ? AppTheme.primaryColor : AppTheme.cardColor,
          foregroundColor: widget.isPrimary ? Colors.black : AppTheme.textPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: widget.isPrimary
                ? BorderSide.none
                : const BorderSide(color: AppTheme.glassBorderColor),
          ),
        ),
        child: _loading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: widget.isPrimary ? Colors.black : AppTheme.primaryColor,
                ),
              )
            : Text(widget.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// ─── Sweep goal bottom sheet ─────────────────
class _SweepGoalSheet extends StatefulWidget {
  final PendingIncomeState pending;
  final List<VaultModel> goalFunds;
  final VoidCallback onSuccess;

  const _SweepGoalSheet({
    required this.pending,
    required this.goalFunds,
    required this.onSuccess,
  });

  @override
  State<_SweepGoalSheet> createState() => _SweepGoalSheetState();
}

class _SweepGoalSheetState extends State<_SweepGoalSheet> {
  String? _selectedVaultId;
  String? _selectedVaultName;
  bool _isApplying = false;

  Color _parseColour(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
    } catch (_) {
      return AppTheme.primaryColor;
    }
  }

  Future<void> _confirm() async {
    if (_selectedVaultId == null) return;
    setState(() => _isApplying = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await IncomeApi().applyIncome(
        injectionId: widget.pending.injectionId!,
        mode: 'sweep',
        goalVaultId: _selectedVaultId,
      );
      if (!mounted) return;
      final completedGoals = result['completed_goals'] as List<dynamic>? ?? [];
      bool wantsChat = false;
      for (final goal in completedGoals) {
        if (!mounted) break;
        final tappedChat = await GoalCelebrationOverlay.show(
          context,
          vaultName: goal['vault_name'] as String,
          goalTargetAmount: (goal['goal_target_amount'] as num).toDouble(),
          allocationPercentage: (goal['allocation_percentage'] as num?)?.toInt() ?? 0,
        );
        if (tappedChat) wantsChat = true;
      }
      if (mounted) widget.onSuccess();
      if (wantsChat && mounted) context.push('/chat');
    } catch (e) {
      if (mounted) {
        setState(() => _isApplying = false);
        messenger.showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppTheme.errorColor,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final carryover = widget.pending.totalCarryover ?? 0;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.glassBorderColor, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Choose a Savings Goal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                const SizedBox(height: 4),
                Text(
                  'RM ${carryover.toStringAsFixed(2)} from your spending vaults will be swept here.',
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 246),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: widget.goalFunds.length,
                    itemBuilder: (context, index) {
                      final fund = widget.goalFunds[index];
                      final colour = _parseColour(fund.vaultColour);
                      final isSelected = _selectedVaultId == fund.id;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _selectedVaultId = fund.id;
                          _selectedVaultName = fund.name;
                        }),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isSelected ? colour.withValues(alpha: 0.10) : AppTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? colour : AppTheme.glassBorderColor,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(color: colour.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                                child: Icon(isSelected ? Icons.check_rounded : Icons.savings_outlined, color: colour, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(fund.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                                    Text('RM ${fund.currentBalance.toStringAsFixed(2)} saved', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // Button lives OUTSIDE the horizontal padding so SafeArea can
          // correctly insert the system nav bar inset below it.
          const SizedBox(height: 8),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: (_selectedVaultId == null || _isApplying) ? null : _confirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: AppTheme.primaryColor.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isApplying
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
                    : Text(
                        _selectedVaultName != null
                            ? 'Sweep to $_selectedVaultName'
                            : 'Select a goal first',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
