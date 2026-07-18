// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : grow_screen.dart
// Description   : Grow hub tab — Financial Health Score link at top,
//                 2x2 grid: Debt, Investment, Protection, Bills.
// First Written : 17-06-2026
// Edited on     : 26-06-2026
// ============================================

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../services/api/finance_api.dart';
import '../main_scaffold.dart';

class GrowScreen extends ConsumerStatefulWidget {
  const GrowScreen({super.key});

  @override
  ConsumerState<GrowScreen> createState() => _GrowScreenState();
}

class _GrowScreenState extends ConsumerState<GrowScreen> with SingleTickerProviderStateMixin {
  Map<String, int> _dimScores = {};
  bool _healthLoading = true;

  late AnimationController _animCtrl;
  late Animation<double> _scoreAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _scoreAnim = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _loadStats();
    growTabRefresh.addListener(_onRefresh);
  }

  void _onRefresh() {
    _animCtrl.reset();
    setState(() => _healthLoading = true);
    _loadStats();
  }

  Future<void> _loadStats() async {
    final api = FinanceApi();
    try {
      final result = await api.getHealthScore();
      final healthData = result['data'] as Map<String, dynamic>?;

      if (mounted) {
        final dims = healthData?['dimensions'] as Map<String, dynamic>? ?? {};
        final score = (healthData?['score'] as num?)?.toInt() ?? 0;
        setState(() {
          _healthLoading = false;
          _dimScores = {
            'Spend': (dims['spend'] as Map<String, dynamic>?)?['score'] as int? ?? 0,
            'Save': (dims['save'] as Map<String, dynamic>?)?['score'] as int? ?? 0,
            'Borrow': (dims['borrow'] as Map<String, dynamic>?)?['score'] as int? ?? 0,
            'Plan': (dims['plan'] as Map<String, dynamic>?)?['score'] as int? ?? 0,
          };
          _scoreAnim = Tween<double>(begin: 0, end: score.toDouble()).animate(
            CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
        });
        _animCtrl.forward();
      }
    } catch (_) {
      if (mounted) setState(() => _healthLoading = false);
    }
  }

  @override
  void dispose() {
    growTabRefresh.removeListener(_onRefresh);
    _animCtrl.dispose();
    super.dispose();
  }

  Widget _staggered(int index, int total, Widget child) => child;

  Color _tierColor(int score) {
    if (score <= 39) return const Color(0xFFE85D3A);
    if (score <= 79) return const Color(0xFF7B5EA7);
    return const Color(0xFF3B82C4);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Grow', style: TextStyle(
                  color: AppTheme.textPrimary, fontSize: 28, fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),

                // ── Financial Health Score card (glowing) ──
                _staggered(0, 3, _healthLoading
                  ? const _PulsingGlowCard()
                  : GestureDetector(
                  onTap: () => context.push('/grow/health-score').then((_) { if (mounted) _onRefresh(); }),
                  child: Container(
                    width: double.infinity,
                    height: 200,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [Color(0xFF1E1A14), Color(0xFF0F0D09)]),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.25)),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.12),
                          blurRadius: 24, spreadRadius: 2),
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.06),
                          blurRadius: 40, spreadRadius: 8),
                      ],
                    ),
                    child: Column(children: [
                      Row(children: [
                        const Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('FINANCIAL HEALTH SCORE', style: TextStyle(
                              color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w800,
                              letterSpacing: 0.5)),
                            SizedBox(height: 2),
                            Text('FHN FinHealth Score', style: TextStyle(
                              color: AppTheme.textHint, fontSize: 11)),
                          ],
                        )),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.glassBorderColor)),
                          child: const Text('Details  ›', style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Mini FHN gauge (animated)
                          AnimatedBuilder(
                            animation: _scoreAnim,
                            builder: (_, __) {
                              final animScore = _scoreAnim.value.round();
                              return SizedBox(
                                width: 90, height: 90,
                                child: CustomPaint(
                                  painter: _MiniGaugePainter(score: animScore),
                                  child: Center(child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('$animScore',
                                        style: TextStyle(
                                          color: _tierColor(animScore),
                                          fontSize: 26, fontWeight: FontWeight.w800)),
                                      Text('/ 100', style: TextStyle(
                                        color: AppTheme.textHint.withValues(alpha: 0.4),
                                        fontSize: 9)),
                                    ],
                                  )),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 16),
                          // Dimension bars (FHN colors)
                          Expanded(child: Column(children: [
                            ..._dimScores.entries.map((e) {
                              final score = e.value;
                              final color = _tierColor(score);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(children: [
                                  SizedBox(width: 50, child: Text(e.key, style: const TextStyle(
                                    color: AppTheme.textSecondary, fontSize: 12))),
                                  Expanded(child: ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: SizedBox(height: 6, child: LinearProgressIndicator(
                                      value: score / 100,
                                      backgroundColor: const Color(0xFF1A1610),
                                      color: color)),
                                  )),
                                  const SizedBox(width: 8),
                                  SizedBox(width: 24, child: Text('$score',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700))),
                                ]),
                              );
                            }),
                          ])),
                        ],
                      ),
                    ]),
                  ),
                )),
                const SizedBox(height: 20),

                // ── 2x2 Grid ──
                _staggered(1, 3, Row(children: [
                  Expanded(child: _GridCard(
                    icon: Icons.credit_card_rounded,
                    iconColor: AppTheme.errorColor,
                    title: 'Debt\nManagement',
                    subtitle: 'Track loans & payoff\nstrategy',
                    onTap: () => context.push('/grow/debt').then((_) { if (mounted) _onRefresh(); }),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _GridCard(
                    icon: Icons.show_chart_rounded,
                    iconColor: AppTheme.successColor,
                    title: 'Investment\nPortfolio',
                    subtitle: 'Stocks, crypto & unit\ntrusts',
                    onTap: () => context.push('/grow/invest').then((_) { if (mounted) _onRefresh(); }),
                  )),
                ])),
                const SizedBox(height: 12),
                _staggered(2, 3, Row(children: [
                  Expanded(child: _GridCard(
                    icon: Icons.shield_rounded,
                    iconColor: const Color(0xFF5090E0),
                    title: 'Protection\nPlanning',
                    subtitle: 'Emergency fund &\ninsurance',
                    onTap: () => context.push('/grow/protection').then((_) { if (mounted) _onRefresh(); }),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _GridCard(
                    icon: Icons.notifications_rounded,
                    iconColor: AppTheme.primaryColor,
                    title: 'Bill\nReminders',
                    subtitle: 'Upcoming bills &\npayments',
                    onTap: () => context.push('/bills').then((_) { if (mounted) _onRefresh(); }),
                  )),
                ])),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GridCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _GridCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.glassBorderColor)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(
              color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700, height: 1.3)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(
              color: AppTheme.textSecondary, fontSize: 11, height: 1.3)),
          ],
        ),
      ),
    );
  }
}

