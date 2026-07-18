// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : vault_detail_screen.dart
// Description   : Single vault detail — balance, goal progress,
//                 and full transaction history for that vault.
// First Written : 17-06-2026
// Edited on     : 17-06-2026
// ============================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_theme.dart';
import '../../models/vault_model.dart';
import '../../providers/vault_provider.dart';
import '../../services/api/transaction_api.dart';
import '../../widgets/shimmer_loading.dart';

class VaultDetailScreen extends ConsumerStatefulWidget {
  final String vaultId;
  const VaultDetailScreen({super.key, required this.vaultId});

  @override
  ConsumerState<VaultDetailScreen> createState() => _VaultDetailScreenState();
}

class _VaultDetailScreenState extends ConsumerState<VaultDetailScreen> {
  final _currency =
      NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ', decimalDigits: 2);

  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _allocationHistory = [];
  bool _loadingTx = true;
  String? _txError;
  String _statusFilter = 'all';

  List<Map<String, dynamic>> get _filtered {
    if (_statusFilter == 'all') return _transactions;
    return _transactions.where((t) => t['status'] == _statusFilter).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadTransactions();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllocationHistory();
    });
  }

  Future<void> _loadTransactions() async {
    try {
      final filtered = await TransactionApi().getHistory(vaultId: widget.vaultId);
      if (mounted) {
        setState(() {
          _transactions = filtered;
          _loadingTx = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _txError = e.toString().replaceFirst('Exception: ', '');
          _loadingTx = false;
        });
      }
    }
  }

  Future<void> _loadAllocationHistory() async {
    try {
      final vault = _findVault();
      if (vault == null) return;
      final categoryKey = vault.categoryKey;

      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      final response = await Supabase.instance.client
          .from('allocation_history')
          .select('new_allocation, previous_allocation, change_reason, triggered_by, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(20);

      final records = <Map<String, dynamic>>[];
      for (final row in (response as List)) {
        final newAlloc = row['new_allocation'] as Map<String, dynamic>?;
        final prevAlloc = row['previous_allocation'] as Map<String, dynamic>?;
        if (newAlloc == null || !newAlloc.containsKey(categoryKey)) continue;

        final newPct = newAlloc[categoryKey] as num?;
        final prevPct = prevAlloc != null && prevAlloc.containsKey(categoryKey)
            ? prevAlloc[categoryKey] as num?
            : null;

        records.add({
          'new_pct': newPct,
          'prev_pct': prevPct,
          'reason': row['change_reason'] as String?,
          'triggered_by': row['triggered_by'] as String?,
          'created_at': row['created_at'] as String?,
        });
      }

      if (mounted) setState(() => _allocationHistory = records);
    } catch (_) {}
  }

  VaultModel? _findVault() {
    final vaults = ref.watch(vaultProvider).vaults;
    try {
      return vaults.firstWhere((v) => v.id == widget.vaultId);
    } catch (_) {
      return null;
    }
  }

  Color _vaultColor(String colorHex) {
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final vault = _findVault();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: DecoratedBox(
        decoration:
            const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: vault == null
              ? _notFound()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(vault),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 108),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildVaultCard(vault),
                            const SizedBox(height: 28),
                            _buildTransactionsSection(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeader(VaultModel vault) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(Icons.arrow_back_rounded,
                color: AppTheme.textPrimary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vault.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  vault.vaultType == 'fund' ? 'Saving Goal' : 'Spending Vault',
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (vault.vaultType == 'fund'
                      ? AppTheme.primaryColor
                      : AppTheme.textHint)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              vault.vaultType == 'fund' ? 'GOAL' : 'VAULT',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: vault.vaultType == 'fund'
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVaultCard(VaultModel vault) {
    final color = _vaultColor(vault.vaultColour);
    final isFund = vault.vaultType == 'fund';
    final progress = isFund && (vault.goalTargetAmount ?? 0) > 0
        ? (vault.currentBalance / vault.goalTargetAmount!).clamp(0.0, 1.0)
        : vault.allocatedAmount > 0
            ? (vault.spentAmount / vault.allocatedAmount).clamp(0.0, 1.0)
            : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.12),
            AppTheme.cardColor,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Balance
          Text(
            isFund ? 'Saved' : 'Current Balance',
            style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                letterSpacing: 0.3),
          ),
          const SizedBox(height: 4),
          Text(
            _currency.format(vault.currentBalance),
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -1.5,
              height: 1.0,
            ),
          ),

          if (isFund && vault.goalTargetAmount != null) ...[
            const SizedBox(height: 4),
            Text(
              'Target: ${_currency.format(vault.goalTargetAmount!)}',
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary),
            ),
          ] else ...[
            const SizedBox(height: 4),
            Text(
              'Spent: ${_currency.format(vault.spentAmount)} / ${_currency.format(vault.allocatedAmount)}',
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary),
            ),
          ],

          const SizedBox(height: 14),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppTheme.glassBorderColor,
              valueColor: AlwaysStoppedAnimation<Color>(
                isFund
                    ? (progress >= 1.0 ? AppTheme.successColor : color)
                    : (progress > 0.85 ? AppTheme.errorColor : color),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isFund
                ? '${(progress * 100).toStringAsFixed(1)}% of goal reached'
                : '${(progress * 100).toStringAsFixed(1)}% of budget used',
            style: const TextStyle(
                fontSize: 11, color: AppTheme.textHint),
          ),

          if (vault.linkedGoal != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.flag_rounded,
                    size: 14, color: AppTheme.textHint),
                const SizedBox(width: 6),
                Text(
                  vault.linkedGoal!,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textHint),
                ),
              ],
            ),
          ],
          if (_allocationHistory.isNotEmpty) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _showAllocationHistorySheet,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_rounded, size: 13, color: AppTheme.primaryColor.withValues(alpha: 0.7)),
                  const SizedBox(width: 5),
                  Text(
                    'Allocation History (${_allocationHistory.length})',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAllocationHistorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141210),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(
              color: AppTheme.glassBorderColor, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.history_rounded, size: 16, color: AppTheme.primaryColor.withValues(alpha: 0.7)),
                  const SizedBox(width: 8),
                  const Text('Allocation History', style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  const Spacer(),
                  Text('${_allocationHistory.length} changes', style: const TextStyle(
                    fontSize: 12, color: AppTheme.textHint)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                itemCount: _allocationHistory.length,
                itemBuilder: (context, i) => _buildHistoryItem(i),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(int i) {
    final dateFmt = DateFormat('d MMM yyyy');
    final record = _allocationHistory[i];
    final newPct = record['new_pct'] as num?;
    final prevPct = record['prev_pct'] as num?;
    final reason = record['reason'] as String?;
    final trigger = record['triggered_by'] as String?;
    final createdAt = record['created_at'] as String?;
    final date = createdAt != null ? dateFmt.format(DateTime.parse(createdAt).toLocal()) : '';
    final isLast = i == _allocationHistory.length - 1;
    final hasChange = prevPct != null && prevPct != newPct;

    String triggerLabel;
    IconData triggerIcon;
    switch (trigger) {
      case 'onboarding':
        triggerLabel = 'Initial setup';
        triggerIcon = Icons.flag_rounded;
        break;
      case 'conversation':
      case 'ai_chat':
        triggerLabel = 'Aion adjustment';
        triggerIcon = Icons.auto_awesome_rounded;
        break;
      case 'goal_change':
        triggerLabel = 'Goal update';
        triggerIcon = Icons.track_changes_rounded;
        break;
      case 'income_change':
        triggerLabel = 'Income change';
        triggerIcon = Icons.attach_money_rounded;
        break;
      default:
        triggerLabel = trigger ?? 'Update';
        triggerIcon = Icons.edit_rounded;
    }

    final isFirst = i == 0;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 14, height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isFirst ? AppTheme.goldGradient : null,
                    color: isFirst ? null : AppTheme.glassBorderColor,
                  ),
                  child: isFirst
                      ? const Icon(Icons.circle, size: 6, color: Color(0xFF0A0800))
                      : null,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2, margin: const EdgeInsets.symmetric(vertical: 4),
                      color: AppTheme.glassBorderColor.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isFirst ? const Color(0xFF1E1A14) : AppTheme.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isFirst
                      ? AppTheme.primaryColor.withValues(alpha: 0.25)
                      : AppTheme.glassBorderColor,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(triggerIcon, size: 13,
                        color: isFirst ? AppTheme.primaryColor : AppTheme.textHint),
                      const SizedBox(width: 6),
                      Text(triggerLabel, style: TextStyle(
                        color: isFirst ? AppTheme.primaryColor : AppTheme.textSecondary,
                        fontSize: 12, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text(date, style: const TextStyle(color: AppTheme.textHint, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (hasChange)
                    Row(
                      children: [
                        Text('$prevPct%', style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 18, fontWeight: FontWeight.w700)),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.arrow_forward_rounded, size: 16, color: AppTheme.primaryColor),
                        ),
                        Text('$newPct%', style: const TextStyle(
                          color: AppTheme.primaryColor, fontSize: 18, fontWeight: FontWeight.w700)),
                      ],
                    )
                  else if (newPct != null)
                    Text('$newPct%', style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                  if (reason != null && reason.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(reason, style: const TextStyle(
                      color: AppTheme.textHint, fontSize: 11, height: 1.4)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _dateLabel(String isoString) {
    final date = DateTime.parse(isoString).toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Today';
    if (d == yesterday) return 'Yesterday';
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Widget _buildTransactionsSection() {
    final filtered = _filtered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'TRANSACTION HISTORY',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['all', 'approved', 'blocked', 'cancelled'].map((s) {
              final active = _statusFilter == s;
              final label = s == 'all' ? 'All' : s[0].toUpperCase() + s.substring(1);
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _statusFilter = s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: active ? AppTheme.primaryColor.withValues(alpha: 0.15) : AppTheme.cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: active ? AppTheme.primaryColor : AppTheme.glassBorderColor,
                      ),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: active ? AppTheme.primaryColor : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        if (_loadingTx)
          const SkeletonTransactionList(count: 5)
        else if (_txError != null)
          _ErrorRow(error: _txError!, onRetry: _loadTransactions)
        else if (filtered.isEmpty)
          const _EmptyTx()
        else
          _buildGroupedList(filtered),
      ],
    );
  }

  Widget _buildGroupedList(List<Map<String, dynamic>> txs) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final tx in txs) {
      final label = _dateLabel(tx['created_at'] as String);
      grouped.putIfAbsent(label, () => []).add(tx);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: grouped.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                entry.key,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            ...entry.value.map((tx) => _TxRow(tx: tx)),
            const SizedBox(height: 16),
          ],
        );
      }).toList(),
    );
  }

  Widget _notFound() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off_rounded,
              size: 48, color: AppTheme.textHint),
          const SizedBox(height: 12),
          const Text('Vault not found',
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 16)),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Go back',
                style: TextStyle(color: AppTheme.primaryColor)),
          ),
        ],
      ),
    );
  }
}

