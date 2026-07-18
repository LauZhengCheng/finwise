// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : news_screen.dart
// Description   : Financial news feed — breaking news carousel,
//                 category tabs, article list with thumbnails,
//                 tap for detail screen.
// First Written : 17-06-2026
// Edited on     : 21-06-2026
// ============================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../services/api/finance_api.dart';
import '../../widgets/shimmer_loading.dart';
import 'news_detail_screen.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> with SingleTickerProviderStateMixin {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _breaking = [];
  List<Map<String, dynamic>> _articles = [];
  final _carouselCtrl = PageController();
  Timer? _carouselTimer;
  int _carouselPage = 0;

  late final TabController _tabCtrl;
  static const _tabs = ['For You', 'Markets', 'Economy', 'Banking'];
  static const _tabTags = [
    null,
    ['stock_market', 'crypto'],
    ['monetary_policy', 'inflation', 'employment', 'trade', 'government'],
    ['interest_rates', 'banking'],
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _carouselCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final response = await FinanceApi().getNews();
      if (!mounted) return;
      final data = response['data'] as Map<String, dynamic>? ?? {};
      setState(() {
        _breaking = (data['breaking'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        _articles = (data['articles'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        // If no breaking, promote first 3 articles to carousel
        if (_breaking.isEmpty && _articles.length > 2) {
          _breaking = _articles.take(3).toList();
          _articles = _articles.skip(3).toList();
        }
        _loading = false;
      });
      _startCarousel();
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  void _startCarousel() {
    _carouselTimer?.cancel();
    if (_breaking.length < 2) return;
    _carouselTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      _carouselPage = (_carouselPage + 1) % _breaking.length;
      _carouselCtrl.animateToPage(_carouselPage,
        duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    });
  }

  List<Map<String, dynamic>> _filteredArticles(int tabIndex) {
    final tags = _tabTags[tabIndex];
    if (tags == null) return _articles;
    return _articles.where((a) {
      final articleTags = (a['tags'] as List?)?.cast<String>() ?? [];
      return articleTags.any((t) => tags.contains(t));
    }).toList();
  }

  Color _sentimentColor(String? sentiment) {
    switch (sentiment) {
      case 'positive': return AppTheme.successColor;
      case 'negative': return AppTheme.errorColor;
      default: return const Color(0xFF5090E0);
    }
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  OverlayEntry? _sentimentOverlay;

  void _showSentimentGuide(BuildContext context) {
    _sentimentOverlay = OverlayEntry(
      builder: (ctx) => Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.glassBorderColor),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 30)],
              ),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Sentiment Guide', style: TextStyle(
                      color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    _sentimentRow(AppTheme.successColor, 'Positive',
                      'Good for your finances — rate cuts, market gains, ringgit strengthening'),
                    const SizedBox(height: 12),
                    _sentimentRow(AppTheme.errorColor, 'Negative',
                      'May impact your money — rate hikes, market drops, inflation rising'),
                    const SizedBox(height: 12),
                    _sentimentRow(const Color(0xFF5090E0), 'Neutral',
                      'Informational — no direct impact on your finances'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_sentimentOverlay!);
  }

  void _hideSentimentGuide() {
    _sentimentOverlay?.remove();
    _sentimentOverlay = null;
  }

  Widget _sentimentRow(Color color, String label, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 10, height: 10,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(desc, style: const TextStyle(color: AppTheme.textHint, fontSize: 11, height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }

  void _openDetail(Map<String, dynamic> article) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => NewsDetailScreen(article: article),
    ));
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
              // Header
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
                    const Text('Financial News', style: TextStyle(
                      color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    GestureDetector(
                      onLongPressStart: (_) => _showSentimentGuide(context),
                      onLongPressEnd: (_) => _hideSentimentGuide(),
                      child: Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.cardColor,
                          border: Border.all(color: AppTheme.glassBorderColor),
                        ),
                        child: const Center(
                          child: Text('?', style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _loading
                    ? const Padding(padding: EdgeInsets.all(20), child: SkeletonTransactionList(count: 5))
                    : _error != null
                        ? Center(child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline_rounded, color: AppTheme.errorColor, size: 48),
                              const SizedBox(height: 12),
                              Text(_error!, style: const TextStyle(color: AppTheme.textSecondary)),
                              const SizedBox(height: 16),
                              TextButton(onPressed: _load, child: const Text('Retry',
                                style: TextStyle(color: AppTheme.primaryColor))),
                            ],
                          ))
                        : _buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // Breaking news carousel
        if (_breaking.isNotEmpty) ...[
          SizedBox(
            height: 200,
            child: PageView.builder(
              controller: _carouselCtrl,
              itemCount: _breaking.length,
              onPageChanged: (i) => setState(() => _carouselPage = i),
              itemBuilder: (context, i) => _BreakingCard(
                article: _breaking[i],
                sentimentColor: _sentimentColor,
                timeAgo: _timeAgo,
                onTap: () => _openDetail(_breaking[i]),
              ),
            ),
          ),
          if (_breaking.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_breaking.length, (i) {
                  final active = i == _carouselPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 20 : 6, height: 6,
                    decoration: BoxDecoration(
                      color: active ? AppTheme.primaryColor : AppTheme.glassBorderColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
          const SizedBox(height: 16),
        ],

        // Category tabs
        TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primaryColor,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 14),
          tabAlignment: TabAlignment.start,
          dividerColor: Colors.transparent,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),

        // Article list
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: List.generate(_tabs.length, (tabIndex) {
              final articles = _filteredArticles(tabIndex);
              if (articles.isEmpty) {
                return const Center(child: Text('No articles in this category',
                  style: TextStyle(color: AppTheme.textHint, fontSize: 14)));
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 108),
                itemCount: articles.length,
                itemBuilder: (context, i) => _ArticleCard(
                  article: articles[i],
                  sentimentColor: _sentimentColor,
                  timeAgo: _timeAgo,
                  onTap: () => _openDetail(articles[i]),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

// ── Breaking news card (carousel) ──────────────────────────────
class _BreakingCard extends StatelessWidget {
  final Map<String, dynamic> article;
  final Color Function(String?) sentimentColor;
  final String Function(String?) timeAgo;
  final VoidCallback onTap;

  const _BreakingCard({
    required this.article, required this.sentimentColor,
    required this.timeAgo, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = article['image_url'] as String?;
    final sentiment = article['sentiment'] as String? ?? 'neutral';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.glassBorderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background image or gradient
            if (imageUrl != null && imageUrl.isNotEmpty)
              Image.network(imageUrl, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [sentimentColor(sentiment).withValues(alpha: 0.3), AppTheme.cardColor],
                    ),
                  ),
                ))
            else
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [sentimentColor(sentiment).withValues(alpha: 0.2), AppTheme.cardColor],
                  ),
                ),
              ),

            // Dark overlay for text readability
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
                  stops: const [0.3, 1.0],
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: sentimentColor(sentiment),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      sentiment[0].toUpperCase() + sentiment.substring(1),
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    article['title'] as String? ?? '',
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, height: 1.3),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${article['source'] ?? ''} · ${timeAgo(article['published_at']?.toString())}',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Article list card ──────────────────────────────────────────
class _ArticleCard extends StatelessWidget {
  final Map<String, dynamic> article;
  final Color Function(String?) sentimentColor;
  final String Function(String?) timeAgo;
  final VoidCallback onTap;

  const _ArticleCard({
    required this.article, required this.sentimentColor,
    required this.timeAgo, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = article['image_url'] as String?;
    final sentiment = article['sentiment'] as String? ?? 'neutral';
    final tags = (article['tags'] as List?)?.cast<String>() ?? [];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.glassBorderColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 90, height: 90,
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(imageUrl, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _PlaceholderThumb(color: sentimentColor(sentiment)))
                    : _PlaceholderThumb(color: sentimentColor(sentiment)),
              ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tag + sentiment
                  Row(
                    children: [
                      if (tags.isNotEmpty)
                        Text(
                          tags.first.replaceAll('_', ' '),
                          style: TextStyle(
                            color: sentimentColor(sentiment),
                            fontSize: 10, fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      const Spacer(),
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: sentimentColor(sentiment),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Title
                  Text(
                    article['title'] as String? ?? '',
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 14,
                      fontWeight: FontWeight.w600, height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Source + time
                  Text(
                    '${article['source'] ?? ''} · ${timeAgo(article['published_at']?.toString())}',
                    style: const TextStyle(color: AppTheme.textHint, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderThumb extends StatelessWidget {
  final Color color;
  const _PlaceholderThumb({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color.withValues(alpha: 0.15),
      child: Center(
        child: Icon(Icons.article_rounded, color: color.withValues(alpha: 0.4), size: 28),
      ),
    );
  }
}
