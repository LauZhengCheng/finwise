// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : bill_reminders_screen.dart
// Description   : Bill reminders — upcoming bills list, add bill form,
//                 mark paid, and delete.
// First Written : 17-06-2026
// Edited on     : 17-06-2026
// ============================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/app_theme.dart';
import '../../widgets/shimmer_loading.dart';
import '../../services/api/bills_api.dart';

class BillRemindersScreen extends StatefulWidget {
  const BillRemindersScreen({super.key});

  @override
  State<BillRemindersScreen> createState() => _BillRemindersScreenState();
}

class _BillRemindersScreenState extends State<BillRemindersScreen> {
  final _api = BillsApi();
  final _currency =
      NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ', decimalDigits: 2);
  final _dateFormat = DateFormat('d MMM yyyy');

  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _bills = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _api.getBills();
      if (mounted) {
        setState(() {
          _bills = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  String? _markingPaidId;

  Future<void> _markPaid(String id) async {
    if (_markingPaidId != null) return;
    setState(() => _markingPaidId = id);
    try {
      await _api.updateBill(id, {'is_paid': true});
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppTheme.errorColor,
        ));
      }
    } finally {
      if (mounted) setState(() => _markingPaidId = null);
    }
  }

  Future<void> _delete(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Delete Bill',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text('Remove this bill reminder?',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel',
                  style: TextStyle(color: AppTheme.textSecondary))),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete',
                  style: TextStyle(color: AppTheme.errorColor))),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _api.deleteBill(id);
        await _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppTheme.errorColor,
          ));
        }
      }
    }
  }

  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddBillSheet(
        onSave: (data) async {
          await _api.createBill(data);
          await _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSheet,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: const Color(0xFF0A0800),
        child: const Icon(Icons.add_rounded),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Icon(Icons.arrow_back_rounded,
                          color: AppTheme.textPrimary, size: 24),
                    ),
                    const SizedBox(width: 16),
                    const Text('Bill Reminders',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary)),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Padding(padding: EdgeInsets.all(16), child: SkeletonTransactionList(count: 5))
                    : _error != null
                        ? _ErrorState(error: _error!, onRetry: _load)
                        : _buildList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_bills.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none_rounded,
                size: 56, color: AppTheme.textHint.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text('No bill reminders',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            const Text('Tap + to add upcoming bills',
                style:
                    TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    final unpaid = _bills.where((b) => b['is_paid'] != true).toList();
    final paid = _bills.where((b) => b['is_paid'] == true).toList();

    final now = DateTime.now();
    double totalUnpaid = 0;
    for (final b in unpaid) {
      totalUnpaid += (b['amount'] as num?)?.toDouble() ?? 0;
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.primaryColor,
      backgroundColor: AppTheme.cardColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 140),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary card
            if (unpaid.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppTheme.errorColor.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_rounded,
                        size: 20,
                        color: AppTheme.errorColor.withValues(alpha: 0.8)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${unpaid.length} upcoming bill${unpaid.length > 1 ? 's' : ''} — ${_currency.format(totalUnpaid)} due',
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            if (unpaid.isNotEmpty) const SizedBox(height: 20),

            if (unpaid.isNotEmpty) ...[
              _SectionLabel('UPCOMING (${unpaid.length})'),
              const SizedBox(height: 12),
              ...unpaid.map((b) => _BillCard(
                    data: b,
                    currency: _currency,
                    dateFormat: _dateFormat,
                    now: now,
                    isMarkingPaid: _markingPaidId == b['id'],
                    onMarkPaid: () => _markPaid(b['id'] as String),
                    onDelete: () => _delete(b['id'] as String),
                  )),
              const SizedBox(height: 24),
            ],
            if (paid.isNotEmpty) ...[
              _SectionLabel('PAID (${paid.length})'),
              const SizedBox(height: 12),
              ...paid.map((b) => _BillCard(
                    data: b,
                    currency: _currency,
                    dateFormat: _dateFormat,
                    now: now,
                    onDelete: () => _delete(b['id'] as String),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: AppTheme.textSecondary));
  }
}

class _BillCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final NumberFormat currency;
  final DateFormat dateFormat;
  final DateTime now;
  final bool isMarkingPaid;
  final VoidCallback? onMarkPaid;
  final VoidCallback onDelete;

  const _BillCard({
    required this.data,
    required this.currency,
    required this.dateFormat,
    required this.now,
    this.isMarkingPaid = false,
    this.onMarkPaid,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = data['name'] as String? ?? 'Bill';
    final amount = (data['amount'] as num?)?.toDouble() ?? 0;
    final dueDateStr = data['due_date'] as String?;
    final frequency = data['frequency'] as String? ?? 'monthly';
    final isPaid = data['is_paid'] == true;

    DateTime? dueDate;
    if (dueDateStr != null) dueDate = DateTime.tryParse(dueDateStr);

    int? daysUntil;
    bool isOverdue = false;
    if (dueDate != null && !isPaid) {
      daysUntil = dueDate.difference(now).inDays;
      isOverdue = daysUntil < 0;
    }

    final Color urgencyColor;
    if (isPaid) {
      urgencyColor = AppTheme.successColor;
    } else if (isOverdue) {
      urgencyColor = AppTheme.errorColor;
    } else if (daysUntil != null && daysUntil <= 3) {
      urgencyColor = AppTheme.errorColor;
    } else if (daysUntil != null && daysUntil <= 7) {
      urgencyColor = AppTheme.primaryColor;
    } else {
      urgencyColor = AppTheme.textHint;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isPaid
                ? AppTheme.glassBorderColor
                : urgencyColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: urgencyColor.withValues(alpha: 0.1),
            ),
            child: Icon(
              isPaid
                  ? Icons.check_circle_rounded
                  : Icons.notifications_rounded,
              size: 20,
              color: urgencyColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isPaid
                            ? AppTheme.textHint
                            : AppTheme.textPrimary,
                        decoration:
                            isPaid ? TextDecoration.lineThrough : null)),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Text(
                      dueDate != null ? dateFormat.format(dueDate) : '—',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color:
                            AppTheme.glassBorderColor.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        frequency[0].toUpperCase() + frequency.substring(1),
                        style: const TextStyle(
                            fontSize: 10, color: AppTheme.textHint),
                      ),
                    ),
                    if (!isPaid && daysUntil != null)
                      Text(
                        isOverdue
                            ? 'Overdue!'
                            : daysUntil == 0
                                ? 'Due today'
                                : 'in $daysUntil days',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: urgencyColor),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                currency.format(amount),
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isPaid && onMarkPaid != null)
                    GestureDetector(
                      onTap: isMarkingPaid ? null : onMarkPaid,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color:
                              AppTheme.successColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: AppTheme.successColor
                                  .withValues(alpha: 0.3)),
                        ),
                        child: isMarkingPaid
                            ? const SizedBox(width: 14, height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.successColor))
                            : const Text('Paid',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.successColor)),
                      ),
                    ),
                  if (!isPaid && onMarkPaid != null) const SizedBox(width: 6),
                  GestureDetector(
                    onTap: onDelete,
                    child: const Icon(Icons.delete_outline_rounded,
                        size: 18, color: AppTheme.textHint),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddBillSheet extends StatefulWidget {
  final Future<void> Function(Map<String, dynamic>) onSave;
  const _AddBillSheet({required this.onSave});

  @override
  State<_AddBillSheet> createState() => _AddBillSheetState();
}

class _AddBillSheetState extends State<_AddBillSheet> {
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  String _frequency = 'monthly';
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  bool _isSaving = false;
  String? _error;

  static const _frequencies = ['monthly', 'quarterly', 'annually'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Bill name is required');
      return;
    }
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await widget.onSave({
        'name': _nameCtrl.text.trim(),
        'amount': amount,
        'due_date': _dueDate.toIso8601String().split('T').first,
        'frequency': _frequency,
      });
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy');
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          left: 24,
          right: 24,
          top: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Add Bill Reminder',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(Icons.close_rounded,
                    color: AppTheme.textSecondary, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _Field(
              label: 'Bill name *',
              controller: _nameCtrl,
              hint: 'e.g. Netflix, Gym, Rent'),
          const SizedBox(height: 12),
          _Field(
              label: 'Amount (RM) *',
              controller: _amountCtrl,
              hint: '0.00',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true)),
          const SizedBox(height: 12),
          // Due date
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Due date *',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary)),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.glassBorderColor),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 8),
                      Text(fmt.format(_dueDate),
                          style: const TextStyle(
                              fontSize: 14, color: AppTheme.textPrimary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Frequency
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Frequency',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary)),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _frequencies.map((f) {
                    final label = f[0].toUpperCase() + f.substring(1);
                    final selected = _frequency == f;
                    return GestureDetector(
                      onTap: () => setState(() => _frequency = f),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppTheme.primaryColor
                              : AppTheme.backgroundColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: selected
                                  ? AppTheme.primaryColor
                                  : AppTheme.glassBorderColor),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? const Color(0xFF0A0800)
                                  : AppTheme.textSecondary),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(
                    color: AppTheme.errorColor, fontSize: 13)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: const Color(0xFF0A0800),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF0A0800)))
                  : const Text('Add Bill',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(color: AppTheme.textHint, fontSize: 14),
            filled: true,
            fillColor: AppTheme.backgroundColor,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: AppTheme.glassBorderColor)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: AppTheme.glassBorderColor)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: AppTheme.primaryColor)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppTheme.errorColor),
            const SizedBox(height: 12),
            Text(error,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 14)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry',
                  style: TextStyle(color: AppTheme.primaryColor)),
            ),
          ],
        ),
      ),
    );
  }
}
