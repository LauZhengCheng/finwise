// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : fd_marketplace_screen.dart
// Description   : Fixed deposit rate comparison marketplace.
//                 User inputs deposit amount + tenure, sees
//                 interest earned per bank. Apply opens in-app browser.
// First Written : 17-06-2026
// Edited on     : 21-06-2026
// ============================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_theme.dart';
import '../../services/api/finance_api.dart';
import '../../widgets/shimmer_loading.dart';

class FdMarketplaceScreen extends StatefulWidget {
  const FdMarketplaceScreen({super.key});

  @override
  State<FdMarketplaceScreen> createState() => _FdMarketplaceScreenState();
}

class _FdMarketplaceScreenState extends State<FdMarketplaceScreen> {
  final _fmt = NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ', decimalDigits: 2);
  final _amountCtrl = TextEditingController(text: '10000');

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _allRates = [];

  int _selectedTenure = 0; // 0 = all
  String _typeFilter = 'all'; // all, conventional, islamic
  static const _tenures = [0, 3, 6, 12, 24];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final response = await FinanceApi().getFDRates();
      if (!mounted) return;
      setState(() {
        _allRates = (response['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
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

  List<Map<String, dynamic>> get _filtered {
    var list = _allRates;
    if (_selectedTenure > 0) {
      list = list.where((r) => r['tenure_months'] == _selectedTenure).toList();
    }
    if (_typeFilter == 'conventional') {
      list = list.where((r) => r['is_islamic'] != true).toList();
    } else if (_typeFilter == 'islamic') {
      list = list.where((r) => r['is_islamic'] == true).toList();
    }
    list.sort((a, b) =>
      ((b['interest_rate'] as num?)?.toDouble() ?? 0)
          .compareTo((a['interest_rate'] as num?)?.toDouble() ?? 0));
    return list;
  }

  double _calcInterest(double rate, int? tenure) {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    final months = tenure ?? 12;
    return amount * (rate / 100) * (months / 12);
  }

  Color _bankColor(String bank) {
    final hash = bank.hashCode;
    final colors = [
      const Color(0xFF5090E0), const Color(0xFF7C3AED), const Color(0xFFE05050),
      const Color(0xFF059669), const Color(0xFFF59E0B), const Color(0xFFEC4899),
    ];
    return colors[hash.abs() % colors.length];
  }

  static const _bankDomains = {
    'maybank': 'maybank.com',
    'cimb': 'cimb.com',
    'public bank': 'publicbank.com.my',
    'rhb': 'rhb.com.my',
    'hong leong': 'hlb.com.my',
    'ambank': 'ambank.com.my',
    'uob': 'uob.com.my',
    'ocbc': 'ocbc.com.my',
    'hsbc': 'hsbc.com.my',
    'standard chartered': 'sc.com',
    'bank islam': 'bankislam.com',
    'bank rakyat': 'bankrakyat.com.my',
    'affin': 'affinbank.com.my',
    'alliance': 'alliancebank.com.my',
    'bsn': 'bsn.com.my',
    'agro': 'agrobank.com.my',
    'bank of china': 'bankofchina.com',
    'citibank': 'citibank.com',
    'mbsb': 'mbsb.com.my',
    'muamalat': 'muamalat.com.my',
  };

  String? _bankLogoUrl(String bank) {
    final lower = bank.toLowerCase();
    for (final entry in _bankDomains.entries) {
      if (lower.contains(entry.key)) {
        return 'https://logo.clearbit.com/${entry.value}';
      }
    }
    return null;
  }

  static const _bankWebsites = {
    'affin islamic': 'https://www.affinalways.com',
    'affinbank': 'https://www.affinalways.com',
    'affin': 'https://www.affinalways.com',
    'alliance': 'https://www.alliancebank.com.my',
    'ambank islamic': 'https://www.ambank.com.my',
    'ambank': 'https://www.ambank.com.my',
    'bank islam': 'https://www.bankislam.com',
    'bank of china': 'https://www.bankofchina.com.my/',
    'cimb islamic': 'https://www.cimb.com.my',
    'cimb': 'https://www.cimb.com.my',
    'hong leong': 'https://www.hlb.com.my',
    'hsbc': 'https://www.hsbc.com.my',
    'maybank islamic': 'https://www.maybank2u.com.my',
    'maybank': 'https://www.maybank2u.com.my',
    'mbsb': 'https://www.mbsb.com.my',
    'ocbc': 'https://www.ocbc.com.my',
    'public islamic': 'https://www.pbebank.com',
    'public bank': 'https://www.pbebank.com',
    'rhb islamic': 'https://www.rhb.com.my',
    'rhb': 'https://www.rhb.com.my',
    'standard chartered': 'https://www.sc.com/my',
    'stashaway': 'https://www.stashaway.my',
    'uob': 'https://www.uob.com.my',
  };

  Future<void> _openApply(String bank, String? applyUrl) async {
    // Priority: backend's specific iMoney link > bank website > iMoney general
    String url;
    if (applyUrl != null && applyUrl.isNotEmpty && applyUrl != 'https://www.imoney.my/fixed-deposit') {
      url = applyUrl;
    } else {
      final lower = bank.toLowerCase();
      url = 'https://www.imoney.my/fixed-deposit';
      for (final entry in _bankWebsites.entries) {
        if (lower.contains(entry.key)) { url = entry.value; break; }
      }
    }
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView);
    } catch (_) {}
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
                    const Text('FD Marketplace', style: TextStyle(
                      color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Input section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.glassBorderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('I would like to deposit', style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          // Amount input
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: _amountCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              onChanged: (_) => setState(() {}),
                              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                              decoration: InputDecoration(
                                prefixText: 'RM ',
                                prefixStyle: const TextStyle(color: AppTheme.primaryColor, fontSize: 16, fontWeight: FontWeight.w600),
                                filled: true, fillColor: AppTheme.surfaceColor,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppTheme.glassBorderColor)),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppTheme.glassBorderColor)),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppTheme.primaryColor)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text('over', style: TextStyle(color: AppTheme.textHint, fontSize: 13)),
                          const SizedBox(width: 10),
                          // Tenure dropdown
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.glassBorderColor),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: _selectedTenure,
                                  dropdownColor: AppTheme.cardColor,
                                  isExpanded: true,
                                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                                  items: _tenures.map((t) => DropdownMenuItem(
                                    value: t,
                                    child: Text(t == 0 ? 'All' : '$t months',
                                      style: const TextStyle(fontSize: 13)),
                                  )).toList(),
                                  onChanged: (v) => setState(() => _selectedTenure = v ?? 0),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Type toggle
                      Row(
                        children: [
                          _TypeChip(label: 'All', active: _typeFilter == 'all',
                            onTap: () => setState(() => _typeFilter = 'all')),
                          const SizedBox(width: 8),
                          _TypeChip(label: 'Conventional', active: _typeFilter == 'conventional',
                            onTap: () => setState(() => _typeFilter = 'conventional')),
                          const SizedBox(width: 8),
                          _TypeChip(label: 'Islamic', active: _typeFilter == 'islamic',
                            onTap: () => setState(() => _typeFilter = 'islamic')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Results
              Expanded(
                child: _loading
                    ? const Padding(padding: EdgeInsets.all(20), child: SkeletonTransactionList(count: 5))
                    : _error != null
                        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.error_outline_rounded, color: AppTheme.errorColor, size: 48),
                            const SizedBox(height: 12),
                            Text(_error!, style: const TextStyle(color: AppTheme.textSecondary)),
                            const SizedBox(height: 16),
                            TextButton(onPressed: _load, child: const Text('Retry',
                              style: TextStyle(color: AppTheme.primaryColor))),
                          ]))
                        : _buildList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    final rates = _filtered;

    if (rates.isEmpty) {
      return const Center(child: Text('No FD rates match your filters',
        style: TextStyle(color: AppTheme.textHint, fontSize: 14)));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 108),
      itemCount: rates.length,
      itemBuilder: (context, i) {
        final r = rates[i];
        final bank = r['bank'] as String? ?? 'Unknown';
        final applyUrl = r['apply_url'] as String?;
        final logoUrl = r['logo_url'] as String?;
        final product = r['product'] as String? ?? '';
        final rate = (r['interest_rate'] as num?)?.toDouble() ?? 0;
        final tenure = r['tenure_months'] as int?;
        final minAmount = (r['min_amount'] as num?)?.toDouble();
        final isIslamic = r['is_islamic'] as bool? ?? false;
        final interest = _calcInterest(rate, tenure);
        final isBest = i == 0;
        final color = _bankColor(bank);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isBest ? AppTheme.primaryColor.withValues(alpha: 0.3) : AppTheme.glassBorderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bank name + badges
              Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: (logoUrl != null || _bankLogoUrl(bank) != null)
                        ? Image.network(
                            logoUrl ?? _bankLogoUrl(bank)!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Center(child: Text(
                              bank.isNotEmpty ? bank[0] : '?',
                              style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800),
                            )),
                          )
                        : Center(child: Text(
                            bank.isNotEmpty ? bank[0] : '?',
                            style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800),
                          )),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(bank, style: const TextStyle(
                          color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                        Text(product, style: const TextStyle(
                          color: AppTheme.textHint, fontSize: 11)),
                      ],
                    ),
                  ),
                  if (isBest)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: AppTheme.goldGradient,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('BEST', style: TextStyle(
                        color: Color(0xFF0A0800), fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                    ),
                  if (isIslamic) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('Islamic', style: TextStyle(
                        color: Color(0xFF059669), fontSize: 9, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),

              // Rate + Interest earned
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Interest Rate', style: TextStyle(
                          color: AppTheme.textHint, fontSize: 10)),
                        const SizedBox(height: 2),
                        Text('${rate.toStringAsFixed(2)}% p.a.', style: const TextStyle(
                          color: AppTheme.primaryColor, fontSize: 18, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Interest Earned', style: TextStyle(
                          color: AppTheme.textHint, fontSize: 10)),
                        const SizedBox(height: 2),
                        Text(_fmt.format(interest), style: const TextStyle(
                          color: AppTheme.successColor, fontSize: 16, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Details row + Apply
              Row(
                children: [
                  if (tenure != null)
                    Text('$tenure months', style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
                  if (tenure != null && minAmount != null)
                    const Text(' · ', style: TextStyle(color: AppTheme.textHint)),
                  if (minAmount != null)
                    Text('Min ${_fmt.format(minAmount)}', style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
                  const Spacer(),
                  GestureDetector(
                      onTap: () => _openApply(bank, applyUrl),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Apply', style: TextStyle(
                              color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.w600)),
                            SizedBox(width: 4),
                            Icon(Icons.open_in_new_rounded, color: AppTheme.primaryColor, size: 12),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TypeChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppTheme.primaryColor.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? AppTheme.primaryColor : AppTheme.glassBorderColor),
        ),
        child: Text(label, style: TextStyle(
          color: active ? AppTheme.primaryColor : AppTheme.textSecondary,
          fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
