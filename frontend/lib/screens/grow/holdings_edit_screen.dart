// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : holdings_edit_screen.dart
// Description   : Trader-friendly holdings editor — 3 category tabs
//                 (Crypto/Stocks/ETF). Crypto from CoinGecko with prices,
//                 Stocks/ETF full list from Alpha Vantage LISTING_STATUS.
//                 Tap ticker → enter units + buy price → add.
// First Written : 24-06-2026
// Edited on     : 24-06-2026
// ============================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/app_theme.dart';
import '../../services/api/invest_api.dart';

class HoldingsEditScreen extends StatefulWidget {
  const HoldingsEditScreen({super.key});

  @override
  State<HoldingsEditScreen> createState() => _HoldingsEditScreenState();
}

class _HoldingsEditScreenState extends State<HoldingsEditScreen> with SingleTickerProviderStateMixin {
  final _api = InvestApi();
  final _fmt = NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 2);
  final _searchCtrl = TextEditingController();
  late TabController _tabController;

  bool _loadingHoldings = true;
  bool _saving = false;
  List<Map<String, dynamic>> _myHoldings = [];
  String _search = '';

  // Crypto
  List<Map<String, dynamic>> _cryptoList = [];
  bool _cryptoLoading = true;

  // Stocks + ETF (loaded once, split client-side)
  List<Map<String, dynamic>> _stockList = [];
  List<Map<String, dynamic>> _etfList = [];
  bool _stocksEtfLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _searchCtrl.clear();
        setState(() => _search = '');
      }
    });
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    // Load existing holdings
    try {
      final investments = await _api.getInvestments();
      if (mounted) {
        setState(() {
          _myHoldings = investments.map((h) => <String, dynamic>{
            'asset_name': h['asset_name'] ?? '',
            'ticker': h['ticker'] ?? '',
            'category': h['category'] ?? 'stocks',
            'units': (h['units'] as num?)?.toDouble() ?? 0,
            'purchase_price': (h['purchase_price'] as num?)?.toDouble() ?? 0,
            'current_price': (h['current_price'] as num?)?.toDouble() ?? 0,
          }).toList();
          _loadingHoldings = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingHoldings = false);
    }

    // Load all 3 lists in parallel
    _loadCrypto();
    _loadListings();
  }

  Future<void> _loadCrypto() async {
    try {
      final data = await _api.getCryptoPrices();
      if (mounted) setState(() { _cryptoList = data; _cryptoLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _cryptoLoading = false);
    }
  }

  Future<void> _loadListings() async {
    try {
      final data = await _api.getListings();
      if (mounted) {
        setState(() {
          _stockList = data.where((t) => t['category'] == 'stocks').toList();
          _etfList = data.where((t) => t['category'] == 'etf').toList();
          _stocksEtfLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _stocksEtfLoading = false);
    }
  }

  bool _isHeld(String ticker) =>
    _myHoldings.any((h) => (h['ticker'] as String).toUpperCase() == ticker.toUpperCase());

  void _removeHolding(String ticker) {
    setState(() {
      _myHoldings.removeWhere((h) => (h['ticker'] as String).toUpperCase() == ticker.toUpperCase());
    });
  }

  void _showAddSheet(String ticker, String name, String category, {double? livePrice}) {
    if (_isHeld(ticker)) return;

    showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: AppTheme.cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _AddHoldingSheet(
        ticker: ticker,
        name: name,
        category: category,
        livePrice: livePrice,
        api: _api,
        fmt: _fmt,
        catEmoji: _catEmoji,
        catColor: _catColor,
      ),
    ).then((result) {
      if (result != null && mounted) {
        setState(() => _myHoldings.add(result));
      }
    });
  }

  Future<void> _save() async {
    if (_myHoldings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Add at least one holding before saving'),
        backgroundColor: AppTheme.textHint));
      return;
    }

    final payload = _myHoldings.map((h) => <String, dynamic>{
      'asset_name': h['asset_name'],
      'ticker': h['ticker'],
      'category': h['category'],
      'units': h['units'],
      'purchase_price': h['purchase_price'],
      'current_price': h['current_price'],
    }).toList();

    setState(() => _saving = true);
    try {
      final result = await _api.saveAll(payload);
      if (mounted) {
        context.pop<Map<String, dynamic>>({
          'risk': result['risk'],
          'analysis': result['analysis'],
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppTheme.errorColor));
      }
    }
  }

  Color _catColor(String cat) {
    switch (cat) {
      case 'crypto': return const Color(0xFFF7931A);
      case 'stocks': return const Color(0xFF5090E0);
      case 'etf': return const Color(0xFF059669);
      default: return AppTheme.textHint;
    }
  }

  String _catEmoji(String cat) {
    switch (cat) {
      case 'crypto': return '₿';
      case 'stocks': return '📈';
      case 'etf': return '📊';
      default: return '💼';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(children: [
                GestureDetector(
                  onTap: () => context.pop(),
                  child: const Icon(Icons.arrow_back_rounded,
                    color: AppTheme.textPrimary, size: 24)),
                const SizedBox(width: 16),
                const Expanded(child: Text('Manage Holdings', style: TextStyle(
                  color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w700))),
                GestureDetector(
                  onTap: _saving ? null : _save,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: _saving ? null : AppTheme.goldGradient,
                      color: _saving ? AppTheme.textHint.withValues(alpha: 0.3) : null,
                      borderRadius: BorderRadius.circular(10)),
                    child: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.textSecondary))
                      : const Text('Save', style: TextStyle(
                          color: Color(0xFF0A0800), fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ),

            // My holdings chips — always present in the tree (zero height when empty)
            // to keep Column children structurally stable for TabBarView below
            const SizedBox(height: 16),
            SizedBox(
              height: _myHoldings.isEmpty ? 0 : 38,
              child: _myHoldings.isEmpty
                ? null
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: _myHoldings.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final h = _myHoldings[i];
                      final color = _catColor(h['category'] as String);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: color.withValues(alpha: 0.3))),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(h['ticker'] as String, style: TextStyle(
                            color: color, fontSize: 12, fontWeight: FontWeight.w700)),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => _removeHolding(h['ticker'] as String),
                            child: Icon(Icons.close_rounded, size: 14, color: color.withValues(alpha: 0.7)),
                          ),
                        ]),
                      );
                    },
                  ),
            ),
            const SizedBox(height: 16),

            // Tabs
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(12)),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  gradient: AppTheme.goldGradient,
                  borderRadius: BorderRadius.circular(10)),
                labelColor: const Color(0xFF0A0800),
                unselectedLabelColor: AppTheme.textSecondary,
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerHeight: 0,
                tabs: const [
                  Tab(text: '₿ Crypto'),
                  Tab(text: '📈 Stocks'),
                  Tab(text: '📊 ETF'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                onChanged: (v) => setState(() => _search = v.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search ticker or name...',
                  hintStyle: const TextStyle(color: AppTheme.textHint, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textHint, size: 20),
                  filled: true, fillColor: AppTheme.surfaceColor,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.glassBorderColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.glassBorderColor)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primaryColor)),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Lists
            Expanded(
              child: _loadingHoldings
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildCryptoTab(),
                      _buildListTab(_stockList, 'stocks', _stocksEtfLoading),
                      _buildListTab(_etfList, 'etf', _stocksEtfLoading),
                    ],
                  ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildCryptoTab() {
    if (_cryptoLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFF7931A)));
    }

    final filtered = _search.isEmpty ? _cryptoList : _cryptoList.where((c) =>
      (c['ticker'] as String).toLowerCase().contains(_search) ||
      (c['name'] as String).toLowerCase().contains(_search)
    ).toList();

    if (filtered.isEmpty) {
      return Center(child: Text(
        _search.isEmpty ? 'No crypto data available' : 'No results for "$_search"',
        style: const TextStyle(color: AppTheme.textHint, fontSize: 14)));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: filtered.length,
      itemBuilder: (_, i) {
        final c = filtered[i];
        final ticker = c['ticker'] as String;
        final name = c['name'] as String;
        final price = (c['price'] as num?)?.toDouble();
        final held = _isHeld(ticker);

        return _tickerTile(
          ticker: ticker, name: name, category: 'crypto', held: held,
          trailing: price != null ? Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_fmt.format(price), style: const TextStyle(
                color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
              Text('${(c['change_24h'] as num? ?? 0) >= 0 ? '+' : ''}${((c['change_24h'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)}%',
                style: TextStyle(
                  color: (c['change_24h'] as num? ?? 0) >= 0 ? AppTheme.successColor : AppTheme.errorColor,
                  fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ) : const SizedBox.shrink(),
          onTap: () => _showAddSheet(ticker, name, 'crypto', livePrice: price),
        );
      },
    );
  }

  Widget _buildListTab(List<Map<String, dynamic>> list, String category, bool loading) {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
    }

    final filtered = _search.isEmpty ? list : list.where((t) =>
      (t['ticker'] as String).toLowerCase().contains(_search) ||
      (t['name'] as String).toLowerCase().contains(_search)
    ).toList();

    if (filtered.isEmpty) {
      return Center(child: Text(
        _search.isEmpty ? 'No listings available' : 'No results for "$_search"',
        style: const TextStyle(color: AppTheme.textHint, fontSize: 14)));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: filtered.length,
      itemBuilder: (_, i) {
        final t = filtered[i];
        final ticker = t['ticker'] as String;
        final name = t['name'] as String;
        final exchange = t['exchange'] as String? ?? '';
        final held = _isHeld(ticker);

        return _tickerTile(
          ticker: ticker, name: name, category: category, held: held,
          trailing: Text(exchange, style: const TextStyle(color: AppTheme.textHint, fontSize: 10)),
          onTap: () => _showAddSheet(ticker, name, category),
        );
      },
    );
  }

  Widget _tickerTile({
    required String ticker, required String name, required String category,
    required bool held, required Widget trailing, required VoidCallback onTap,
  }) {
    final color = _catColor(category);
    return GestureDetector(
      onTap: held ? null : onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: held ? AppTheme.surfaceColor.withValues(alpha: 0.5) : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: held ? color.withValues(alpha: 0.3) : AppTheme.glassBorderColor)),
        child: Row(children: [
          Text(_catEmoji(category), style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Flexible(child: Text(ticker, style: const TextStyle(
                  color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis)),
                if (held) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4)),
                    child: const Text('HELD', style: TextStyle(
                      color: AppTheme.successColor, fontSize: 8, fontWeight: FontWeight.w800)),
                  ),
                ],
              ]),
              Text(name, style: const TextStyle(color: AppTheme.textHint, fontSize: 11),
                overflow: TextOverflow.ellipsis),
            ],
          )),
          const SizedBox(width: 8),
          trailing,
          if (!held) ...[
            const SizedBox(width: 8),
            const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primaryColor, size: 22),
          ],
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ADD HOLDING BOTTOM SHEET
// Extracted as its own StatefulWidget so TextEditingControllers
// are disposed by Flutter's own State.dispose() lifecycle —
// guaranteed to run only after the sheet's Elements are fully
// unmounted, avoiding manual timing/dispose-ordering bugs.
// ─────────────────────────────────────────────
class _AddHoldingSheet extends StatefulWidget {
  final String ticker;
  final String name;
  final String category;
  final double? livePrice;
  final InvestApi api;
  final NumberFormat fmt;
  final String Function(String) catEmoji;
  final Color Function(String) catColor;

