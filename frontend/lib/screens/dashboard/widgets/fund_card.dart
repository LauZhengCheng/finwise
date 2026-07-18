// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : fund_card.dart
// Description   : Saving fund card — full-width card used inside a
//                 PageView on the dashboard. Shows saved vs goal with
//                 a gold progress bar and completion state.
// First Written : 06-06-2026
// Edited on     : 10-06-2026
// ============================================

import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../models/vault_model.dart';

class FundCard extends StatelessWidget {
  final VaultModel fund;
  final bool isArchiving;
  final VoidCallback? onArchive;

  const FundCard({super.key, required this.fund, this.isArchiving = false, this.onArchive});

  Color get _colour {
    try {
      final hex = fund.vaultColour.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return AppTheme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = fund.goalTargetAmount ?? 0.0;
    final saved = fund.currentBalance;
    final progress = target > 0 ? (saved / target).clamp(0.0, 1.0) : 0.0;
    final remaining = (target - saved).clamp(0.0, double.infinity);
    final isComplete = saved >= target && target > 0;
    final progressColor = isComplete ? AppTheme.primaryColor : _colour;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
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
          // Top row: fund name + FUND tag
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  fund.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isComplete ? 'COMPLETE' : 'GOAL',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: isComplete
                        ? AppTheme.primaryColor
                        : AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Saved amount (large) + goal label
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'RM ${saved.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: progressColor,
                  letterSpacing: -0.8,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  target > 0 ? '/ RM ${target.toStringAsFixed(2)}' : 'saved',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: progressColor.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              minHeight: 5,
            ),
          ),

          const SizedBox(height: 8),

          // Progress label + inline Archive button on the same row
          Row(
            children: [
              Expanded(
                child: Text(
                  target > 0
                      ? isComplete
                          ? 'Goal reached!'
                          : '${(progress * 100).toInt()}% · RM ${remaining.toStringAsFixed(2)} to go'
                      : 'No goal target set',
                  style: TextStyle(
                    fontSize: 12,
                    color: isComplete ? AppTheme.primaryColor : AppTheme.textHint,
                    fontWeight: isComplete ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (isComplete && onArchive != null)
                isArchiving
                  ? const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.textHint)))
                  : TextButton.icon(
                      onPressed: onArchive,
                      icon: const Icon(Icons.archive_outlined, size: 12),
                      label: const Text('Archive'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.textHint,
                        padding: const EdgeInsets.only(left: 8),
                        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        minimumSize: Size.zero,
                      ),
                    ),
            ],
          ),
        ],
      ),
    );
  }
}
