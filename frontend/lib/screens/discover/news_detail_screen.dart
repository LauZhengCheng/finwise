// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : news_detail_screen.dart
// Description   : News article detail — full image, Aion summary,
//                 tags, and "Read Full Article" in-app browser.
// First Written : 21-06-2026
// Edited on     : 21-06-2026
// ============================================

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart' show Share;
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_theme.dart';

class NewsDetailScreen extends StatelessWidget {
  final Map<String, dynamic> article;

  const NewsDetailScreen({super.key, required this.article});

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

  Future<void> _openArticle(BuildContext context) async {
    final url = article['url'] as String?;
    if (url == null) return;
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open article')),
        );
      }
    }
  }

  void _share() {
    final title = article['title'] as String? ?? '';
    final url = article['url'] as String? ?? '';
    Share.share('$title\n$url');
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = article['image_url'] as String?;
    final sentiment = article['sentiment'] as String? ?? 'neutral';
    final tags = (article['tags'] as List?)?.cast<String>() ?? [];
    final color = _sentimentColor(sentiment);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: CustomScrollView(
          slivers: [
            // ── Collapsing image header ──
            SliverAppBar(
              expandedHeight: 240,
              pinned: true,
              backgroundColor: AppTheme.backgroundColor,
              leading: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                ),
              ),
              actions: [
                GestureDetector(
                  onTap: _share,
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.share_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageUrl != null && imageUrl.isNotEmpty)
                      Image.network(imageUrl, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [color.withValues(alpha: 0.3), AppTheme.cardColor],
                            ),
                          ),
                        ))
                    else
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                            colors: [color.withValues(alpha: 0.2), AppTheme.cardColor],
                          ),
                        ),
                        child: Center(child: Icon(Icons.article_rounded, size: 56, color: color.withValues(alpha: 0.3))),
                      ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                          stops: const [0.4, 1.0],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Content ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 108),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sentiment badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: color.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        sentiment[0].toUpperCase() + sentiment.substring(1),
                        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Title
                    Text(
                      article['title'] as String? ?? '',
                      style: const TextStyle(
                        color: AppTheme.textPrimary, fontSize: 22,
                        fontWeight: FontWeight.w700, height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Source + time
                    Row(
                      children: [
                        const Icon(Icons.newspaper_rounded, size: 14, color: AppTheme.textHint),
                        const SizedBox(width: 6),
                        Text(
                          '${article['source'] ?? 'Unknown'}',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.access_time_rounded, size: 14, color: AppTheme.textHint),
                        const SizedBox(width: 4),
                        Text(
                          _timeAgo(article['published_at']?.toString()),
                          style: const TextStyle(color: AppTheme.textHint, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Aion summary
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1A14),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.auto_awesome_rounded, size: 14,
                                color: AppTheme.primaryColor.withValues(alpha: 0.7)),
                              const SizedBox(width: 6),
                              Text("Aion's Summary", style: TextStyle(
                                color: AppTheme.primaryColor.withValues(alpha: 0.7),
                                fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            article['summary'] as String? ?? 'No summary available.',
                            style: const TextStyle(
                              color: AppTheme.textPrimary, fontSize: 15, height: 1.6),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Tags
                    if (tags.isNotEmpty) ...[
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: tags.map((tag) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.glassBorderColor),
                          ),
                          child: Text(
                            tag.replaceAll('_', ' '),
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                          ),
                        )).toList(),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Read full article button
                    GestureDetector(
                      onTap: () => _openArticle(context),
                      child: Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: AppTheme.goldGradient,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Read Full Article', style: TextStyle(
                              color: Color(0xFF0A0800), fontSize: 15, fontWeight: FontWeight.w700)),
                            SizedBox(width: 8),
                            Icon(Icons.open_in_new_rounded, color: Color(0xFF0A0800), size: 18),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