// ── Transaction row (matches general transaction page style) ─────────
class _TxRow extends StatelessWidget {
  final Map<String, dynamic> tx;

  const _TxRow({required this.tx});

  @override
  Widget build(BuildContext context) {
    final status = tx['status'] as String? ?? 'approved';
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0;
    final merchantName = tx['merchant_name'] as String? ?? 'Unknown';
    final createdAt = tx['created_at'] as String?;
    final txType = tx['transaction_type'] as String? ?? 'expense';
    final isIncome = txType == 'income';
    final isTransfer = txType == 'transfer';
    final isIncomingTransfer = isTransfer && merchantName.startsWith('From:');
    final moneyMoved = status == 'approved';
    final note = tx['note'] as String?;

    final amountPrefix = !moneyMoved ? '' : (isIncome || isIncomingTransfer) ? '+ ' : '- ';
    final amountColor = !moneyMoved
        ? AppTheme.silverMuted
        : (isIncome || isIncomingTransfer)
            ? AppTheme.successColor
            : AppTheme.errorColor;

    final time = createdAt != null ? _formatTime(createdAt) : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppTheme.glassCard(radius: 16, elevated: true),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: amountColor.withValues(alpha: 0.12),
              ),
              child: Icon(
                _txIcon(status, isIncome, isTransfer, isIncomingTransfer),
                size: 20,
                color: amountColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(merchantName,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 3),
                  _StatusBadge(status: status),
                  if (note != null && note.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(note,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textHint,
                            fontStyle: FontStyle.italic)),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${amountPrefix}RM ${amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: amountColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(time,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textHint)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _txIcon(String status, bool isIncome, bool isTransfer, bool isIncomingTransfer) {
    if (status == 'blocked') return Icons.block_rounded;
    if (status == 'cancelled') return Icons.cancel_rounded;
    if (isIncomingTransfer) return Icons.call_received_rounded;
    if (isTransfer) return Icons.send_rounded;
    return isIncome ? Icons.arrow_circle_down_rounded : Icons.check_circle_rounded;
  }

  String _formatTime(String isoString) {
    final dt = DateTime.parse(isoString).toLocal();
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ── Status badge pill ────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'approved':
        color = AppTheme.successColor;
        label = 'Approved';
        break;
      case 'blocked':
        color = AppTheme.errorColor;
        label = 'Blocked';
        break;
      case 'cancelled':
        color = AppTheme.silverMuted;
        label = 'Cancelled';
        break;
      default:
        color = AppTheme.primaryColor;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────
class _EmptyTx extends StatelessWidget {
  const _EmptyTx();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: const Column(
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 40, color: AppTheme.textHint),
          SizedBox(height: 12),
          Text('No transactions for this vault',
              style:
                  TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
        ],
      ),
    );
  }
}

// ── Error row ─────────────────────────────────────────────────────────
class _ErrorRow extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorRow({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Text(error,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13)),
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry',
                  style: TextStyle(color: AppTheme.primaryColor)),
            ),
          ],
        ),
      ),
    );
  }
}
