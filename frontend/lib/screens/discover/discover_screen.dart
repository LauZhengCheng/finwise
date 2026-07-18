// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : discover_screen.dart
// Description   : Discover hub — scrolling news ticker, 3 market
//                 ticker rows (Stocks/Crypto/FX), 3 feature cards
//                 with background images.
// First Written : 17-06-2026
// Edited on     : 26-06-2026
// ============================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../services/api/finance_api.dart';
import '../main_scaffold.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final _api = FinanceApi();
  List<Map<String, dynamic>> _stockItems = [];
  List<Map<String, dynamic>> _cryptoItems = [];
  List<Map<String, dynamic>> _fxItems = [];
  List<String> _newsHeadlines = [];

  final _stockScroll = ScrollController();
  final _cryptoScroll = ScrollController();
  final _fxScroll = ScrollController();
  final _newsScroll = ScrollController();
  @override
  void initState() {
    super.initState();
    _loadData();
    discoverTabRefresh.addListener(_onRefresh);
  }

  void _onRefresh() {
    _loadData();
  }

  @override
  void dispose() {
    _stockScroll.dispose();
    _cryptoScroll.dispose();
    _fxScroll.dispose();
    _newsScroll.dispose();
    discoverTabRefresh.removeListener(_onRefresh);
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _api.getTickerData(),
        _api.getNews(),
      ]);

      final tickerData = results[0]['data'] as Map<String, dynamic>? ?? {};
      final newsData = results[1];

      final stocks = (tickerData['stocks'] as List? ?? [])
          .map((s) => Map<String, dynamic>.from(s as Map)).toList();
      final crypto = (tickerData['crypto'] as List? ?? [])
          .map((c) => Map<String, dynamic>.from(c as Map)).toList();
      final fx = (tickerData['fx'] as List? ?? [])
          .map((f) => Map<String, dynamic>.from(f as Map)).toList();

      final headlines = <String>[];
      final articles = newsData['data']?['articles'] as List? ??
          newsData['data'] as List? ?? [];
      for (final a in articles.take(15)) {
        if (a is Map && a['title'] != null) headlines.add(a['title'] as String);
      }

      if (mounted) {
        setState(() {
          _stockItems = stocks;
          _cryptoItems = crypto;
          _fxItems = fx;
          _newsHeadlines = headlines;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_scrolling) _startAutoScroll();
        });
      }
    } catch (_) {}
  }

  bool _scrolling = false;

  void _startAutoScroll() {
    if (_scrolling) return;
    _scrolling = true;
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      _autoScroll(_newsScroll, 25);
      _autoScroll(_stockScroll, 30);
      _autoScroll(_cryptoScroll, 35);
      _autoScroll(_fxScroll, 28);
    });
  }

  void _autoScroll(ScrollController ctrl, double speed) {
    if (!mounted || !ctrl.hasClients) return;
    try {
      final maxScroll = ctrl.position.maxScrollExtent;
      final remaining = maxScroll - ctrl.offset;
      if (remaining <= 0) {
        ctrl.jumpTo(0);
        Future.delayed(const Duration(milliseconds: 300), () => _autoScroll(ctrl, speed));
        return;
      }
      final duration = Duration(seconds: (remaining / speed).round().clamp(1, 600));
      ctrl.animateTo(maxScroll, duration: duration, curve: Curves.linear).then((_) {
        if (mounted) _autoScroll(ctrl, speed);
      }).catchError((_) {});
    } catch (_) {}
  }

  Widget _staggered(int index, int total, Widget child) => child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(0, 28, 0, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text('Discover', style: TextStyle(
                    color: AppTheme.textPrimary, fontSize: 28, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 16),

                // ── News ticker ──
                if (_newsHeadlines.isNotEmpty)
                  _buildTickerRow('NEWS', AppTheme.primaryColor, _newsScroll,
                    _newsHeadlines.map((h) => _TickerText(text: h, isNews: true)).toList()),

                // ── Stock ticker ──
                if (_stockItems.isNotEmpty)
                  _buildTickerRow('STOCKS', const Color(0xFF5090E0), _stockScroll,
                    _stockItems.map((item) => _MarketTickerItem(item: item)).toList()),

                // ── Crypto ticker ──
                if (_cryptoItems.isNotEmpty)
                  _buildTickerRow('CRYPTO', const Color(0xFFF7931A), _cryptoScroll,
                    _cryptoItems.map((item) => _MarketTickerItem(item: item)).toList()),

                // ── FX ticker ──
                if (_fxItems.isNotEmpty)
                  _buildTickerRow('FX', const Color(0xFF059669), _fxScroll,
                    _fxItems.map((item) => _MarketTickerItem(item: item)).toList()),

                const SizedBox(height: 24),

                // ── 3 Feature Cards (staggered entrance) ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(children: [
                    _staggered(0, 3, _DiscoverCard(
                      image: 'assets/Financial News.png',
                      title: 'Financial News',
                      subtitle: 'AI-summarised market updates',
                      onTap: () => context.push('/discover/news'),
                    )),
                    const SizedBox(height: 14),
                    _staggered(1, 3, _DiscoverCard(
                      image: 'assets/Smart Deals.png',
                      title: 'Smart Deals',
                      subtitle: 'Cashback & promotions',
                      onTap: () => context.push('/discover/deals'),
                    )),
                    const SizedBox(height: 14),
                    _staggered(2, 3, _DiscoverCard(
                      image: 'assets/Saving Bank.png',
                      title: 'FD Marketplace',
                      subtitle: 'Compare fixed deposit rates',
                      onTap: () => context.push('/discover/fd-rates'),
                    )),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTickerRow(String label, Color labelColor, ScrollController ctrl, List<Widget> children) {
    return Container(
      height: 22,
      margin: const EdgeInsets.only(bottom: 1),
      color: const Color(0xFF0D0B08),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          color: labelColor,
          alignment: Alignment.center,
          child: Text(label, style: const TextStyle(
            color: Color(0xFF0A0800), fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        ),
        Expanded(
          child: ListView(
            controller: ctrl,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            children: children,
          ),
        ),
      ]),
    );
  }
}

