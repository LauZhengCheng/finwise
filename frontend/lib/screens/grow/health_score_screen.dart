// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : health_score_screen.dart
// Description   : Financial Health Score — FHN FinHealth Score with
//                 animated radial donut gauge, 4 expandable dimension
//                 cards with Aion per-dimension advice, overall Aion advice.
// First Written : 25-06-2026
// Edited on     : 25-06-2026
// ============================================

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../services/api/finance_api.dart';
import '../../widgets/shimmer_loading.dart';

class HealthScoreScreen extends StatefulWidget {
  const HealthScoreScreen({super.key});

  @override
  State<HealthScoreScreen> createState() => _HealthScoreScreenState();
}

class _HealthScoreScreenState extends State<HealthScoreScreen> with SingleTickerProviderStateMixin {
  final _api = FinanceApi();
  bool _loading = true;
  Map<String, dynamic>? _data;
  final Set<String> _expanded = {};

  late AnimationController _animCtrl;
  late Animation<double> _scoreAnim;

  static const _vulnerableColor = Color(0xFFE85D3A);
  static const _copingColor = Color(0xFF7B5EA7);
  static const _healthyColor = Color(0xFF3B82C4);

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _scoreAnim = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _load();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final result = await _api.getHealthScore();
      if (mounted) {
        final data = result['data'] as Map<String, dynamic>?;
        final score = (data?['score'] as num?)?.toInt() ?? 0;
        setState(() {
          _data = data;
          _loading = false;
          _scoreAnim = Tween<double>(begin: 0, end: score.toDouble()).animate(
            CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
        });
        _animCtrl.forward();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _tierColor(int score) {
    if (score <= 39) return _vulnerableColor;
    if (score <= 79) return _copingColor;
    return _healthyColor;
  }

  static const _dimLabels = {'spend': 'Spend', 'save': 'Save', 'borrow': 'Borrow', 'plan': 'Plan'};
  static const _dimIcons = {
    'spend': Icons.shopping_cart_rounded,
    'save': Icons.savings_rounded,
    'borrow': Icons.account_balance_rounded,
    'plan': Icons.flag_rounded,
  };
  static const _adviceKeys = {
    'spend': 'spend_advice', 'save': 'save_advice',
    'borrow': 'borrow_advice', 'plan': 'plan_advice',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(children: [
                GestureDetector(
                  onTap: () => context.pop(),
                  child: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary, size: 24)),
                const SizedBox(width: 16),
                const Text('Financial Health', style: TextStyle(
                  color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w700)),
              ]),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                ? const Padding(padding: EdgeInsets.all(20), child: SkeletonTransactionList(count: 4))
                : _data == null
                  ? const Center(child: Text('Unable to calculate health score',
                      style: TextStyle(color: AppTheme.textHint, fontSize: 14)))
                  : _buildContent(),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final tier = _data!['tier'] as String? ?? 'Unknown';
    final dimensions = _data!['dimensions'] as Map<String, dynamic>? ?? {};
    final advice = _data!['aion_advice'] as Map<String, dynamic>?;
    final overallAdvice = advice?['overall'] as String?;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(children: [
        // ── Animated Radial Gauge ──
        AnimatedBuilder(
          animation: _scoreAnim,
          builder: (context, _) {
            final animScore = _scoreAnim.value.round();
            final color = _tierColor(animScore);
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Color(0xFF1E1A14), Color(0xFF0F0D09)]),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Column(children: [
                const Text('Financial Health Score', style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13)),
                const SizedBox(height: 4),
                Text('FHN FinHealth Score', style: TextStyle(
                  color: AppTheme.textHint.withValues(alpha: 0.5), fontSize: 10)),
                const SizedBox(height: 20),
                SizedBox(
                  width: 180, height: 180,
                  child: CustomPaint(
                    painter: _GaugePainter(score: animScore),
                    child: Center(child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$animScore', style: TextStyle(
                          color: color, fontSize: 48, fontWeight: FontWeight.w800)),
                        Text('out of 100', style: TextStyle(
                          color: AppTheme.textHint.withValues(alpha: 0.5), fontSize: 11)),
                      ],
                    )),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20)),
                  child: Text(tier, style: TextStyle(
                    color: color, fontSize: 14, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 16),
                _buildTierScale(animScore),
              ]),
            );
          },
        ),
        const SizedBox(height: 16),

        // ── Aion's Overall Advice ──
        if (overallAdvice != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.15))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.auto_awesome_rounded, size: 14,
                    color: AppTheme.primaryColor.withValues(alpha: 0.7)),
                  const SizedBox(width: 6),
                  Text("Aion's Advice", style: TextStyle(
                    color: AppTheme.primaryColor.withValues(alpha: 0.7),
                    fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 8),
                Text(overallAdvice, style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13, height: 1.5)),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── 4 Dimension Cards ──
        ...['spend', 'save', 'borrow', 'plan'].map((key) =>
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildDimensionCard(key, dimensions, advice),
          ),
        ),
      ]),
    );
  }

  Widget _buildTierScale(int score) {
    return Column(children: [
      LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth;
        final pos = (score / 100).clamp(0.0, 1.0) * width;
        return Stack(clipBehavior: Clip.none, children: [
          Row(children: [
            Expanded(flex: 40, child: Container(height: 6,
              decoration: const BoxDecoration(
                color: _vulnerableColor,
                borderRadius: BorderRadius.horizontal(left: Radius.circular(3))))),
            Expanded(flex: 40, child: Container(height: 6, color: _copingColor)),
            Expanded(flex: 20, child: Container(height: 6,
              decoration: const BoxDecoration(
                color: _healthyColor,
                borderRadius: BorderRadius.horizontal(right: Radius.circular(3))))),
          ]),
          Positioned(
            left: pos - 5, top: -4,
            child: Container(width: 14, height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle, color: Colors.white,
                border: Border.all(color: _tierColor(score), width: 2.5),
                boxShadow: [BoxShadow(color: _tierColor(score).withValues(alpha: 0.4), blurRadius: 6)]))),
        ]);
      }),
      const SizedBox(height: 6),
      Row(children: [
        Text('Vulnerable', style: TextStyle(color: _vulnerableColor.withValues(alpha: 0.6), fontSize: 9)),
        const Spacer(),
        Text('Coping', style: TextStyle(color: _copingColor.withValues(alpha: 0.6), fontSize: 9)),
        const Spacer(),
        Text('Healthy', style: TextStyle(color: _healthyColor.withValues(alpha: 0.6), fontSize: 9)),
      ]),
    ]);
  }

  Widget _buildDimensionCard(String key, Map<String, dynamic> dimensions, Map<String, dynamic>? advice) {
    final dim = dimensions[key] as Map<String, dynamic>? ?? {};
    final dimScore = (dim['score'] as num?)?.toInt() ?? 0;
    final indicators = (dim['indicators'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final isExpanded = _expanded.contains(key);
    final color = _tierColor(dimScore);
    final adviceText = advice?[_adviceKeys[key]] as String?;

    return GestureDetector(
      onTap: () => setState(() {
        if (isExpanded) { _expanded.remove(key); } else { _expanded.add(key); }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isExpanded ? color.withValues(alpha: 0.3) : AppTheme.glassBorderColor)),
        child: Column(children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10)),
              child: Icon(_dimIcons[key] ?? Icons.help, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(_dimLabels[key] ?? key, style: const TextStyle(
              color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600))),
            Text('$dimScore', style: TextStyle(
              color: color, fontSize: 20, fontWeight: FontWeight.w800)),
            Text('/100', style: TextStyle(
              color: AppTheme.textHint.withValues(alpha: 0.5), fontSize: 11)),
            const SizedBox(width: 8),
            AnimatedRotation(
              turns: isExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textHint, size: 20)),
          ]),
          if (isExpanded) ...[
            const SizedBox(height: 14),
            const Divider(color: AppTheme.glassBorderColor, height: 1),
            const SizedBox(height: 14),
            ...indicators.map((ind) {
              final indScore = (ind['score'] as num?)?.toInt() ?? 0;
              final indColor = _tierColor(indScore);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  Expanded(child: Text(ind['name'] as String? ?? '',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
                  const SizedBox(width: 8),
                  SizedBox(width: 80, height: 6,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: indScore / 100,
                        backgroundColor: AppTheme.surfaceColor,
                        color: indColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(width: 28, child: Text('$indScore',
                    textAlign: TextAlign.right,
                    style: TextStyle(color: indColor, fontSize: 13, fontWeight: FontWeight.w700))),
                ]),
              );
            }),
            // Aion's per-dimension advice
            if (adviceText != null) ...[
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.1))),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 12,
                      color: AppTheme.primaryColor.withValues(alpha: 0.6)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(adviceText, style: TextStyle(
                      color: AppTheme.primaryColor.withValues(alpha: 0.8),
                      fontSize: 11, height: 1.4))),
                  ],
                ),
              ),
            ],
          ],
        ]),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final int score;
  _GaugePainter({required this.score});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    const startAngle = 2.3;
    const sweepTotal = 2 * math.pi - 0.6;

    final bgPaint = Paint()
      ..style = PaintingStyle.stroke..strokeWidth = 14
      ..color = const Color(0xFF1A1610)..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
      startAngle, sweepTotal, false, bgPaint);

    const vulnSweep = sweepTotal * 0.4;
    const copingSweep = sweepTotal * 0.4;
    const healthySweep = sweepTotal * 0.2;

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
      startAngle, vulnSweep, false,
      Paint()..style = PaintingStyle.stroke..strokeWidth = 14
        ..color = const Color(0xFFE85D3A)..strokeCap = StrokeCap.round);

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
      startAngle + vulnSweep, copingSweep, false,
      Paint()..style = PaintingStyle.stroke..strokeWidth = 14
        ..color = const Color(0xFF7B5EA7));

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
      startAngle + vulnSweep + copingSweep, healthySweep, false,
      Paint()..style = PaintingStyle.stroke..strokeWidth = 14
        ..color = const Color(0xFF3B82C4)..strokeCap = StrokeCap.round);

    final scoreAngle = startAngle + sweepTotal * (score / 100).clamp(0.0, 1.0);
    final dotCenter = Offset(
      center.dx + radius * math.cos(scoreAngle),
      center.dy + radius * math.sin(scoreAngle));
    canvas.drawCircle(dotCenter, 9, Paint()..color = Colors.white);
    Color dotColor;
    if (score <= 39) { dotColor = const Color(0xFFE85D3A); }
    else if (score <= 79) { dotColor = const Color(0xFF7B5EA7); }
    else { dotColor = const Color(0xFF3B82C4); }
    canvas.drawCircle(dotCenter, 6, Paint()..color = dotColor);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) => old.score != score;
}
