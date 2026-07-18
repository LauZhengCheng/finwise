// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : spending_chart.dart
// Description   : Spending summary card with donut chart.
//                 Donut slices = each spending vault's actual spent amount.
//                 Shows real-time spending breakdown by category.
// First Written : 06-06-2026
// Edited on     : 10-06-2026
// ============================================

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../models/vault_model.dart';

class SpendingChartCard extends StatelessWidget {
  final List<VaultModel> vaults;
  final VoidCallback? onViewAll;

  const SpendingChartCard({super.key, required this.vaults, this.onViewAll});

  List<VaultModel> get _spendingVaults =>
      vaults.where((v) => v.vaultType == 'vault').toList();

  Color _hexColor(String hex) {
    try {
      final clean = hex.replaceFirst('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return AppTheme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final spending = _spendingVaults;

    return Container(
      padding: const EdgeInsets.all(20),
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
          // Section label + View All button
          Row(
            children: [
              const Expanded(
                child: Text(
                  'SPENDING SUMMARY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              if (onViewAll != null)
                TextButton.icon(
                  onPressed: onViewAll,
                  icon: const Icon(Icons.receipt_long_rounded, size: 12),
                  label: const Text('View All'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textHint,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 20),

          spending.isEmpty ? _buildEmptyState() : _buildChart(spending),
        ],
      ),
    );
  }

  Widget _buildChart(List<VaultModel> spending) {
    final totalSpent = spending.fold<double>(0, (s, v) => s + v.spentAmount);

    return Row(
      children: [
        // Donut chart
        SizedBox(
          width: 140,
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sections: spending.map((v) {
                    return PieChartSectionData(
                      value: v.spentAmount > 0 ? v.spentAmount : 0.01,
                      color: _hexColor(v.vaultColour),
                      radius: 42,
                      title: '',
                      showTitle: false,
                    );
                  }).toList(),
                  centerSpaceRadius: 38,
                  sectionsSpace: 3,
                  startDegreeOffset: -90,
                  pieTouchData: PieTouchData(enabled: false),
                ),
                swapAnimationDuration: const Duration(milliseconds: 600),
              ),
              // Centre label
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    totalSpent > 0 ? 'RM ${totalSpent.toStringAsFixed(0)}' : 'RM 0',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                      height: 1.0,
                    ),
                  ),
                  const Text(
                    'spent',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.textHint,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(width: 20),

        // Legend
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: spending.map((v) {
              final colour = _hexColor(v.vaultColour);
              final pct = totalSpent > 0 ? (v.spentAmount / totalSpent * 100).round() : 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: colour.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$pct%',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: colour),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        v.name,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      'RM ${v.spentAmount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colour,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text(
          'Complete onboarding to see your spending breakdown',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
      ),
    );
  }
}
