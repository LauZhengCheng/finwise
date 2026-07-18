// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : spending_forecast_screen.dart
// Description   : Spending forecast — pace check, trend-adjusted
//                 daily average, run-out date, target daily spend,
//                 and month-over-month comparison per vault.
// First Written : 17-06-2026
// Edited on     : 21-06-2026
// ============================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/app_theme.dart';
import '../../widgets/shimmer_loading.dart';
import '../../services/api/finance_api.dart';

class SpendingForecastScreen extends StatefulWidget {
  const SpendingForecastScreen({super.key});

  @override
  State<SpendingForecastScreen> createState() => _SpendingForecastScreenState();
}

class _SpendingForecastScreenState extends State<SpendingForecastScreen> {
  final _fmt = NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ', decimalDigits: 2);

  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _monthProgress;
  List<Map<String, dynamic>> _forecasts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final response = await FinanceApi().getSpendingForecast();
      if (!mounted) return;
      final data = response['data'] as Map<String, dynamic>? ?? {};
      setState(() {
        _monthProgress = data['month_progress'] as Map<String, dynamic>?;
        _forecasts = (data['forecasts'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'critical': return AppTheme.errorColor;
      case 'warning': return const Color(0xFFF59E0B);
      default: return AppTheme.successColor;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'critical': return 'Over pace';
      case 'warning': return 'Tight';
      default: return 'On track';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
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
                    const Text('Spending Forecast', style: TextStyle(
                      color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Padding(padding: EdgeInsets.all(20), child: SkeletonTransactionList(count: 5));
    }
    if (_error != null) {
      return Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.errorColor, size: 48),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          const SizedBox(height: 16),
          TextButton(onPressed: _load, child: const Text('Retry', style: TextStyle(color: AppTheme.primaryColor))),
        ],
      ));
    }
    if (_forecasts.isEmpty) {
      return const Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.trending_down_rounded, size: 56, color: AppTheme.textHint),
          SizedBox(height: 16),
          Text('No spending data yet', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16, fontWeight: FontWeight.w500)),
          SizedBox(height: 8),
          Text('Start making transactions to see\nyour spending forecast.', textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textHint, fontSize: 13)),
        ],
      ));
    }

    final mp = _monthProgress;

    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.primaryColor,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 108),
        children: [
          // ── Month progress bar ──
          if (mp != null) ...[
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
                      Text('Day ${mp['day']} of ${mp['total']}', style: const TextStyle(
                        color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text('${mp['left']} days left', style: const TextStyle(
                        color: AppTheme.textHint, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (mp['pct'] as num).toDouble() / 100,
                      backgroundColor: AppTheme.glassBorderColor,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('${mp['pct']}% through the month', style: const TextStyle(
                    color: AppTheme.textHint, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── Vault forecast cards ──
          ..._forecasts.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _ForecastCard(f: f, fmt: _fmt, statusColor: _statusColor, statusLabel: _statusLabel,
              monthPct: (mp?['pct'] as num?)?.toInt() ?? 0),
          )),
        ],
      ),
    );
  }
}

class _ForecastCard extends StatelessWidget {
  final Map<String, dynamic> f;
  final NumberFormat fmt;
  final Color Function(String) statusColor;
  final String Function(String) statusLabel;
  final int monthPct;

  const _ForecastCard({
    required this.f, required this.fmt, required this.statusColor,
    required this.statusLabel, required this.monthPct,
  });

  @override
  Widget build(BuildContext context) {
    final status = f['status'] as String? ?? 'ok';
    final color = statusColor(status);
    final balance = (f['current_balance'] as num?)?.toDouble() ?? 0;
    final allocated = (f['allocated_amount'] as num?)?.toDouble() ?? 0;
    final spent = (f['spent_amount'] as num?)?.toDouble() ?? 0;
    final budgetPct = (f['budget_used_pct'] as num?)?.toInt() ?? 0;
    final weightedAvg = (f['weighted_avg_daily'] as num?)?.toDouble() ?? 0;
    final daysRemaining = f['days_remaining'] as int?;
    final runOutDate = f['run_out_date'] as String?;
    final targetDaily = (f['target_daily'] as num?)?.toDouble() ?? 0;
    final needsReduction = f['needs_reduction'] as bool? ?? false;
    final paceRatio = (f['pace_ratio'] as num?)?.toDouble() ?? 0;
    final burstCount = (f['burst_count'] as num?)?.toInt() ?? 0;
    final burstTotal = (f['burst_total'] as num?)?.toDouble() ?? 0;
    final momPct = f['month_over_month_pct'] as int?;
    final vaultName = f['vault_name'] as String? ?? 'Vault';

    final budgetProgress = allocated > 0 ? (spent / allocated).clamp(0.0, 1.0) : 0.0;
    final paceProgress = monthPct / 100;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: status == 'critical'
              ? AppTheme.errorColor.withValues(alpha: 0.3)
              : AppTheme.glassBorderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: name + status chip
          Row(
            children: [
              Expanded(child: Text(vaultName, style: const TextStyle(
                color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Text(statusLabel(status), style: TextStyle(
                  color: color, fontSize: 10, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Balance + spent
          Row(
            children: [
              Text(fmt.format(balance), style: const TextStyle(
                color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
              Text(' left', style: const TextStyle(color: AppTheme.textHint, fontSize: 12)),
              const SizedBox(width: 8),
              Text('·', style: const TextStyle(color: AppTheme.textHint)),
              const SizedBox(width: 8),
              Text('${fmt.format(spent)} spent', style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),

          // Budget usage bar
          Row(
            children: [
              const Text('Budget  ', style: TextStyle(color: AppTheme.textHint, fontSize: 10)),
              Expanded(child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: budgetProgress, minHeight: 4,
                  backgroundColor: AppTheme.glassBorderColor,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    budgetPct > 80 ? AppTheme.errorColor : color),
                ),
              )),
              const SizedBox(width: 8),
              Text('$budgetPct%', style: TextStyle(
                color: budgetPct > monthPct ? color : AppTheme.textHint, fontSize: 10, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),

          // Pace bar
          Row(
            children: [
              const Text('Pace    ', style: TextStyle(color: AppTheme.textHint, fontSize: 10)),
              Expanded(child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: paceProgress, minHeight: 4,
                  backgroundColor: AppTheme.glassBorderColor,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor.withValues(alpha: 0.4)),
                ),
              )),
              const SizedBox(width: 8),
              Text('$monthPct%', style: const TextStyle(
                color: AppTheme.textHint, fontSize: 10, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),

          // Stats row
          Row(
            children: [
              _MiniStat(label: 'Avg/day', value: fmt.format(weightedAvg)),
              const SizedBox(width: 14),
              if (daysRemaining != null)
                _MiniStat(label: 'Runs out', value: runOutDate ?? '~$daysRemaining days',
                  color: status != 'ok' ? color : null),
              if (daysRemaining == null)
                const _MiniStat(label: 'Runs out', value: 'No data'),
              if (momPct != null) ...[
                const SizedBox(width: 14),
                _MiniStat(
                  label: 'vs last mo',
                  value: '${momPct > 0 ? '+' : ''}$momPct%',
                  color: momPct > 15 ? AppTheme.errorColor : momPct < -10 ? AppTheme.successColor : null,
                ),
              ],
            ],
          ),

          // Burst warning
          if (burstCount > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.flash_on_rounded, size: 12, color: const Color(0xFFF59E0B).withValues(alpha: 0.7)),
                const SizedBox(width: 4),
                Text('$burstCount one-off spike${burstCount > 1 ? 's' : ''} (${fmt.format(burstTotal)}) excluded from avg',
                  style: const TextStyle(color: AppTheme.textHint, fontSize: 10)),
              ],
            ),
          ],

          // Target daily spend
          if (needsReduction) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline_rounded, size: 14, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    'To last the month: spend ≤ ${fmt.format(targetDaily)}/day',
                    style: const TextStyle(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.w600),
                  )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _MiniStat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textHint, fontSize: 9, letterSpacing: 0.3)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(
          color: color ?? AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
