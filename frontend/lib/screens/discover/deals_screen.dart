// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : deals_screen.dart
// Description   : Smart Deals — full-width deal feed with category
//                 gradient headers, Aion insights, need/want filter.
// First Written : 17-06-2026
// Edited on     : 21-06-2026
// ============================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_theme.dart';
import '../../services/api/finance_api.dart';
import '../../widgets/shimmer_loading.dart';

class DealsScreen extends StatefulWidget {
  const DealsScreen({super.key});

  @override
  State<DealsScreen> createState() => _DealsScreenState();
}

class _DealsScreenState extends State<DealsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _allDeals = [];

  String _typeFilter = 'all';
  String _categoryFilter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await FinanceApi().getDeals();
      if (!mounted) return;
      setState(() {
        _allDeals = (response['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  List<String> get _categories {
    final cats = _allDeals.map((d) => d['category'] as String? ?? 'other').toSet().toList();
    cats.sort();
    return cats;
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _allDeals;
    if (_typeFilter == 'needs') {
      list = list.where((d) => d['is_need'] == true).toList();
    } else if (_typeFilter == 'wants') {
      list = list.where((d) => d['is_want'] == true).toList();
    }
    if (_categoryFilter != 'all') {
      list = list.where((d) => d['category'] == _categoryFilter).toList();
    }
    return list;
  }

  static const _categoryColors = {
    'food': Color(0xFF059669),
    'transport': Color(0xFF5090E0),
    'shopping': Color(0xFFF59E0B),
    'entertainment': Color(0xFFEC4899),
    'health': Color(0xFF10B981),
    'education': Color(0xFF6366F1),
    'utilities': Color(0xFF64748B),
    'finance': Color(0xFF7C3AED),
    'travel': Color(0xFF0EA5E9),
    'other': Color(0xFF6B7280),
  };

  static const _categoryIcons = {
    'food': Icons.restaurant_rounded,
    'transport': Icons.directions_car_rounded,
    'shopping': Icons.shopping_bag_rounded,
    'entertainment': Icons.movie_rounded,
    'health': Icons.medical_services_rounded,
    'education': Icons.school_rounded,
    'utilities': Icons.bolt_rounded,
    'finance': Icons.credit_card_rounded,
    'travel': Icons.flight_rounded,
    'other': Icons.local_offer_rounded,
  };

  Color _catColor(String? cat) => _categoryColors[cat ?? 'other'] ?? const Color(0xFF6B7280);
  IconData _catIconData(String? cat) => _categoryIcons[cat ?? 'other'] ?? Icons.local_offer_rounded;

  static const _bankDomains = {
    'affin': 'affinbank.com.my',
    'alliance': 'alliancebank.com.my',
    'ambank': 'ambank.com.my',
    'bank islam': 'bankislam.com',
    'cimb': 'cimb.com',
    'hong leong': 'hlb.com.my',
    'hsbc': 'hsbc.com.my',
    'maybank': 'maybank.com',
    'mbsb': 'mbsb.com.my',
    'ocbc': 'ocbc.com.my',
    'public': 'publicbank.com.my',
    'rhb': 'rhb.com.my',
    'standard chartered': 'sc.com',
    'uob': 'uob.com.my',
  };

  String? _logoUrl(String? merchant) {
    if (merchant == null) return null;
    final lower = merchant.toLowerCase();
    for (final entry in _bankDomains.entries) {
      if (lower.contains(entry.key)) {
        return 'https://logo.clearbit.com/${entry.value}';
      }
    }
    return null;
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
                    const Text('Smart Deals', style: TextStyle(
                      color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text('${_filtered.length} deals', style: const TextStyle(
                      color: AppTheme.textHint, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Type filter
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _TypeChip(label: 'All', active: _typeFilter == 'all',
                      onTap: () => setState(() => _typeFilter = 'all')),
                    const SizedBox(width: 8),
                    _TypeChip(label: 'Needs', active: _typeFilter == 'needs',
                      onTap: () => setState(() => _typeFilter = 'needs'),
                      color: AppTheme.successColor),
                    const SizedBox(width: 8),
                    _TypeChip(label: 'Wants', active: _typeFilter == 'wants',
                      onTap: () => setState(() => _typeFilter = 'wants'),
                      color: const Color(0xFFF59E0B)),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Category filter
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _TypeChip(label: 'All', active: _categoryFilter == 'all',
                      onTap: () => setState(() => _categoryFilter = 'all')),
                    ..._categories.map((cat) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _TypeChip(
                        label: '${cat[0].toUpperCase()}${cat.substring(1)}',
                        active: _categoryFilter == cat,
                        onTap: () => setState(() => _categoryFilter = cat),
                        color: _catColor(cat),
                      ),
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Deal feed
              Expanded(
                child: _loading
                    ? const Padding(padding: EdgeInsets.all(20), child: SkeletonTransactionList(count: 4))
                    : _error != null
                        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.error_outline_rounded, color: AppTheme.errorColor, size: 48),
                            const SizedBox(height: 12),
                            Text(_error!, style: const TextStyle(color: AppTheme.textSecondary)),
                            const SizedBox(height: 16),
                            TextButton(onPressed: _load, child: const Text('Retry',
                              style: TextStyle(color: AppTheme.primaryColor))),
                          ]))
                        : _buildFeed(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeed() {
    final deals = _filtered;
    if (deals.isEmpty) {
      return const Center(child: Text('No deals match your filters',
        style: TextStyle(color: AppTheme.textHint, fontSize: 14)));
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 108),
        itemCount: deals.length,
        itemBuilder: (context, i) => _DealFeedCard(
          deal: deals[i],
          catColor: _catColor,
          catIcon: _catIconData,
          logoUrl: _logoUrl,
        ),
      ),
    );
  }
}

// ── Deal feed card (Concept C) ──────────────────────────────
class _DealFeedCard extends StatelessWidget {
  final Map<String, dynamic> deal;
  final Color Function(String?) catColor;
  final IconData Function(String?) catIcon;
  final String? Function(String?) logoUrl;

  const _DealFeedCard({
    required this.deal, required this.catColor,
    required this.catIcon, required this.logoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final merchant = deal['merchant'] as String? ?? '';
    final title = deal['deal_title'] as String? ?? '';
    final category = deal['category'] as String? ?? 'other';
    final isNeed = deal['is_need'] as bool? ?? false;
    final note = deal['aion_note'] as String?;
    final discount = deal['discount_pct'] as num?;
    final cashback = deal['max_cashback'] as num?;
    final sourceUrl = deal['source_url'] as String?;
    final color = catColor(category);
    final logo = logoUrl(merchant);
    final catLabel = category.isEmpty ? 'Other' : '${category[0].toUpperCase()}${category.substring(1)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.glassBorderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category gradient header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0.1)],
              ),
            ),
            child: Row(
              children: [
                Icon(catIcon(category), size: 14, color: color),
                const SizedBox(width: 6),
                Text(catLabel, style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (isNeed ? AppTheme.successColor : const Color(0xFFF59E0B)).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: (isNeed ? AppTheme.successColor : const Color(0xFFF59E0B)).withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    isNeed ? 'NEED' : 'WANT',
                    style: TextStyle(
                      color: isNeed ? AppTheme.successColor : const Color(0xFFF59E0B),
                      fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Merchant + logo
                Row(
                  children: [
                    if (logo != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(logo, width: 28, height: 28, fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(child: Text(
                              merchant.isNotEmpty ? merchant[0] : '?',
                              style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w800),
                            )),
                          )),
                      )
                    else
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(child: Text(
                          merchant.isNotEmpty ? merchant[0] : '?',
                          style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w800),
                        )),
                      ),
                    const SizedBox(width: 10),
                    Text(merchant, style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 12),

                // Deal title
                Text(title, style: const TextStyle(
                  color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700, height: 1.3)),
                const SizedBox(height: 10),

                // Discount/cashback chips
                if (discount != null || cashback != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        if (discount != null)
                          _Chip(text: '${discount.toStringAsFixed(0)}% off', color: color),
                        if (cashback != null)
                          _Chip(text: 'RM ${cashback.toStringAsFixed(0)} cashback', color: color),
                      ],
                    ),
                  ),

                // Aion insight
                if (note != null && note.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.auto_awesome_rounded, size: 14,
                          color: AppTheme.primaryColor.withValues(alpha: 0.7)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(note, style: TextStyle(
                            color: AppTheme.primaryColor.withValues(alpha: 0.85),
                            fontSize: 12, height: 1.4)),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () async {
                      final url = sourceUrl ?? 'https://www.imoney.my/credit-card-promotion';
                      debugPrint('[Deals] Opening: $url');
                      try {
                        final success = await launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView);
                        if (!success && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Could not open: $url')));
                        }
                      } catch (e) {
                        debugPrint('[Deals] Launch error: $e');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')));
                        }
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('View source', style: TextStyle(
                          color: color.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 4),
                        Icon(Icons.open_in_new_rounded, size: 12, color: color.withValues(alpha: 0.7)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color color;
  const _Chip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color? color;
  const _TypeChip({required this.label, required this.active, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.primaryColor;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? c.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? c : AppTheme.glassBorderColor),
        ),
        child: Text(label, style: TextStyle(
          color: active ? c : AppTheme.textSecondary,
          fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
