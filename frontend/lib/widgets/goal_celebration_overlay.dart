// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : goal_celebration_overlay.dart
// Description   : Full-screen goal completion celebration overlay.
//                 Shows goal name/amount, freed-up allocation chip, and a
//                 "Chat with Aion" button. Small Lottie animation in corner.
// First Written : 19-06-2026
// Edited on     : 19-06-2026
// ============================================

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../config/app_theme.dart';

class GoalCelebrationOverlay extends StatefulWidget {
  final String vaultName;
  final double goalTargetAmount;
  final int allocationPercentage;
  final VoidCallback onDismiss;
  final VoidCallback onChat;

  const GoalCelebrationOverlay({
    super.key,
    required this.vaultName,
    required this.goalTargetAmount,
    required this.allocationPercentage,
    required this.onDismiss,
    required this.onChat,
  });

  static Future<bool> show(
    BuildContext context, {
    required String vaultName,
    required double goalTargetAmount,
    required int allocationPercentage,
  }) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (_) => GoalCelebrationOverlay(
        vaultName: vaultName,
        goalTargetAmount: goalTargetAmount,
        allocationPercentage: allocationPercentage,
        onDismiss: () => navigator.pop(false),
        onChat: () => navigator.pop(true),
      ),
    );
    return result ?? false;
  }

  @override
  State<GoalCelebrationOverlay> createState() => _GoalCelebrationOverlayState();
}

class _GoalCelebrationOverlayState extends State<GoalCelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnim = CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut);
    _fadeAnim = CurvedAnimation(parent: _scaleController, curve: Curves.easeIn);

    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _scaleController.forward();
    });
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: FadeTransition(
        opacity: _fadeAnim,
        child: ScaleTransition(
          scale: _scaleAnim,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1600),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                  blurRadius: 40,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // ── Main card content ──────────────────────────
                ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Trophy icon
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppTheme.goldGradient,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withValues(alpha: 0.5),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.emoji_events_rounded,
                            color: Color(0xFF0A0800),
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Goal achieved badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppTheme.primaryColor.withValues(alpha: 0.35),
                            ),
                          ),
                          child: const Text(
                            'GOAL ACHIEVED',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.8,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Vault name
                        Text(
                          widget.vaultName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.5,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Amount saved
                        Text(
                          'RM ${widget.goalTargetAmount.toStringAsFixed(2)} saved!',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Freed-up allocation chip
                        if (widget.allocationPercentage > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E2A1A),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppTheme.successColor.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.trending_up_rounded,
                                    size: 14, color: AppTheme.successColor),
                                const SizedBox(width: 6),
                                Text(
                                  '${widget.allocationPercentage}% of income now freed up',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.successColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 10),

                        // Subtitle
                        const Text(
                          'Aion wants to discuss what to do with\nyour freed-up allocation — chat now.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Chat with Aion button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: widget.onChat,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: const Color(0xFF0A0800),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.auto_awesome_rounded, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Chat with Aion',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Maybe later
                        TextButton(
                          onPressed: widget.onDismiss,
                          child: const Text(
                            'Maybe later',
                            style: TextStyle(fontSize: 13, color: AppTheme.textHint),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Small animation — top-right corner ─────────
                Positioned(
                  top: -14,
                  right: -14,
                  child: IgnorePointer(
                    child: SizedBox(
                      width: 80,
                      height: 80,
                      child: Lottie.asset(
                        'assets/animations/confetti.json',
                        fit: BoxFit.contain,
                        repeat: true,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
