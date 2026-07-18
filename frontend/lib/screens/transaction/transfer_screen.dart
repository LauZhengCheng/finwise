// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : transfer_screen.dart
// Description   : P2P transfer screen — send money by phone number.
//                 Step 1: enter phone, amount, optional note.
//                 Step 2: pick which vault to send from.
// First Written : 18-06-2026
// Edited on     : 18-06-2026
// ============================================

import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../models/vault_model.dart';
import '../../providers/vault_provider.dart';
import '../../services/api/transfer_api.dart';

class TransferScreen extends ConsumerStatefulWidget {
  final String? prefilledPhone;

  const TransferScreen({super.key, this.prefilledPhone});

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _showVaultPicker = false;
  String? _selectedVaultId;
  bool _isSending = false;
  bool _success = false;
  String _receiverName = '';

  // Phone lookup state
  String? _recipientName;   // null = not yet looked up; '' = not found
  bool _isLookingUp = false;
  Timer? _debounceTimer;

  double get _amount => double.tryParse(_amountController.text.trim()) ?? 0;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneChanged);
    if (widget.prefilledPhone != null) {
      _phoneController.text = widget.prefilledPhone!;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _phoneController.removeListener(_onPhoneChanged);
    _phoneController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onPhoneChanged() {
    final phone = _phoneController.text.trim();
    _debounceTimer?.cancel();
    if (phone.length < 9) {
      setState(() { _recipientName = null; _isLookingUp = false; });
      return;
    }
    setState(() { _isLookingUp = true; _recipientName = null; });
    _debounceTimer = Timer(const Duration(milliseconds: 600), () => _lookupPhone(phone));
  }

  Future<void> _lookupPhone(String phone) async {
    try {
      final result = await TransferApi().lookupRecipient(phone);
      if (!mounted || _phoneController.text.trim() != phone) return;
      setState(() {
        _isLookingUp = false;
        _recipientName = result['found'] == true ? result['full_name'] as String? ?? '' : '';
      });
    } catch (_) {
      if (mounted) setState(() { _isLookingUp = false; _recipientName = ''; });
    }
  }

  Future<void> _send() async {
    if (_selectedVaultId == null) return;
    setState(() => _isSending = true);
    try {
      final result = await TransferApi().sendTransfer(
        recipientPhone: _phoneController.text.trim(),
        amount: _amount,
        sourceVaultId: _selectedVaultId!,
        note: _noteController.text.trim(),
      );
      ref.read(vaultProvider.notifier).fetchVaults();
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _success = true;
        _receiverName = result['receiver_name'] as String? ?? 'Recipient';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      if (mounted) {
        String msg = 'Transfer failed. Please try again.';
        if (e is DioException) {
          final data = e.response?.data;
          if (data is Map) msg = data['error'] as String? ?? msg;
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: AppTheme.errorColor,
        ));
      }
    }
  }

  Color _parseColour(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
    } catch (_) {
      return AppTheme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final vaultState = ref.watch(vaultProvider);
    final spendingVaults = vaultState.spendingVaults;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: _success
              ? _buildSuccess()
              : _showVaultPicker
                  ? _buildVaultPicker(spendingVaults)
                  : _buildForm(),
        ),
      ),
    );
  }

  // ── Step 1: Phone + Amount + Note ─────────────
  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
              onPressed: () => Navigator.pop(context),
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            const Text(
              'Transfer Money',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppTheme.textPrimary, letterSpacing: -0.8),
            ),
            const SizedBox(height: 4),
            const Text(
              'Send money to any FinWise user by phone number.',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 32),

            // Phone number
            const Text('Recipient Phone Number', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(fontSize: 16, color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'e.g. 0123456789',
                hintStyle: const TextStyle(color: AppTheme.textHint),
                prefixIcon: const Icon(Icons.phone_rounded, color: AppTheme.textSecondary, size: 20),
                filled: true,
                fillColor: AppTheme.cardColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.glassBorderColor)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.glassBorderColor)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Please enter a phone number';
                return null;
              },
            ),

            // Recipient lookup result
            if (_isLookingUp)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: AppTheme.primaryColor, strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text('Looking up...', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            if (!_isLookingUp && _recipientName != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    Icon(
                      _recipientName!.isNotEmpty ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      size: 16,
                      color: _recipientName!.isNotEmpty ? const Color(0xFF4CAF50) : AppTheme.errorColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _recipientName!.isNotEmpty
                          ? 'Recipient: ${_recipientName!}'
                          : 'User not found',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _recipientName!.isNotEmpty ? const Color(0xFF4CAF50) : AppTheme.errorColor,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // Amount
            const Text('Amount (RM)', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              decoration: InputDecoration(
                prefixText: 'RM  ',
                prefixStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                hintText: '0.00',
                hintStyle: const TextStyle(fontSize: 24, color: AppTheme.textHint),
                filled: true,
                fillColor: AppTheme.cardColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.glassBorderColor)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.glassBorderColor)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Please enter an amount';
                final parsed = double.tryParse(v.trim());
                if (parsed == null || parsed <= 0) return 'Please enter a valid amount';
                return null;
              },
            ),

            const SizedBox(height: 20),

            // Note (optional)
            const Text('Note (optional)', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _noteController,
              style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'e.g. Dinner split, rent share...',
                hintStyle: const TextStyle(color: AppTheme.textHint),
                prefixIcon: const Icon(Icons.notes_rounded, color: AppTheme.textSecondary, size: 20),
                filled: true,
                fillColor: AppTheme.cardColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.glassBorderColor)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.glassBorderColor)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),

            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: (_recipientName == null || _recipientName!.isEmpty)
                  ? null
                  : () {
                      if (!_formKey.currentState!.validate()) return;
                      setState(() => _showVaultPicker = true);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.black,
                disabledBackgroundColor: AppTheme.primaryColor.withValues(alpha: 0.3),
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Choose Vault to Send From', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 2: Pick source vault ─────────────────
  Widget _buildVaultPicker(List<VaultModel> vaults) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 20, 0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
                onPressed: () => setState(() => _showVaultPicker = false),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Send From', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppTheme.textPrimary, letterSpacing: -0.8)),
              const SizedBox(height: 4),
              Text(
                'Sending RM ${_amount.toStringAsFixed(2)} to ${_recipientName ?? _phoneController.text.trim()}',
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: vaults.length,
            itemBuilder: (context, i) {
              final v = vaults[i];
              final colour = _parseColour(v.vaultColour);
              final isSelected = _selectedVaultId == v.id;
              final hasFunds = v.currentBalance >= _amount;

              return GestureDetector(
                onTap: hasFunds ? () => setState(() => _selectedVaultId = v.id) : null,
                child: Opacity(
                  opacity: hasFunds ? 1.0 : 0.4,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected ? colour.withValues(alpha: 0.12) : AppTheme.cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? colour : AppTheme.glassBorderColor,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(color: colour.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                          child: Icon(isSelected ? Icons.check_rounded : Icons.account_balance_wallet_outlined, color: colour, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(v.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                              Text(
                                hasFunds ? 'Spending Vault' : 'Insufficient balance',
                                style: TextStyle(fontSize: 12, color: hasFunds ? AppTheme.textSecondary : AppTheme.errorColor),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'RM ${v.currentBalance.toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colour),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: (_selectedVaultId == null || _isSending) ? null : _send,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 56),
              disabledBackgroundColor: AppTheme.primaryColor.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isSending
                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
                : Text(
                    _selectedVaultId == null ? 'Select a vault first' : 'Send RM ${_amount.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }

  // ── Success state ─────────────────────────────
  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: Color(0xFF4CAF50), size: 44),
            ),
            const SizedBox(height: 24),
            const Text('Sent!', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Text(
              'RM ${_amount.toStringAsFixed(2)} sent to $_receiverName.\nAion will notify the recipient about this transaction.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => context.go('/dashboard'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Back to Home', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
