// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : goal_guardian_popup.dart
// Description   : Goal Guardian advisory popup — shows Aria's alert
//                 message with Proceed or Cancel options
// First Written : 06-06-2026
// Edited on     : 06-06-2026
// ============================================

import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';

class GoalGuardianPopup extends StatelessWidget {
  final Map<String, dynamic> result;
  final VoidCallback onProceed;
  final VoidCallback onCancel;

  const GoalGuardianPopup({
    super.key,
    required this.result,
    required this.onProceed,
    required this.onCancel,
  });

  String get _alertMessage =>
      result['alert_message'] as String? ?? 'Aria has flagged this transaction.';

  String get _severity =>
      result['alert_severity'] as String? ?? 'medium';

  Color get _severityColor {
    switch (_severity) {
      case 'high':
        return AppTheme.errorColor;
      case 'medium':
        return const Color(0xFFF59E0B);
      default:
        return AppTheme.primaryColor;
    }
  }

  IconData get _severityIcon {
    switch (_severity) {
      case 'high':
        return Icons.warning_rounded;
      case 'medium':
        return Icons.info_rounded;
      default:
        return Icons.lightbulb_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.textSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _severityColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(_severityIcon, color: _severityColor, size: 32),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            _severity == 'high'
                ? 'Aria has a concern'
                : 'Heads up from Aria',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          // Aria's message bubble
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.15)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor:
                      AppTheme.primaryColor.withValues(alpha: 0.15),
                  child: const Text(
                    'A',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _alertMessage,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: const BorderSide(color: AppTheme.glassBorderColor),
                    minimumSize: const Size(0, 52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Cancel',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onProceed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _severityColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Proceed Anyway',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