class _MiniGaugePainter extends CustomPainter {
  final int score;
  _MiniGaugePainter({required this.score});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const startAngle = 2.3;
    const sweepTotal = 2 * math.pi - 0.6;

    final bgPaint = Paint()
      ..style = PaintingStyle.stroke..strokeWidth = 8
      ..color = const Color(0xFF1A1610)..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
      startAngle, sweepTotal, false, bgPaint);

    const vulnSweep = sweepTotal * 0.4;
    const copingSweep = sweepTotal * 0.4;
    const healthySweep = sweepTotal * 0.2;

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
      startAngle, vulnSweep, false,
      Paint()..style = PaintingStyle.stroke..strokeWidth = 8
        ..color = const Color(0xFFE85D3A)..strokeCap = StrokeCap.round);

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
      startAngle + vulnSweep, copingSweep, false,
      Paint()..style = PaintingStyle.stroke..strokeWidth = 8
        ..color = const Color(0xFF7B5EA7));

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
      startAngle + vulnSweep + copingSweep, healthySweep, false,
      Paint()..style = PaintingStyle.stroke..strokeWidth = 8
        ..color = const Color(0xFF3B82C4)..strokeCap = StrokeCap.round);

    final scoreAngle = startAngle + sweepTotal * (score / 100).clamp(0.0, 1.0);
    final dotCenter = Offset(
      center.dx + radius * math.cos(scoreAngle),
      center.dy + radius * math.sin(scoreAngle));
    canvas.drawCircle(dotCenter, 6, Paint()..color = Colors.white);
    Color dotColor;
    if (score <= 39) { dotColor = const Color(0xFFE85D3A); }
    else if (score <= 79) { dotColor = const Color(0xFF7B5EA7); }
    else { dotColor = const Color(0xFF3B82C4); }
    canvas.drawCircle(dotCenter, 4, Paint()..color = dotColor);
  }

  @override
  bool shouldRepaint(covariant _MiniGaugePainter old) => old.score != score;
}

class _PulsingGlowCard extends StatefulWidget {
  const _PulsingGlowCard();

  @override
  State<_PulsingGlowCard> createState() => _PulsingGlowCardState();
}

class _PulsingGlowCardState extends State<_PulsingGlowCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final glow = 0.05 + _ctrl.value * 0.2;
        return Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF1E1A14), Color(0xFF0F0D09)]),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppTheme.primaryColor.withValues(alpha: glow)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: glow * 0.6),
                blurRadius: 24, spreadRadius: 2),
            ],
          ),
          child: Center(child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 24, height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppTheme.primaryColor.withValues(alpha: 0.5))),
              const SizedBox(height: 10),
              const Text('Calculating Health Score...', style: TextStyle(
                color: AppTheme.textHint, fontSize: 12)),
            ],
          )),
        );
      },
    );
  }
}

