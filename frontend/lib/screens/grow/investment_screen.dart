// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : investment_screen.dart
// Description   : Investment portfolio — stock-app style UI with
//                 risk score bar (Morningstar thresholds), allocation
//                 chips, Aion analysis, and TradingView chart.
//                 Holdings managed on separate page.
// First Written : 17-06-2026
// Edited on     : 24-06-2026
// ============================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../services/api/invest_api.dart';
import '../../services/api/finance_api.dart';
import '../../widgets/shimmer_loading.dart';

class InvestmentScreen extends StatefulWidget {
  const InvestmentScreen({super.key});

  @override
  State<InvestmentScreen> createState() => _InvestmentScreenState();
}

class _InvestmentScreenState extends State<InvestmentScreen> {
  final _api = InvestApi();

  bool _loading = true;
  bool _showMyr = false;
  double? _usdToMyr;
  Map<String, dynamic>? _riskData;
  String _analysis = '';

  static const _categoryLabels = {
    'stocks': 'Stocks', 'crypto': 'Crypto', 'etf': 'ETF',
  };
  static const _categoryIcons = {
    'stocks': '📈', 'crypto': '₿', 'etf': '📊',
  };
  static const _categoryColors = {
    'crypto': Color(0xFFF7931A), 'stocks': Color(0xFF5090E0), 'etf': Color(0xFF059669),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _fmtPrice(double value) {
    if (_showMyr && _usdToMyr != null) {
      return 'RM ${(value * _usdToMyr!).toStringAsFixed(2)}';
    }
    return '\$ ${value.toStringAsFixed(2)}';
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.getRisk(),
        _api.getAnalysis(),
        FinanceApi().getTickerData(),
      ]);
      final risk = results[0] as Map<String, dynamic>;
      final analysis = results[1] as String;
      // Extract USD→MYR rate from FX data
      final tickerData = results[2] as Map<String, dynamic>;
      final fxList = (tickerData['data']?['fx'] as List?) ?? [];
      for (final fx in fxList) {
        if ((fx as Map)['symbol'] == 'MYR/USD') {
          final rate = (fx['price'] as num?)?.toDouble();
          if (rate != null && rate > 0) _usdToMyr = 1 / rate;
          break;
        }
      }
      if (mounted) {
        setState(() {
          _riskData = risk['data'] as Map<String, dynamic>?;
          _analysis = analysis;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _riskColor(int score) {
    if (score <= 23) return AppTheme.successColor;
    if (score <= 47) return AppTheme.primaryColor;
    if (score <= 78) return const Color(0xFFF59E0B);
    return AppTheme.errorColor;
  }

  @override
  Widget build(BuildContext context) {
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
                      onTap: () => context.pop(),
                      child: const Icon(Icons.arrow_back_rounded,
                          color: AppTheme.textPrimary, size: 24),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(child: Text('Investment Portfolio', style: TextStyle(
                      color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w700))),
                    GestureDetector(
                      onTap: () async {
                        final result = await context.push<Map<String, dynamic>>('/grow/invest/holdings');
                        if (result != null && mounted) {
                          setState(() {
                            if (result['risk'] != null) _riskData = result['risk'] as Map<String, dynamic>;
                            if (result['analysis'] != null) _analysis = result['analysis'] as String;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                        ),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.edit_rounded, size: 14, color: AppTheme.primaryColor),
                          SizedBox(width: 4),
                          Text('Holdings', style: TextStyle(
                            color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => context.push('/grow/invest/chart'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.glassBorderColor),
                        ),
                        child: const Icon(Icons.insert_chart_rounded, size: 18, color: AppTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _loading
                    ? const Padding(padding: EdgeInsets.all(20), child: SkeletonTransactionList(count: 4))
                    : _buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final data = _riskData;
    final hasData = data != null;
    final score = (data?['risk_score'] as num?)?.toInt() ?? 0;
    final riskLevel = data?['risk_level'] as String? ?? 'N/A';
    final totalValue = (data?['total_value'] as num?)?.toDouble() ?? 0;
    final totalPnl = (data?['total_pnl'] as num?)?.toDouble() ?? 0;
    final totalPnlPct = (data?['total_pnl_pct'] as num?)?.toDouble() ?? 0;
    final allocation = (data?['allocation'] as Map<String, dynamic>?) ?? {};
    final holdings = (data?['holdings'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF1E1A14), Color(0xFF0F0D09)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasData) ...[
                  Row(children: [
                    const Text('Total Portfolio', style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
                    const Spacer(),
                    if (_usdToMyr != null)
                      GestureDetector(
                        onTap: () => setState(() => _showMyr = !_showMyr),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.glassBorderColor)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(_showMyr ? 'MYR' : 'USD', style: const TextStyle(
                              color: AppTheme.textPrimary, fontSize: 10, fontWeight: FontWeight.w700)),
                            const SizedBox(width: 4),
                            const Icon(Icons.swap_vert_rounded, size: 12, color: AppTheme.textHint),
                          ]),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 4),
                  Text(_fmtPrice(totalValue), style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 28, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(totalPnl >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                      size: 16, color: totalPnl >= 0 ? AppTheme.successColor : AppTheme.errorColor),
                    const SizedBox(width: 4),
                    Text('${totalPnl >= 0 ? '+' : ''}${_fmtPrice(totalPnl.abs())} (${totalPnlPct >= 0 ? '+' : ''}${totalPnlPct.toStringAsFixed(1)}%)',
                      style: TextStyle(
                        color: totalPnl >= 0 ? AppTheme.successColor : AppTheme.errorColor,
                        fontSize: 14, fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 20),
                  _buildRiskBar(score, riskLevel),
                  const SizedBox(height: 16),
                  // Allocation chips
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: allocation.entries.map((e) {
                      final color = _categoryColors[e.key] ?? AppTheme.textHint;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12)),
                        child: Text('${_categoryLabels[e.key] ?? e.key} ${e.value}%',
                          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
                      );
                    }).toList(),
                  ),
                  // Holdings list
                  if (holdings.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Divider(color: AppTheme.glassBorderColor),
                    const SizedBox(height: 12),
                    ...holdings.map((h) {
                      final pnl = (h['pnl'] as num?)?.toDouble() ?? 0;
                      final pnlPct = (h['pnl_pct'] as num?)?.toDouble() ?? 0;
                      final emoji = _categoryIcons[h['category']] ?? '💼';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(children: [
                          Text(emoji, style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 10),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(h['name'] as String? ?? '', style: const TextStyle(
                                color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                              Text('${h['weight']}% · ${_fmtPrice((h['value'] as num?)?.toDouble() ?? 0)}',
                                style: const TextStyle(color: AppTheme.textHint, fontSize: 11)),
                            ],
                          )),
                          Text('${pnl >= 0 ? '+' : ''}${pnlPct.toStringAsFixed(1)}%', style: TextStyle(
                            color: pnl >= 0 ? AppTheme.successColor : AppTheme.errorColor,
                            fontSize: 13, fontWeight: FontWeight.w700)),
                        ]),
                      );
                    }),
                  ],
                ] else ...[
                  Center(child: Column(children: [
                    const SizedBox(height: 8),
                    Icon(Icons.account_balance_wallet_outlined, size: 40,
                      color: AppTheme.textHint.withValues(alpha: 0.3)),
                    const SizedBox(height: 12),
                    const Text('No holdings yet', style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 14)),
                    const SizedBox(height: 4),
                    const Text('Tap "Holdings" above to add your investments', style: TextStyle(
                      color: AppTheme.textHint, fontSize: 12)),
                    const SizedBox(height: 8),
                  ])),
                ],

                const SizedBox(height: 16),
                const Divider(color: AppTheme.glassBorderColor),
                const SizedBox(height: 12),

                Row(children: [
                  Icon(Icons.auto_awesome_rounded, size: 14,
                    color: AppTheme.primaryColor.withValues(alpha: 0.7)),
                  const SizedBox(width: 6),
                  Text("Aion's Analysis", style: TextStyle(
                    color: AppTheme.primaryColor.withValues(alpha: 0.7),
                    fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 8),
                Text(_analysis.isNotEmpty ? _analysis : 'Add holdings to get personalised analysis from Aion.',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskBar(int score, String label) {
    final color = _riskColor(score);
    return Column(children: [
      Row(children: [
        const Text('Risk Score', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        const Spacer(),
        Text('$score/100', style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
          child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
        ),
      ]),
      const SizedBox(height: 8),
      LayoutBuilder(builder: (context, constraints) {
        final barWidth = constraints.maxWidth;
        final pos = (score / 100).clamp(0.0, 1.0) * barWidth;
        return Stack(clipBehavior: Clip.none, children: [
          Container(
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: const LinearGradient(
                colors: [Color(0xFF059669), Color(0xFFD4A843), Color(0xFFF59E0B), Color(0xFFEF4444)],
                stops: [0.0, 0.24, 0.48, 0.79],
              ),
            ),
          ),
          Positioned(
            left: pos - 7, top: -3,
            child: Container(
              width: 14, height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle, color: Colors.white,
                border: Border.all(color: color, width: 2.5),
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6)],
              ),
            ),
          ),
        ]);
      }),
      const SizedBox(height: 4),
      Row(children: [
        Text('Con', style: TextStyle(color: AppTheme.textHint.withValues(alpha: 0.4), fontSize: 8)),
        const Spacer(),
        Text('Mod', style: TextStyle(color: AppTheme.textHint.withValues(alpha: 0.4), fontSize: 8)),
        const Spacer(),
        Text('Agg', style: TextStyle(color: AppTheme.textHint.withValues(alpha: 0.4), fontSize: 8)),
        const Spacer(),
        Text('V.Agg', style: TextStyle(color: AppTheme.textHint.withValues(alpha: 0.4), fontSize: 8)),
      ]),
    ]);
  }
}
