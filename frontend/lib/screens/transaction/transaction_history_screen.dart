// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : transaction_history_screen.dart
// Description   : Full transaction history — all past transactions
//                 newest first, with status badges, search, and filter.
// First Written : 10-06-2026
// Edited on     : 17-06-2026
// ============================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_theme.dart';
import '../../services/api/transaction_api.dart';
import '../../widgets/shimmer_loading.dart';

// Incremented by MainScaffold each time the Transactions tab is tapped —
// causes the screen to silently reload even though it stays mounted.
final transactionRefreshTriggerProvider = StateProvider<int>((ref) => 0);

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  List<Map<String, dynamic>> _transactions = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  String _statusFilter = 'all';

  List<Map<String, dynamic>> get _filtered {
    return _transactions.where((tx) {
      final matchesStatus = _statusFilter == 'all' ||
          tx['status'] == _statusFilter;
      final merchant =
          (tx['merchant_name'] as String? ?? '').toLowerCase();
      final matchesSearch = _searchQuery.isEmpty ||
          merchant.contains(_searchQuery.toLowerCase());
      return matchesStatus && matchesSearch;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await TransactionApi().getHistory();
      if (!mounted) return;
      setState(() {
        _transactions = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        ref.listen<int>(transactionRefreshTriggerProvider, (_, __) => _load());
        return _buildScaffold(context);
      },
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 20, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Text(
                      'Transactions',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ],
                ),
              ),
              // ── Search bar ─────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search merchants...',
                    hintStyle: const TextStyle(
                        color: AppTheme.textHint, fontSize: 14),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AppTheme.textSecondary, size: 20),
                    filled: true,
                    fillColor: AppTheme.cardColor,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppTheme.glassBorderColor)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppTheme.glassBorderColor)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppTheme.primaryColor)),
                  ),
                ),
              ),
              // ── Filter chips ───────────────────────────────
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Row(
                  children: ['all', 'approved', 'blocked', 'cancelled']
                      .map((s) => _FilterChip(
                            label: s == 'all'
                                ? 'All'
                                : s[0].toUpperCase() + s.substring(1),
                            selected: _statusFilter == s,
                            onTap: () =>
                                setState(() => _statusFilter = s),
                          ))
                      .toList(),
                ),
              ),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: SkeletonTransactionList(count: 8),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 48, color: AppTheme.errorColor.withValues(alpha: 0.7)),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 14)),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  _load();
                },
                child: const Text('Retry',
                    style: TextStyle(color: AppTheme.primaryColor)),
              ),
            ],
          ),
        ),
      );
    }
    final visible = _filtered;
    if (visible.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_rounded,
                size: 56,
                color: AppTheme.silverMuted.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(_transactions.isEmpty
                    ? 'No transactions yet'
                    : 'No results found',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Text(_transactions.isEmpty
                    ? 'Your spending history will appear here'
                    : 'Try a different search or filter',
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    // Group by date
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final tx in visible) {
      final date = _dateLabel(tx['created_at'] as String);
      grouped.putIfAbsent(date, () => []).add(tx);
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.primaryColor,
      backgroundColor: AppTheme.cardColor,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 108),
        children: grouped.entries.map((entry) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DateHeader(label: entry.key),
              const SizedBox(height: 8),
              ...entry.value.map((tx) => _TransactionTile(tx: tx)),
              const SizedBox(height: 16),
            ],
          );
        }).toList(),
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
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

// ── Date section header ───────────────────────────────────────────────
class _DateHeader extends StatelessWidget {
  final String label;
  const _DateHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(child: Divider(color: AppTheme.glassBorderColor)),
      ],
    );
  }
}

// ── Single transaction tile ───────────────────────────────────────────
class _TransactionTile extends StatelessWidget {
  final Map<String, dynamic> tx;
  const _TransactionTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final vault = tx['vaults'] as Map<String, dynamic>?;
    final status = tx['status'] as String? ?? 'approved';
    final amount = (tx['amount'] as num).toDouble();
    final merchantName = tx['merchant_name'] as String? ?? 'Unknown';
    final vaultName = vault?['name'] as String? ?? '—';
    final time = _formatTime(tx['created_at'] as String);
    final txType = tx['transaction_type'] as String? ?? 'expense';
    final isIncome = txType == 'income';
    final isTransfer = txType == 'transfer';
    final isIncomingTransfer = isTransfer && merchantName.startsWith('From:');
    final note = tx['note'] as String?;
    final moneyMoved = status == 'approved';

    final amountPrefix = !moneyMoved ? '' : (isIncome || isIncomingTransfer) ? '+ ' : '- ';
    final amountColor = !moneyMoved
        ? AppTheme.silverMuted
        : (isIncome || isIncomingTransfer)
            ? AppTheme.successColor
            : AppTheme.errorColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppTheme.glassCard(radius: 16, elevated: true),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    // Status icon circle
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

                    // Merchant + vault
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            merchantName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  vaultName,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary),
                                ),
                              ),
                              const SizedBox(width: 6),
                              _StatusBadge(status: status),
                            ],
                          ),
                          if (note != null && note.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              note,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textHint,
                                  fontStyle: FontStyle.italic),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Amount + time
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
                        Text(
                          time,
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textHint),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

IconData _txIcon(String status, bool isIncome, bool isTransfer, bool isIncomingTransfer) {
    if (status == 'blocked')    return Icons.block_rounded;
    if (status == 'cancelled')  return Icons.cancel_rounded;
    if (isIncomingTransfer)     return Icons.call_received_rounded;
    if (isTransfer)             return Icons.send_rounded;
    return isIncome ? Icons.arrow_circle_down_rounded : Icons.check_circle_rounded;
  }

  String _formatTime(String isoString) {
    final dt = DateTime.parse(isoString).toLocal();
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ── Filter chip ───────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryColor
              : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppTheme.primaryColor
                : AppTheme.glassBorderColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected
                ? const Color(0xFF0A0800)
                : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ── Status badge chip ─────────────────────────────────────────────────
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
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
