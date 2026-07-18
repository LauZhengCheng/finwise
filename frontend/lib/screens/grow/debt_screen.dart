// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : debt_screen.dart
// Description   : Debt management screen — list, add, and delete debts,
//                 with total summary and minimum payment breakdown
// First Written : 17-06-2026
// Edited on     : 17-06-2026
// ============================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/app_theme.dart';
import '../../widgets/shimmer_loading.dart';
import '../../providers/debt_provider.dart';

class DebtScreen extends ConsumerStatefulWidget {
  const DebtScreen({super.key});

  @override
  ConsumerState<DebtScreen> createState() => _DebtScreenState();
}

class _DebtScreenState extends ConsumerState<DebtScreen> {
  final _currencyFmt = NumberFormat.currency(
    locale: 'ms_MY',
    symbol: 'RM ',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(debtProvider.notifier).fetchDebts();
    });
  }

  Color _chipColor(String debtType) {
    switch (debtType) {
      case 'credit_card':
        return AppTheme.errorColor;
      case 'bnpl':
        return const Color(0xFFF59E0B);
      case 'personal_loan':
        return const Color(0xFF5090E0);
      default:
        return AppTheme.textSecondary;
    }
  }

  String _debtTypeLabel(String debtType) {
    switch (debtType) {
      case 'personal_loan':
        return 'Personal Loan';
      case 'credit_card':
        return 'Credit Card';
      case 'bnpl':
        return 'BNPL';
      case 'car_loan':
        return 'Car Loan';
      case 'home_loan':
        return 'Home Loan';
      case 'student_loan':
        return 'Student Loan';
      default:
        return 'Other';
    }
  }

  void _showAddDebtSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddDebtSheet(
        onSubmit: (data) async {
          await ref.read(debtProvider.notifier).createDebt(data);
        },
      ),
    );
  }

  void _showEditBalance(String id, String name, double currentBalance) {
    final ctrl = TextEditingController(text: currentBalance.toStringAsFixed(2));
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppTheme.cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(
            color: AppTheme.textHint.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Text('Update Balance', style: const TextStyle(
            color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(name, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 20),
          TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18),
            decoration: InputDecoration(
              prefixText: 'RM ',
              prefixStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 18),
              filled: true, fillColor: AppTheme.surfaceColor,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.glassBorderColor)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.glassBorderColor)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primaryColor)),
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () async {
              final newBalance = double.tryParse(ctrl.text);
              if (newBalance == null) return;
              Navigator.pop(ctx);
              try {
                await ref.read(debtProvider.notifier).updateDebt(id, {'current_balance': newBalance});
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to update balance'), backgroundColor: AppTheme.errorColor));
                }
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(gradient: AppTheme.goldGradient, borderRadius: BorderRadius.circular(14)),
              child: const Center(child: Text('Update', style: TextStyle(
                color: Color(0xFF0A0800), fontSize: 15, fontWeight: FontWeight.w700))),
            ),
          ),
        ]),
      ),
    ).then((_) => ctrl.dispose());
  }

  Future<void> _confirmDelete(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text(
          'Delete Debt',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          'Remove "$name" from your debt list?',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => ctx.pop(true),
            child: const Text('Delete',
                style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        await ref.read(debtProvider.notifier).deleteDebt(id);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete debt')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final debtState = ref.watch(debtProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: DecoratedBox(
        decoration:
            const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ──
              Padding(
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
                      'Debt Management',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: debtState.isLoading
                    ? const Padding(padding: EdgeInsets.all(16), child: SkeletonTransactionList(count: 4))
                    : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: [
                          // ── Summary card ──
                          _SummaryCard(
                            totalBalance: debtState.totalBalance,
                            totalMinimum: debtState.totalMinimumPayment,
                            monthlyInterest: debtState.monthlyInterestCost,
                            debtCount: debtState.debtCount,
                            currencyFmt: _currencyFmt,
                          ),
                          const SizedBox(height: 16),

                          // ── Add + Strategy buttons ──
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _showAddDebtSheet,
                                  icon: const Icon(Icons.add_rounded,
                                      color: AppTheme.primaryColor, size: 18),
                                  label: const Text('Add Debt'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.primaryColor,
                                    side: const BorderSide(
                                        color: AppTheme.primaryColor, width: 1.5),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14)),
                                    minimumSize: const Size(0, 48),
                                  ),
                                ),
                              ),
                              if (debtState.debts.isNotEmpty) ...[
                                const SizedBox(width: 12),
                                GestureDetector(
                                  onTap: () => context.push('/grow/debt/strategy'),
                                  child: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      gradient: AppTheme.goldGradient,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(
                                      Icons.auto_awesome_rounded,
                                      color: Color(0xFF0A0A0F),
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 20),

                          // ── Debt list or empty state ──
                          if (debtState.debts.isEmpty)
                            _EmptyState()
                          else
                            ...debtState.debts.map((debt) {
                              final id = debt['id'] as String? ?? '';
                              final name =
                                  debt['name'] as String? ?? 'Unknown';
                              final type =
                                  debt['debt_type'] as String? ?? 'other';
                              final balance =
                                  (debt['current_balance'] as num?)
                                          ?.toDouble() ??
                                      0.0;
                              final principal =
                                  (debt['principal_amount'] as num?)
                                          ?.toDouble() ??
                                      balance;
                              final rate =
                                  (debt['interest_rate'] as num?)
                                      ?.toDouble();
                              final minPay =
                                  (debt['minimum_payment'] as num?)
                                      ?.toDouble();
                              final dueDay = debt['due_date'] as int?;
                              final lender = debt['lender'] as String?;
                              final remainingMonths = debt['remaining_months'] as int?;
                              final notes = debt['notes'] as String?;
                              final calc = debt['calculated'] as Map<String, dynamic>? ?? {};
                              final monthlyInterestCost = (calc['monthly_interest_cost'] as num?)?.toDouble();

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _DebtCard(
                                  onDelete: () => _confirmDelete(id, name),
                                  onEditBalance: () => _showEditBalance(id, name, balance),
                                  name: name,
                                  balance: balance,
                                  principal: principal,
                                  interestRate: rate,
                                  minimumPayment: minPay,
                                  monthlyInterestCost: monthlyInterestCost,
                                  dueDay: dueDay,
                                  lender: lender,
                                  remainingMonths: remainingMonths,
                                  notes: notes,
                                  chipColor: _chipColor(type),
                                  typeLabel: _debtTypeLabel(type),
                                  currencyFmt: _currencyFmt,
                                ),
                              );
                            }),
                          const SizedBox(height: 32),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SUMMARY CARD
// ─────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final double totalBalance;
  final double totalMinimum;
  final double monthlyInterest;
  final int debtCount;
  final NumberFormat currencyFmt;

  const _SummaryCard({
    required this.totalBalance,
    required this.totalMinimum,
    required this.monthlyInterest,
    required this.debtCount,
    required this.currencyFmt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassCard(radius: 20, goldBorder: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'TOTAL DEBT',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Text(
                '$debtCount active',
                style: const TextStyle(color: AppTheme.textHint, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            currencyFmt.format(totalBalance),
            style: const TextStyle(
              color: AppTheme.errorColor,
              fontSize: 32,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: AppTheme.glassBorderColor),
          const SizedBox(height: 12),
          _SummaryRow(
            icon: Icons.calendar_today_rounded,
            label: 'Monthly minimums',
            value: currencyFmt.format(totalMinimum),
          ),
          const SizedBox(height: 8),
          _SummaryRow(
            icon: Icons.trending_up_rounded,
            label: 'Monthly interest cost',
            value: currencyFmt.format(monthlyInterest),
            valueColor: AppTheme.errorColor,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.textSecondary, size: 16),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        const Spacer(),
        Text(value, style: TextStyle(
          color: valueColor ?? AppTheme.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        )),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// DEBT CARD
// ─────────────────────────────────────────────
class _DebtCard extends StatelessWidget {
  final String name;
  final double balance;
  final double principal;
  final double? interestRate;
  final double? minimumPayment;
  final double? monthlyInterestCost;
  final int? dueDay;
  final String? lender;
  final int? remainingMonths;
  final String? notes;
  final Color chipColor;
  final String typeLabel;
  final NumberFormat currencyFmt;
  final VoidCallback? onDelete;
  final VoidCallback? onEditBalance;

  const _DebtCard({
    required this.name,
    required this.balance,
    required this.principal,
    required this.interestRate,
    required this.minimumPayment,
    this.monthlyInterestCost,
    required this.dueDay,
    this.lender,
    this.remainingMonths,
    required this.notes,
    required this.chipColor,
    required this.typeLabel,
    required this.currencyFmt,
    this.onDelete,
    this.onEditBalance,
  });

  @override
  Widget build(BuildContext context) {
    final paidRatio = principal > 0
        ? ((principal - balance) / principal).clamp(0.0, 1.0)
        : 0.0;
    final paidPct = (paidRatio * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.glassBorderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (lender != null && lender!.isNotEmpty)
                      Text(
                        lender!,
                        style: const TextStyle(color: AppTheme.textHint, fontSize: 12),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: chipColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: chipColor.withValues(alpha: 0.4), width: 1),
                    ),
                    child: Text(
                      typeLabel,
                      style: TextStyle(color: chipColor, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (minimumPayment != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '${currencyFmt.format(minimumPayment!)}/mo',
                        style: const TextStyle(color: AppTheme.primaryColor, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            currencyFmt.format(balance),
            style: const TextStyle(color: AppTheme.errorColor, fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${currencyFmt.format(principal - balance)} paid off of ${currencyFmt.format(principal)}',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: paidRatio,
              backgroundColor: AppTheme.glassBorderColor,
              valueColor: AlwaysStoppedAnimation<Color>(
                paidPct >= 80 ? AppTheme.successColor : AppTheme.primaryColor,
              ),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$paidPct% cleared${remainingMonths != null ? ' · ~$remainingMonths months left' : ''}',
            style: const TextStyle(color: AppTheme.textHint, fontSize: 11),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              if (interestRate != null)
                _InfoChip(icon: Icons.percent_rounded, label: '${interestRate!.toStringAsFixed(1)}% p.a.'),
              if (monthlyInterestCost != null && monthlyInterestCost! > 0)
                _InfoChip(icon: Icons.trending_up_rounded, label: '${currencyFmt.format(monthlyInterestCost!)} interest/mo'),
              if (dueDay != null)
                _InfoChip(icon: Icons.event_rounded, label: 'Due day $dueDay'),
            ],
          ),
          if (notes != null && notes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(notes!, style: const TextStyle(color: AppTheme.textHint, fontSize: 12)),
          ],
          if (onDelete != null) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'delete') onDelete!();
                  if (v == 'update') onEditBalance?.call();
                },
                icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textHint, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: AppTheme.surfaceColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'update',
                    child: Row(
                      children: [
                        Icon(Icons.edit_rounded, color: AppTheme.primaryColor, size: 18),
                        SizedBox(width: 8),
                        Text('Update Balance', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, color: AppTheme.errorColor, size: 18),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: AppTheme.errorColor, fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppTheme.textSecondary, size: 13),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
              color: AppTheme.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: const [
            Icon(Icons.check_circle_outline_rounded,
                color: AppTheme.successColor, size: 56),
            SizedBox(height: 16),
            Text(
              "No debts tracked — you're clear!",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ADD DEBT BOTTOM SHEET
// ─────────────────────────────────────────────
class _AddDebtSheet extends StatefulWidget {
  final Future<void> Function(Map<String, dynamic> data) onSubmit;

  const _AddDebtSheet({required this.onSubmit});

  @override
  State<_AddDebtSheet> createState() => _AddDebtSheetState();
}

class _AddDebtSheetState extends State<_AddDebtSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _lenderCtrl = TextEditingController();
  final _principalCtrl = TextEditingController();
  final _currentBalanceCtrl = TextEditingController();
  final _interestRateCtrl = TextEditingController();
  final _minimumPaymentCtrl = TextEditingController();
  final _termMonthsCtrl = TextEditingController();
  final _collateralCtrl = TextEditingController();
  final _dueDayCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _selectedType = 'personal_loan';
  bool _isSubmitting = false;

  static const _debtTypes = [
    ('personal_loan', 'Personal Loan'),
    ('credit_card', 'Credit Card'),
    ('bnpl', 'BNPL'),
    ('car_loan', 'Car Loan'),
    ('home_loan', 'Home Loan'),
    ('student_loan', 'Student Loan'),
    ('other', 'Other'),
  ];

  bool get _isCreditCard => _selectedType == 'credit_card';
  bool get _isBNPL => _selectedType == 'bnpl';
  bool get _hasCollateral => _selectedType == 'car_loan' || _selectedType == 'home_loan';
  bool get _isFixedLoan => !_isCreditCard;

  String get _lenderLabel {
    if (_isBNPL) return 'Platform';
    return 'Lender';
  }

  String get _principalLabel {
    if (_isCreditCard) return 'Total Outstanding (RM)';
    if (_isBNPL) return 'Total Amount (RM)';
    return 'Principal Amount (RM)';
  }

  String get _balanceLabel {
    if (_isCreditCard) return 'Current Statement Balance (RM)';
    return 'Current Balance Owing (RM)';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _lenderCtrl.dispose();
    _principalCtrl.dispose();
    _currentBalanceCtrl.dispose();
    _interestRateCtrl.dispose();
    _minimumPaymentCtrl.dispose();
    _termMonthsCtrl.dispose();
    _collateralCtrl.dispose();
    _dueDayCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _onTypeChanged(String? v) {
    if (v == null) return;
    setState(() {
      _selectedType = v;
      if (_isBNPL) _interestRateCtrl.text = '0';
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      final dueDay = _dueDayCtrl.text.trim().isEmpty
          ? null : int.tryParse(_dueDayCtrl.text.trim());
      final termMonths = _termMonthsCtrl.text.trim().isEmpty
          ? null : int.tryParse(_termMonthsCtrl.text.trim());
      await widget.onSubmit({
        'name': _nameCtrl.text.trim(),
        'debt_type': _selectedType,
        if (_lenderCtrl.text.trim().isNotEmpty)
          'lender': _lenderCtrl.text.trim(),
        'principal_amount': double.parse(_principalCtrl.text.trim()),
        'current_balance': double.parse(_currentBalanceCtrl.text.trim()),
        'interest_rate': double.parse(_interestRateCtrl.text.trim()),
        if (_minimumPaymentCtrl.text.trim().isNotEmpty)
          'minimum_payment': double.parse(_minimumPaymentCtrl.text.trim()),
        if (termMonths != null) 'term_months': termMonths,
        if (_hasCollateral && _collateralCtrl.text.trim().isNotEmpty)
          'collateral': _collateralCtrl.text.trim(),
        if (dueDay != null) 'due_date': dueDay,
        if (_notesCtrl.text.trim().isNotEmpty)
          'notes': _notesCtrl.text.trim(),
      });
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add debt: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text('Add Debt', style: TextStyle(
                    color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Debt type (always first — controls which fields show)
              DropdownButtonFormField<String>(
                initialValue: _selectedType,
                dropdownColor: AppTheme.cardColor,
                decoration: _inputDecoration('Debt Type'),
                style: const TextStyle(color: AppTheme.textPrimary),
                items: _debtTypes.map((t) =>
                  DropdownMenuItem(value: t.$1, child: Text(t.$2))).toList(),
                onChanged: _onTypeChanged,
              ),
              const SizedBox(height: 14),

              // ── Name
              _buildField(
                controller: _nameCtrl,
                label: 'Debt Name',
                hint: _isCreditCard ? 'e.g. Maybank Visa Gold' : _isBNPL ? 'e.g. iPhone 15 installment' : 'e.g. Maybank Car Loan',
                required: true,
              ),
              const SizedBox(height: 14),

              // ── Lender / Platform
              _buildField(controller: _lenderCtrl, label: _lenderLabel,
                hint: _isBNPL ? 'e.g. Atome, Grab PayLater' : 'e.g. Maybank, CIMB', required: true),
              const SizedBox(height: 14),

              // ── Principal / Total amount
              _buildField(controller: _principalCtrl, label: _principalLabel,
                hint: _isBNPL ? '2000' : '50000', required: true, keyboardType: TextInputType.number),
              const SizedBox(height: 14),

              // ── Current balance
              _buildField(controller: _currentBalanceCtrl, label: _balanceLabel,
                hint: _isCreditCard ? '10000' : '35000', required: true, keyboardType: TextInputType.number),
              const SizedBox(height: 14),

              // ── Interest rate
              _buildField(controller: _interestRateCtrl,
                label: _isBNPL ? 'Interest Rate (% p.a.) — usually 0%' : 'Interest Rate (% p.a.)',
                hint: _isCreditCard ? '18' : _isBNPL ? '0' : '3.5',
                required: true, keyboardType: TextInputType.number),
              const SizedBox(height: 14),

              // ── Credit card: minimum payment (reference for AI)
              if (_isCreditCard) ...[
                _buildField(controller: _minimumPaymentCtrl,
                  label: 'Minimum Payment from Statement (RM)',
                  hint: '500', required: true, keyboardType: TextInputType.number),
                const SizedBox(height: 6),
                const Text(
                  'This is the floor — Aion will recommend how much more to pay based on your budget.',
                  style: TextStyle(color: AppTheme.textHint, fontSize: 11)),
                const SizedBox(height: 14),
              ],

              // ── Fixed loans + BNPL: term
              if (_isFixedLoan) ...[
                _buildField(controller: _termMonthsCtrl,
                  label: _isBNPL ? 'Number of Installments (months)' : 'Loan Term (months)',
                  hint: _isBNPL ? '6' : '84', required: true, keyboardType: TextInputType.number),
                const SizedBox(height: 6),
                const Text(
                  'Monthly payment will be auto-calculated from this.',
                  style: TextStyle(color: AppTheme.textHint, fontSize: 11)),
                const SizedBox(height: 14),
              ],

              // ── Car / Home: collateral
              if (_hasCollateral) ...[
                _buildField(controller: _collateralCtrl,
                  label: 'Collateral',
                  hint: _selectedType == 'car_loan' ? 'e.g. 2022 Honda City' : 'e.g. Condo Unit 12-3, PJ'),
                const SizedBox(height: 14),
              ],

              // ── Due day (all types)
              _buildField(controller: _dueDayCtrl, label: 'Payment Due Day', hint: '15',
                required: true, keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Due day is required';
                  final n = int.tryParse(v);
                  if (n == null || n < 1 || n > 31) return 'Enter 1–31';
                  return null;
                }),
              const SizedBox(height: 14),

              // ── Notes (all types, optional)
              _buildField(controller: _notesCtrl, label: 'Notes (optional)',
                hint: _isBNPL ? 'e.g. 0% promo ends Dec 2026' : 'Any additional details', maxLines: 2),
              const SizedBox(height: 24),

              // ── Submit
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: AppTheme.backgroundColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isSubmitting
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(color: AppTheme.backgroundColor, strokeWidth: 2))
                    : const Text('Add Debt', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AppTheme.cardColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.glassBorderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.glassBorderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
            const BorderSide(color: AppTheme.primaryColor, width: 1.5),
      ),
      labelStyle: const TextStyle(color: AppTheme.textSecondary),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool required = false,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: AppTheme.cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.glassBorderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.glassBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
              color: AppTheme.primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.errorColor),
        ),
        hintStyle:
            const TextStyle(color: AppTheme.textHint, fontSize: 14),
        labelStyle: const TextStyle(color: AppTheme.textSecondary),
      ),
      validator: validator ??
          (v) {
            if (required && (v == null || v.trim().isEmpty)) {
              return 'This field is required';
            }
            return null;
          },
    );
  }
}
