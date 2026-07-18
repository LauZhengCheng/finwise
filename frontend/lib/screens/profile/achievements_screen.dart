// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : achievements_screen.dart
// Description   : Achievements — completed saving goals with
//                 celebratory gamification UI. Archive/unarchive.
// First Written : 17-06-2026
// Edited on     : 21-06-2026
// ============================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../config/app_theme.dart';
import '../../models/vault_model.dart';
import '../../providers/vault_provider.dart';

class AchievementsScreen extends ConsumerStatefulWidget {
  const AchievementsScreen({super.key});

  @override
  ConsumerState<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends ConsumerState<AchievementsScreen> {
  final _fmt = NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ', decimalDigits: 2);
  final _dateFmt = DateFormat('d MMM yyyy');

  @override
  Widget build(BuildContext context) {
    final completedGoals = ref.watch(vaultProvider).completedGoals
        .where((g) => g.isArchived).toList()
      ..sort((a, b) => (b.completedAt ?? DateTime(2000)).compareTo(a.completedAt ?? DateTime(2000)));

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
                      onTap: () => Navigator.of(context).pop(),
                      child: const Icon(Icons.arrow_back_rounded,
                          color: AppTheme.textPrimary, size: 24),
                    ),
                    const SizedBox(width: 16),
                    const Text('Achievements', style: TextStyle(
                      color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: completedGoals.isEmpty
                    ? _buildEmpty()
                    : _buildContent(completedGoals),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
            ),
            child: Icon(Icons.emoji_events_outlined,
              size: 36, color: AppTheme.primaryColor.withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 20),
          const Text('No goals completed yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          const Text('Keep saving — completed goals\nwill appear here!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildContent(List<VaultModel> goals) {
    final totalSaved = goals.fold<double>(0, (sum, g) => sum + (g.goalTargetAmount ?? 0));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 108),
      child: Column(
        children: [
          // Trophy summary
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2A2210), Color(0xFF1A1600)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  blurRadius: 20, spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 64, height: 64,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.goldGradient,
                  ),
                  child: const Icon(Icons.emoji_events_rounded,
                    color: Color(0xFF0A0800), size: 32),
                ),
                const SizedBox(height: 16),
                Text(
                  '${goals.length} Goal${goals.length > 1 ? 's' : ''} Achieved!',
                  style: const TextStyle(
                    color: AppTheme.primaryColor, fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_fmt.format(totalSaved)} total saved',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Every goal achieved is a step toward financial freedom',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textHint, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Roadmap timeline
          ...goals.asMap().entries.map((entry) {
            final i = entry.key;
            final fund = entry.value;
            final isLast = i == goals.length - 1;
            return _RoadmapNode(
              fund: fund,
              index: i,
              isLast: isLast,
              fmt: _fmt,
              dateFmt: _dateFmt,
            );
          }),
        ],
      ),
    );
  }
}

class _RoadmapNode extends StatelessWidget {
  final VaultModel fund;
  final int index;
  final bool isLast;
  final NumberFormat fmt;
  final DateFormat dateFmt;

  const _RoadmapNode({
    required this.fund, required this.index, required this.isLast,
    required this.fmt, required this.dateFmt,
  });

  Color get _colour {
    try {
      return Color(int.parse('FF${fund.vaultColour.replaceFirst('#', '')}', radix: 16));
    } catch (_) {
      return AppTheme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = fund.completedAt != null
        ? dateFmt.format(fund.completedAt!.toLocal())
        : '';
    final color = _colour;
    final isFirst = index == 0;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Roadmap path
          SizedBox(
            width: 40,
            child: Column(
              children: [
                // Node circle
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isFirst ? AppTheme.goldGradient : null,
                    color: isFirst ? null : color.withValues(alpha: 0.3),
                    border: isFirst ? null : Border.all(color: color.withValues(alpha: 0.5), width: 2),
                    boxShadow: isFirst ? [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.4),
                        blurRadius: 8, spreadRadius: 1,
                      ),
                    ] : null,
                  ),
                  child: Center(
                    child: isFirst
                        ? const Icon(Icons.star_rounded, color: Color(0xFF0A0800), size: 16)
                        : const Text('🏆', style: TextStyle(fontSize: 12)),
                  ),
                ),
                // Connecting path
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 3,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            color.withValues(alpha: 0.5),
                            (index + 1 < 10 ? AppTheme.primaryColor : AppTheme.glassBorderColor).withValues(alpha: 0.3),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Goal card
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: isFirst ? 0.2 : 0.1),
                    AppTheme.cardColor,
                  ],
                ),
                border: Border.all(
                  color: isFirst
                      ? AppTheme.primaryColor.withValues(alpha: 0.4)
                      : color.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.successColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(dateStr, style: const TextStyle(
                          color: AppTheme.successColor, fontSize: 10, fontWeight: FontWeight.w700)),
                      ),
                      const Spacer(),
                      if (isFirst)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: AppTheme.goldGradient,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('LATEST', style: TextStyle(
                            color: Color(0xFF0A0800), fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Goal name
                  Text(fund.name, style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                  if (fund.linkedGoal != null) ...[
                    const SizedBox(height: 2),
                    Text(fund.linkedGoal!, style: const TextStyle(
                      color: AppTheme.textHint, fontSize: 11)),
                  ],
                  const SizedBox(height: 10),

                  // Amount
                  Text(fmt.format(fund.goalTargetAmount ?? 0), style: TextStyle(
                    color: color, fontSize: 20, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
