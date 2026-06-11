// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : vault_card.dart
// Description   : Spending vault row widget — compact row used inside
//                 the MY VAULTS container on the dashboard.
//                 No individual card container — parent provides the surface.
// First Written : 06-06-2026
// Edited on     : 10-06-2026
// ============================================

import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../models/vault_model.dart';

class VaultCard extends StatelessWidget {
  final VaultModel vault;

  const VaultCard({super.key, required this.vault});

  Color get _colour {
    try {
      final hex = vault.vaultColour.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return AppTheme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining =
        (vault.allocatedAmount - vault.spentAmount).clamp(0.0, double.infinity);
    final progress = vault.allocatedAmount > 0
        ? (vault.spentAmount / vault.allocatedAmount).clamp(0.0, 1.0)
        : 0.0;
    final isOverBudget = vault.spentAmount > vault.allocatedAmount;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Colour dot
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _colour,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),

              // Vault name
              Expanded(
                child: Text(
                  vault.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Remaining amount
              Text(
                isOverBudget
                    ? '−RM ${(vault.spentAmount - vault.allocatedAmount).toStringAsFixed(2)}'
                    : 'RM ${remaining.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isOverBudget ? AppTheme.errorColor : AppTheme.textPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Progress bar + labels
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: _colour.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(
                isOverBudget ? AppTheme.errorColor : _colour,
              ),
              minHeight: 4,
            ),
          ),

          const SizedBox(height: 5),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'RM ${vault.spentAmount.toStringAsFixed(2)} spent',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textHint,
                ),
              ),
              Text(
                isOverBudget
                    ? 'Over budget'
                    : '${(progress * 100).toInt()}% used',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isOverBudget ? AppTheme.errorColor : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
