// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : vault_card.dart
// Description   : Spending vault row widget — compact row used inside
//                 the MY VAULTS container on the dashboard.
//                 No individual card container — parent provides the surface.
// First Written : 06-06-2026
// Edited on     : 18-06-2026
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
    final progress = vault.allocatedAmount > 0
        ? (vault.spentAmount / vault.allocatedAmount).clamp(0.0, 1.0)
        : 0.0;
    final isOverBudget = vault.spentAmount > vault.allocatedAmount;
    final isFull = !isOverBudget && progress >= 1.0;
    final isLow  = !isOverBudget && !isFull && progress >= 0.8;

    final barColor = isOverBudget
        ? AppTheme.errorColor
        : (isFull || isLow)
            ? Colors.orange
            : _colour;

    final budgetLabel = isOverBudget
        ? 'Over original budget by RM ${(vault.spentAmount - vault.allocatedAmount).toStringAsFixed(2)}'
        : isFull
            ? 'Original budget fully used'
            : '${(progress * 100).toInt()}% of original budget used';

    final budgetLabelColor = isOverBudget
        ? AppTheme.errorColor
        : (isFull || isLow)
            ? Colors.orange
            : AppTheme.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: name + balance ──────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
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

              // Balance — always current_balance, never negative
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'RM ${vault.currentBalance.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: vault.currentBalance == 0
                          ? AppTheme.errorColor
                          : AppTheme.textPrimary,
                    ),
                  ),
                  const Text(
                    'Balance',
                    style: TextStyle(
                      fontSize: 9,
                      color: AppTheme.textHint,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ── Progress bar ─────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: barColor.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
              minHeight: 4,
            ),
          ),

          const SizedBox(height: 5),

          // ── Bottom row: spent label + budget status ───
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left: "Spent  RM X.XX"
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Spent  ',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textHint,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        'RM ${vault.spentAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Right: budget status
              Flexible(
                child: Text(
                  budgetLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isOverBudget ? FontWeight.w600 : FontWeight.w500,
                    color: budgetLabelColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
