// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : loan_calculator_screen.dart
// Description   : Loan / EMI calculator — local computation, no API calls.
//                 Supports personal, car and home loan estimation.
// First Written : 17-06-2026
// Edited on     : 17-06-2026
// ============================================

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';

class LoanCalculatorScreen extends StatefulWidget {
  const LoanCalculatorScreen({super.key});

  @override
  State<LoanCalculatorScreen> createState() => _LoanCalculatorScreenState();
}

class _LoanCalculatorScreenState extends State<LoanCalculatorScreen> {
  final _principalCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _tenureCtrl = TextEditingController();

  final _scrollCtrl = ScrollController();
  bool _isFlat = false;
  double? _emi;
  double? _totalPayment;
  double? _totalInterest;
  List<Map<String, double>>? _schedule;
  bool _showSchedule = false;

  String _fmt(double value) {
    final parts = value.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final decPart = parts[1];
    final buf = StringBuffer();
    int count = 0;
    for (int i = intPart.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buf.write(',');
      buf.write(intPart[i]);
      count++;
    }
    return 'RM ${buf.toString().split('').reversed.join()}.$decPart';
  }

  void _calculate() {
    FocusScope.of(context).unfocus();
    final p = double.tryParse(_principalCtrl.text.trim());
    final annualRate = double.tryParse(_rateCtrl.text.trim());
    final n = int.tryParse(_tenureCtrl.text.trim());

    if (p == null || annualRate == null || n == null || p <= 0 || n <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields correctly.')),
      );
      return;
    }

    double emi;
    final schedule = <Map<String, double>>[];

    if (_isFlat) {
      // Flat rate: interest on original principal for entire term
      final totalInterest = p * (annualRate / 100) * (n / 12);
      emi = (p + totalInterest) / n;
      final monthlyInterest = totalInterest / n;
      final monthlyPrincipal = p / n;
      var balance = p;
      for (int m = 1; m <= n; m++) {
        balance -= monthlyPrincipal;
        schedule.add({
          'month': m.toDouble(),
          'payment': emi,
          'principal': monthlyPrincipal,
          'interest': monthlyInterest,
          'balance': balance < 0.01 ? 0 : balance,
        });
      }
    } else {
      // Reducing balance: interest on remaining balance
      if (annualRate == 0) {
        emi = p / n;
        var balance = p;
        for (int m = 1; m <= n; m++) {
          balance -= emi;
          schedule.add({
            'month': m.toDouble(),
            'payment': emi,
            'principal': emi,
            'interest': 0,
            'balance': balance < 0.01 ? 0 : balance,
          });
        }
      } else {
        final r = (annualRate / 100) / 12;
        emi = p * r * pow(1 + r, n) / (pow(1 + r, n) - 1);
        var balance = p;
        for (int m = 1; m <= n; m++) {
          final interest = balance * r;
          final principal = emi - interest;
          balance -= principal;
          schedule.add({
            'month': m.toDouble(),
            'payment': emi,
            'principal': principal,
            'interest': interest,
            'balance': balance < 0.01 ? 0 : balance,
          });
        }
      }
    }