class _TickerText extends StatelessWidget {
  final String text;
  final bool isNews;
  const _TickerText({required this.text, this.isNews = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Center(child: Text(text,
        style: TextStyle(color: isNews ? AppTheme.textSecondary : AppTheme.textPrimary, fontSize: 11),
        maxLines: 1)),
    );
  }
}

class _MarketTickerItem extends StatelessWidget {
  final Map<String, dynamic> item;
  const _MarketTickerItem({required this.item});

  @override
  Widget build(BuildContext context) {
    final symbol = item['symbol'] as String? ?? '';
    final price = (item['price'] as num?)?.toDouble() ?? 0;
    final changePct = (item['change_pct'] as num?)?.toDouble();
    final isUp = (changePct ?? 0) >= 0;
    final type = item['type'] as String? ?? '';

    String priceStr;
    if (type == 'fx') {
      priceStr = price.toStringAsFixed(4);
    } else if (price > 1000) {
      priceStr = '\$${price.toStringAsFixed(0)}';
    } else {
      priceStr = '\$${price.toStringAsFixed(2)}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Center(child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(symbol, style: const TextStyle(
            color: AppTheme.textPrimary, fontSize: 10, fontWeight: FontWeight.w700)),
          const SizedBox(width: 4),
          Text(priceStr, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
          if (changePct != null) ...[
            const SizedBox(width: 3),
            Text('${isUp ? '▲' : '▼'}${changePct.abs().toStringAsFixed(1)}%',
              style: TextStyle(
                color: isUp ? AppTheme.successColor : AppTheme.errorColor,
                fontSize: 9, fontWeight: FontWeight.w600)),
          ],
        ],
      )),
    );
  }
}

class _DiscoverCard extends StatelessWidget {
  final String image;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DiscoverCard({
    required this.image,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          image: DecorationImage(
            image: AssetImage(image),
            fit: BoxFit.cover,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.black.withValues(alpha: 0.75),
                Colors.black.withValues(alpha: 0.2),
              ],
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(title, style: const TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}
