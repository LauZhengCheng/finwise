// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : debt_strategy_screen.dart
// Description   : Aion's Debt Strategy — whiteboard-style analysis
//                 showing payment priority with connected flow,
//                 reasoning bubbles, and key metrics.
// First Written : 20-06-2026
// Edited on     : 20-06-2026
// ============================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/app_theme.dart';
import '../../services/api/debt_api.dart';
import '../../widgets/shimmer_loading.dart';

class DebtStrategyScreen extends StatefulWidget {
  const DebtStrategyScreen({super.key});

  @override
  State<DebtStrategyScreen> createState() => _DebtStrategyScreenState();
}

class _DebtStrategyScreenState extends State<DebtStrategyScreen> {
  final _fmt = NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ', decimalDigits: 2);
  Map<String, dynamic>? _strategy;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await DebtApi().getStrategy();
      if (!mounted) return;
      setState(() {
        _strategy = result['strategy'] as Map<String, dynamic>?;
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
    return Scaffold(
      backgroundColor: const Color(0xFF0D0B08),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1610), Color(0xFF0D0B08)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Header with Aion branding ──
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: const Icon(Icons.arrow_back_rounded,
                          color: AppTheme.textPrimary, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      width: 32, height: 32,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppTheme.goldGradient,
                      ),
                      child: const Center(
                        child: Text('A', style: TextStyle(
                          color: Color(0xFF0A0800), fontSize: 14, fontWeight: FontWeight.w800)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Aion's Strategy", style: TextStyle(
                          color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
                        Text('Personalised debt payoff plan', style: TextStyle(
                          color: AppTheme.primaryColor, fontSize: 11, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _loading
                    ? const Padding(padding: EdgeInsets.all(20), child: SkeletonTransactionList(count: 4))
                    : _error != null
                        ? Center(child: Text(_error!, style: const TextStyle(color: AppTheme.errorColor)))
                        : _strategy == null
                            ? const Center(child: Text('Add debts first to see your strategy',
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)))
                            : _buildStrategy(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStrategy() {
    final s = _strategy!;
    final priorityList = (s['priority_list'] as List? ?? []).cast<Map<String, dynamic>>();
    final debtVault = s['debt_vault'] as Map<String, dynamic>?;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 108),
      children: [
        // ── Key metrics row ──
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1A14),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _MetricTile(
                    label: 'Total Debt',
                    value: _fmt.format(s['total_balance'] ?? 0),
                    color: AppTheme.errorColor,
                  )),
                  Container(width: 1, height: 40, color: AppTheme.glassBorderColor),
                  Expanded(child: _MetricTile(
                    label: 'Monthly Payment',
                    value: _fmt.format(s['total_monthly_payment'] ?? 0),
                    color: AppTheme.textPrimary,
                  )),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: AppTheme.glassBorderColor, height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _MetricTile(
                    label: 'Interest Cost/mo',
                    value: _fmt.format(s['monthly_interest_cost'] ?? 0),
                    color: AppTheme.errorColor,
                  )),
                  Container(width: 1, height: 40, color: AppTheme.glassBorderColor),
                  Expanded(child: _MetricTile(
                    label: 'Interest Saved',
                    value: _fmt.format(s['interest_saved_vs_minimum'] ?? 0),
                    color: AppTheme.successColor,
                  )),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Strategy badge + debt-free date ──
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: AppTheme.goldGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(s['type'] == 'avalanche' ? Icons.bolt_rounded : Icons.emoji_events_rounded,
                    color: const Color(0xFF0A0800), size: 14),
                  const SizedBox(width: 4),
                  Text((s['type'] as String? ?? 'AVALANCHE').toUpperCase(), style: const TextStyle(
                    color: Color(0xFF0A0800), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(s['description'] as String? ?? '', style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (s['recommendation_reason'] != null) ...[
          const SizedBox(height: 8),
          Text(s['recommendation_reason'] as String? ?? '', style: const TextStyle(
            color: AppTheme.textHint, fontSize: 11, height: 1.4)),
        ],
        if (debtVault != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_rounded, color: AppTheme.primaryColor, size: 14),
              const SizedBox(width: 6),
              Text('${debtVault['name']}: ${debtVault['allocation']}% allocation',
                style: const TextStyle(color: AppTheme.primaryColor, fontSize: 12)),
            ],
          ),
        ],
        if (s['debt_free_date'] != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.flag_rounded, color: AppTheme.successColor, size: 14),
              const SizedBox(width: 6),
              Text('Debt-free by ${s['debt_free_date']}',
                style: const TextStyle(color: AppTheme.successColor, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
        const SizedBox(height: 28),

        // ── Priority flow header ──
        const Text('PAYMENT PRIORITY', style: TextStyle(
          color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.4)),
        const SizedBox(height: 4),
        Text(s['type'] == 'snowball'
          ? 'Ordered by balance — smallest first'
          : 'Ordered by interest rate — highest first',
          style: const TextStyle(color: AppTheme.textHint, fontSize: 11)),
        const SizedBox(height: 16),

        // ── Connected priority flow ──
        ...List.generate(priorityList.length, (i) {
          final debt = priorityList[i];
          final isTop = i == 0;
          final isLast = i == priorityList.length - 1;
          return _PriorityFlowItem(
            debt: debt,
            fmt: _fmt,
            isTop: isTop,
            isLast: isLast,
            index: i,
          );
        }),
        const SizedBox(height: 28),

        // ── Discuss with Aion ──
        GestureDetector(
          onTap: () => context.push('/chat'),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor.withValues(alpha: 0.12),
                  AppTheme.primaryColor.withValues(alpha: 0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_awesome_rounded, color: AppTheme.primaryColor, size: 18),
                SizedBox(width: 8),
                Text('Discuss with Aion', style: TextStyle(
                  color: AppTheme.primaryColor, fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Metric tile (for the top grid) ──
class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricTile({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textHint, fontSize: 10, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

// ── Connected priority flow item with timeline line ──
class _PriorityFlowItem extends StatelessWidget {
  final Map<String, dynamic> debt;
  final NumberFormat fmt;
  final bool isTop;
  final bool isLast;
  final int index;

  const _PriorityFlowItem({
    required this.debt,
    required this.fmt,
    required this.isTop,
    required this.isLast,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final rate = (debt['interest_rate'] as num?)?.toDouble() ?? 0;
    final payment = (debt['monthly_payment'] as num?)?.toDouble() ?? 0;
    final extra = (debt['extra_payment'] as num?)?.toDouble() ?? 0;
    final balance = (debt['balance'] as num?)?.toDouble() ?? 0;
    final monthlyInt = (debt['monthly_interest'] as num?)?.toDouble() ?? 0;
    final remaining = debt['remaining_months'] as int?;
    final reason = debt['reason'] as String? ?? '';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Timeline connector ──
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isTop ? AppTheme.goldGradient : null,
                    color: isTop ? null : AppTheme.glassBorderColor,
                    border: isTop ? null : Border.all(color: AppTheme.textHint.withValues(alpha: 0.3)),
                  ),
                  child: Center(
                    child: isTop
                        ? const Icon(Icons.bolt_rounded, color: Color(0xFF0A0800), size: 14)
                        : Text('${index + 1}', style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.glassBorderColor,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // ── Content ──
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isTop ? const Color(0xFF1E1A14) : AppTheme.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isTop ? AppTheme.primaryColor.withValues(alpha: 0.35) : AppTheme.glassBorderColor,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + rate
                  Row(
                    children: [
                      Expanded(
                        child: Text(debt['name'] as String? ?? '', style: const TextStyle(
                          color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isTop ? AppTheme.errorColor : AppTheme.textHint).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('${rate.toStringAsFixed(1)}%', style: TextStyle(
                          color: isTop ? AppTheme.errorColor : AppTheme.textSecondary,
                          fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Stats row
                  Row(
                    children: [
                      _MiniLabel(top: 'Balance', bottom: fmt.format(balance)),
                      const SizedBox(width: 14),
                      _MiniLabel(top: 'Payment', bottom: '${fmt.format(payment)}/mo'),
                      if (extra > 0) ...[
                        const SizedBox(width: 14),
                        _MiniLabel(top: 'Extra', bottom: '+${fmt.format(extra)}',
                          color: AppTheme.successColor),
                      ],
                    ],
                  ),
                  if (remaining != null) ...[
                    const SizedBox(height: 4),
                    Text('~$remaining months left · ${fmt.format(monthlyInt)} interest/mo',
                      style: const TextStyle(color: AppTheme.textHint, fontSize: 10)),
                  ],
                  const SizedBox(height: 10),

                  // Reasoning bubble
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isTop
                          ? AppTheme.primaryColor.withValues(alpha: 0.08)
                          : AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isTop
                            ? AppTheme.primaryColor.withValues(alpha: 0.2)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.auto_awesome_rounded,
                          size: 12,
                          color: isTop ? AppTheme.primaryColor : AppTheme.textHint),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(reason, style: TextStyle(
                            color: isTop ? AppTheme.primaryColor : AppTheme.textSecondary,
                            fontSize: 11, height: 1.4)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniLabel extends StatelessWidget {
  final String top;
  final String bottom;
  final Color? color;

  const _MiniLabel({required this.top, required this.bottom, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(top, style: const TextStyle(color: AppTheme.textHint, fontSize: 9, letterSpacing: 0.3)),
        const SizedBox(height: 2),
        Text(bottom, style: TextStyle(
          color: color ?? AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