  const _AddHoldingSheet({
    required this.ticker,
    required this.name,
    required this.category,
    required this.livePrice,
    required this.api,
    required this.fmt,
    required this.catEmoji,
    required this.catColor,
  });

  @override
  State<_AddHoldingSheet> createState() => _AddHoldingSheetState();
}

class _AddHoldingSheetState extends State<_AddHoldingSheet> {
  late final TextEditingController _unitsCtrl;
  late final TextEditingController _buyCtrl;
  late final TextEditingController _priceCtrl;
  bool _fetching = false;

  @override
  void initState() {
    super.initState();
    _unitsCtrl = TextEditingController();
    _buyCtrl = TextEditingController();
    _priceCtrl = TextEditingController(text: widget.livePrice?.toStringAsFixed(2) ?? '');

    if (widget.livePrice == null) {
      _fetching = true;
      widget.api.getStockQuote(widget.ticker).then((data) {
        if (!mounted) return;
        setState(() {
          if (data['price'] != null) {
            _priceCtrl.text = (data['price'] as num).toStringAsFixed(2);
          }
          _fetching = false;
        });
      }).catchError((_) {
        if (mounted) setState(() => _fetching = false);
      });
    }
  }

  @override
  void dispose() {
    _unitsCtrl.dispose();
    _buyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Widget _inputField(TextEditingController ctrl, String hint, IconData icon) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.textHint, fontSize: 13),
        prefixIcon: Icon(icon, color: AppTheme.textHint, size: 20),
        filled: true, fillColor: AppTheme.surfaceColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.glassBorderColor)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.glassBorderColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryColor)),
      ),
    );
  }

  Widget _priceDisplay() {
    final livePrice = widget.livePrice;
    if (livePrice != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.show_chart_rounded, color: AppTheme.successColor, size: 20),
          const SizedBox(width: 12),
          Text('Current price: ${widget.fmt.format(livePrice)}', style: const TextStyle(
            color: AppTheme.successColor, fontSize: 14, fontWeight: FontWeight.w600)),
        ]),
      );
    }
    if (_fetching) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.glassBorderColor),
        ),
        child: const Row(children: [
          Icon(Icons.show_chart_rounded, color: AppTheme.textHint, size: 20),
          SizedBox(width: 12),
          Text('Fetching current price...', style: TextStyle(
            color: AppTheme.textHint, fontSize: 13)),
          SizedBox(width: 8),
          SizedBox(width: 14, height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor)),
        ]),
      );
    }
    if (_priceCtrl.text.isNotEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.show_chart_rounded, color: AppTheme.successColor, size: 20),
          const SizedBox(width: 12),
          Text('Current price: \$${_priceCtrl.text}', style: const TextStyle(
            color: AppTheme.successColor, fontSize: 14, fontWeight: FontWeight.w600)),
        ]),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _inputField(_priceCtrl, 'Current price (\$)', Icons.show_chart_rounded),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text('Real-time price temporarily unavailable',
            style: TextStyle(color: AppTheme.textHint.withValues(alpha: 0.5), fontSize: 10)),
        ),
      ],
    );
  }

  void _onAdd() {
    final units = double.tryParse(_unitsCtrl.text);
    final buy = double.tryParse(_buyCtrl.text);
    final current = double.tryParse(_priceCtrl.text);
    if (units == null || units <= 0) return;
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.pop(context, {
      'asset_name': widget.name,
      'ticker': widget.ticker,
      'category': widget.category,
      'units': units,
      'purchase_price': buy ?? 0,
      'current_price': current ?? widget.livePrice ?? buy ?? 0,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(
          color: AppTheme.textHint.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: widget.catColor(widget.category).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12)),
            child: Text(widget.catEmoji(widget.category), style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.ticker, style: const TextStyle(
                color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
              Text(widget.name, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            ],
          )),
          if (widget.livePrice != null)
            Text(widget.fmt.format(widget.livePrice), style: const TextStyle(
              color: AppTheme.successColor, fontSize: 16, fontWeight: FontWeight.w700))
          else if (_fetching)
            const SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor)),
        ]),
        const SizedBox(height: 24),
        _inputField(_unitsCtrl, 'Units (quantity)', Icons.layers_outlined),
        const SizedBox(height: 12),
        _inputField(_buyCtrl, 'Average buy price (\$)', Icons.payments_outlined),
        const SizedBox(height: 12),
        _priceDisplay(),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: _onAdd,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: AppTheme.goldGradient, borderRadius: BorderRadius.circular(14)),
            child: const Center(child: Text('Add to Portfolio', style: TextStyle(
              color: Color(0xFF0A0800), fontSize: 15, fontWeight: FontWeight.w700))),
          ),
        ),
      ]),
    );
  }
}
