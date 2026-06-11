// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : transaction_history_screen.dart
// Description   : Full transaction history — all past transactions
//                 newest first, with status badges and vault info.
// First Written : 10-06-2026
// Edited on     : 10-06-2026
// ============================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_theme.dart';
import '../../services/api/transaction_api.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await TransactionApi().getHistory();
      setState(() {
        _transactions = data;
        _loading = false;
      });
    } catch (e) {
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
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Text(
                  'Transactions',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.8,
                  ),
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
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
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
    if (_transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_rounded,
                size: 56,
                color: AppTheme.silverMuted.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            const Text('No transactions yet',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            const Text('Your spending history will appear here',
                style:
                    TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    // Group by date
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final tx in _transactions) {
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
    final merchantCategory = tx['merchant_category'] as String?;
    final vaultName = vault?['name'] as String? ?? '—';
    final time = _formatTime(tx['created_at'] as String);
    final accentColor = _categoryColor(merchantCategory);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppTheme.glassCard(radius: 16, elevated: true),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left accent stripe keyed to vault category
            Container(width: 4, color: accentColor),

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
                        color: _statusColor(status).withValues(alpha: 0.12),
                      ),
                      child: Icon(
                        _statusIcon(status),
                        size: 20,
                        color: _statusColor(status),
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
                              Text(
                                vaultName,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary),
                              ),
                              const SizedBox(width: 6),
                              _StatusBadge(status: status),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Amount + time
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          status == 'blocked' || status == 'cancelled'
                              ? 'RM ${amount.toStringAsFixed(2)}'
                              : '- RM ${amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: status == 'approved'
                                ? AppTheme.successColor
                                : AppTheme.silverMuted,
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

  Color _categoryColor(String? category) {
    if (category == null || category.isEmpty) return AppTheme.silverMuted;
    final c = category.toLowerCase();
    if (c.contains('food') || c.contains('dining') || c.contains('grocer') || c.contains('essential')) return AppTheme.vaultGreen;
    if (c.contains('transport') || c.contains('petrol') || c.contains('grab') || c.contains('fuel')) return AppTheme.vaultBlue;
    if (c.contains('entertainment') || c.contains('gaming') || c.contains('cinema') || c.contains('streaming')) return AppTheme.vaultPurple;
    if (c.contains('health') || c.contains('medical') || c.contains('pharmacy') || c.contains('fitness')) return AppTheme.vaultTeal;
    if (c.contains('shopping') || c.contains('fashion') || c.contains('clothing')) return AppTheme.vaultOrange;
    if (c.contains('education') || c.contains('course') || c.contains('book')) return AppTheme.vaultBlue;
    if (c.contains('parent') || c.contains('support') || c.contains('family')) return AppTheme.vaultTeal;
    if (c.contains('saving') || c.contains('fund') || c.contains('emergency')) return AppTheme.primaryColor;
    // Hash fallback — unknown categories get a consistent colour
    const colors = [
      AppTheme.vaultGreen, AppTheme.vaultBlue, AppTheme.vaultOrange,
      AppTheme.vaultPurple, AppTheme.vaultTeal,
    ];
    return colors[category.hashCode.abs() % colors.length];
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':  return AppTheme.successColor;
      case 'blocked':   return AppTheme.errorColor;
      case 'cancelled': return AppTheme.silverMuted;
      default:          return AppTheme.primaryColor;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'approved':  return Icons.check_circle_rounded;
      case 'blocked':   return Icons.block_rounded;
      case 'cancelled': return Icons.cancel_rounded;
      default:          return Icons.receipt_rounded;
    }
  }

  String _formatTime(String isoString) {
    final dt = DateTime.parse(isoString).toLocal();
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
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