    setState(() {
      _emi = emi;
      _totalPayment = emi * n;
      _totalInterest = (emi * n) - p;
      _schedule = schedule;
      _showSchedule = false;
    });
  }

  void _clear() {
    _principalCtrl.clear();
    _rateCtrl.clear();
    _tenureCtrl.clear();
    setState(() {
      _emi = null;
      _totalPayment = null;
      _totalInterest = null;
      _schedule = null;
      _showSchedule = false;
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _principalCtrl.dispose();
    _rateCtrl.dispose();
    _tenureCtrl.dispose();
    super.dispose();
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
              _buildHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildInputCard(),
                      const SizedBox(height: 16),
                      _buildCalculateButton(),
                      if (_emi != null) ...[
                        const SizedBox(height: 20),
                        _buildResultCard(),
                        if (_schedule != null && _schedule!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildScheduleSection(),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: const Icon(Icons.arrow_back_rounded,
                color: AppTheme.textPrimary, size: 24),
          ),
          const SizedBox(width: 16),
          const Text(
            'Loan Calculator',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.glassBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Loan Details',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() {
                  _isFlat = !_isFlat;
                  _emi = null;
                  _totalPayment = null;
                  _totalInterest = null;
                  _schedule = null;
                  _showSchedule = false;
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.glassBorderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: !_isFlat ? AppTheme.primaryColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text('Reducing', style: TextStyle(
                          color: !_isFlat ? const Color(0xFF0A0800) : AppTheme.textHint,
                          fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _isFlat ? AppTheme.primaryColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text('Flat Rate', style: TextStyle(
                          color: _isFlat ? const Color(0xFF0A0800) : AppTheme.textHint,
                          fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildInputField(
            controller: _principalCtrl,
            label: 'Loan Amount (RM)',
            hint: 'e.g. 50000',
            isDecimal: true,
          ),
          const SizedBox(height: 14),
          _buildInputField(
            controller: _rateCtrl,
            label: 'Annual Interest Rate (%)',
            hint: 'e.g. 5.5',
            isDecimal: true,
          ),
          const SizedBox(height: 14),
          _buildInputField(
            controller: _tenureCtrl,
            label: 'Tenure (Months)',
            hint: 'e.g. 60',
            isDecimal: false,
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isDecimal,
  }) {
    return TextField(
      controller: controller,
      keyboardType:
          TextInputType.numberWithOptions(decimal: isDecimal, signed: false),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
            isDecimal ? RegExp(r'^\d*\.?\d*') : RegExp(r'^\d*')),
      ],
      style: const TextStyle(color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
      ),
    );
  }

  Widget _buildCalculateButton() {
    return GestureDetector(
      onTap: _calculate,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          gradient: AppTheme.goldGradient,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: Text(
            'Calculate',
            style: TextStyle(
              color: AppTheme.backgroundColor,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.35), width: 1),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.08),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Result',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              GestureDetector(
                onTap: _clear,
                child: const Text(
                  'Clear',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: Column(
              children: [
                const Text(
                  'Monthly EMI',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _fmt(_emi!),
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Divider(color: AppTheme.glassBorderColor),
          const SizedBox(height: 16),
          _buildResultRow('Total Payment', _fmt(_totalPayment!)),
          const SizedBox(height: 10),
          _buildResultRow('Total Interest', _fmt(_totalInterest!),
              highlight: true),
          const SizedBox(height: 10),
          _buildResultRow('Rate Type', _isFlat ? 'Flat Rate' : 'Reducing Balance'),
        ],
      ),
    );
  }

  Widget _buildScheduleSection() {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            setState(() => _showSchedule = !_showSchedule);
            if (!_showSchedule) return;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollCtrl.hasClients) {
                _scrollCtrl.animateTo(
                  _scrollCtrl.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                );
              }
            });
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.glassBorderColor),
            ),
            child: Row(
              children: [
                const Icon(Icons.table_chart_rounded, color: AppTheme.primaryColor, size: 18),
                const SizedBox(width: 10),
                const Text('Amortization Schedule', style: TextStyle(
                  color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('${_schedule!.length} months', style: const TextStyle(
                  color: AppTheme.textHint, fontSize: 12)),
                const SizedBox(width: 8),
                Icon(
                  _showSchedule ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.textSecondary, size: 22,
                ),
              ],
            ),
          ),
        ),
        if (_showSchedule) ...[
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.glassBorderColor),
            ),
            child: Column(
              children: [
                // Header row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppTheme.glassBorderColor)),
                  ),
                  child: const Row(
                    children: [
                      SizedBox(width: 36, child: Text('#', style: TextStyle(
                        color: AppTheme.textHint, fontSize: 10, fontWeight: FontWeight.w700))),
                      Expanded(child: Text('Principal', style: TextStyle(
                        color: AppTheme.textHint, fontSize: 10, fontWeight: FontWeight.w700))),
                      Expanded(child: Text('Interest', style: TextStyle(
                        color: AppTheme.textHint, fontSize: 10, fontWeight: FontWeight.w700))),
                      Expanded(child: Text('Balance', textAlign: TextAlign.right, style: TextStyle(
                        color: AppTheme.textHint, fontSize: 10, fontWeight: FontWeight.w700))),
                    ],
                  ),
                ),
                // Schedule rows
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 400),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _schedule!.length,
                    itemBuilder: (context, i) {
                      final row = _schedule![i];
                      final isLast = row['balance'] == 0;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isLast ? AppTheme.successColor.withValues(alpha: 0.08) : null,
                          border: i < _schedule!.length - 1
                              ? const Border(bottom: BorderSide(color: AppTheme.glassBorderColor, width: 0.5))
                              : null,
                        ),
                        child: Row(
                          children: [
                            SizedBox(width: 36, child: Text(
                              '${row['month']!.toInt()}',
                              style: const TextStyle(color: AppTheme.textHint, fontSize: 11),
                            )),
                            Expanded(child: Text(
                              _fmt(row['principal']!),
                              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11),
                            )),
                            Expanded(child: Text(
                              _fmt(row['interest']!),
                              style: const TextStyle(color: AppTheme.errorColor, fontSize: 11),
                            )),
                            Expanded(child: Text(
                              _fmt(row['balance']!),
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: isLast ? AppTheme.successColor : AppTheme.textSecondary,
                                fontSize: 11, fontWeight: isLast ? FontWeight.w700 : FontWeight.normal),
                            )),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildResultRow(String label, String value,
      {bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: highlight ? AppTheme.errorColor : AppTheme.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
