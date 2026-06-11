// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : spending_chart.dart
// Description   : Spending summary card with donut chart.
//                 Donut slices = each spending vault's allocation %.
//                 Total Safe-to-Spend number is shown as the dashboard
//                 hero above — this card shows the breakdown only.
// First Written : 06-06-2026
// Edited on     : 10-06-2026
// ============================================

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../models/vault_model.dart';

class SpendingChartCard extends StatelessWidget {
  final List<VaultModel> vaults;

  const SpendingChartCard({super.key, required this.vaults});

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
          // Section label
          const Text(
            'SPENDING SUMMARY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: AppTheme.textSecondary,
            ),
          ),

          const SizedBox(height: 20),

          spending.isEmpty ? _buildEmptyState() : _buildChart(spending),
        ],
      ),
    );
  }

  Widget _buildChart(List<VaultModel> spending) {
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
                      value: v.allocationPercentage.toDouble(),
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
                    '${spending.length}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                      height: 1.0,
                    ),
                  ),
                  const Text(
                    'vaults',
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
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: colour,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        v.name,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${v.allocationPercentage}%',
                      style: TextStyle(
                        fontSize: 12,
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
