// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : general_deposit_screen.dart
// Description   : General deposit screen — user picks which vault to
//                 deposit money into. Increases both current_balance
//                 and allocated_amount for the current income cycle.
// First Written : 12-06-2026
// Edited on     : 12-06-2026
// ============================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../models/vault_model.dart';
import '../../providers/vault_provider.dart';
import '../../services/api/income_api.dart';
import '../../widgets/goal_celebration_overlay.dart';

class GeneralDepositScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> qrPayload;

  const GeneralDepositScreen({super.key, required this.qrPayload});

  @override
  ConsumerState<GeneralDepositScreen> createState() =>
      _GeneralDepositScreenState();
}

class _GeneralDepositScreenState extends ConsumerState<GeneralDepositScreen> {
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _selectedVaultId;
  bool _isConfirming = false;
  bool _showVaultPicker = false;

  double get _amount => double.tryParse(_amountController.text.trim()) ?? 0;

  String get _senderName =>
      widget.qrPayload['merchant_name'] ?? 'Unknown Sender';

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_selectedVaultId == null) return;
    setState(() => _isConfirming = true);
    try {
      final result = await IncomeApi().depositToVault(
        vaultId: _selectedVaultId!,
        amount: _amount,
      );
      ref.read(vaultProvider.notifier).fetchVaults();

      if (!mounted) return;

      final completedGoals = result['completed_goals'] as List<dynamic>? ?? [];
      bool wantsChat = false;
      for (final goal in completedGoals) {
        if (!mounted) break;
        final tappedChat = await GoalCelebrationOverlay.show(
          context,
          vaultName: goal['vault_name'] as String,
          goalTargetAmount: (goal['goal_target_amount'] as num).toDouble(),
          allocationPercentage: (goal['allocation_percentage'] as num?)?.toInt() ?? 0,
        );
        if (tappedChat) wantsChat = true;
      }

      if (mounted) context.go(wantsChat ? '/chat' : '/dashboard');
    } catch (e) {
      if (mounted) {
        setState(() => _isConfirming = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppTheme.errorColor,
          ),
        );
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
    final allVaults = vaultState.vaults;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: _showVaultPicker
              ? _buildVaultPicker(allVaults)
              : _buildAmountEntry(),
        ),
      ),
    );
  }

  // ── Step 1: Enter amount ──────────────────────
  Widget _buildAmountEntry() {
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

            // Sender info card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.arrow_downward_rounded, color: Colors.black, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('From', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        Text(
                          _senderName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            const Text('Enter Amount', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            const Text(
              'Choose how much to deposit, then pick which vault to put it in.',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 24),

            // Amount field
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
              autofocus: true,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              decoration: InputDecoration(
                prefixText: 'RM  ',
                prefixStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                hintText: '0.00',
                hintStyle: const TextStyle(fontSize: 24, color: AppTheme.textHint),
                filled: true,
                fillColor: AppTheme.cardColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.glassBorderColor)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.glassBorderColor)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Please enter an amount';
                final parsed = double.tryParse(v.trim());
                if (parsed == null || parsed <= 0) return 'Please enter a valid amount';
                return null;
              },
            ),

            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: () {
                if (!_formKey.currentState!.validate()) return;
                setState(() => _showVaultPicker = true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Choose Vault', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 2: Pick vault ────────────────────────
  Widget _buildVaultPicker(List<VaultModel> vaults) {
    return Column(
      children: [
        // Header
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
              const Text('Choose Vault', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppTheme.textPrimary, letterSpacing: -0.8)),
              const SizedBox(height: 4),
              Text(
                'Depositing RM ${_amount.toStringAsFixed(2)} — pick where to put it',
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Vault list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: vaults.length,
            itemBuilder: (context, i) {
              final v = vaults[i];
              final colour = _parseColour(v.vaultColour);
              final isSelected = _selectedVaultId == v.id;

              return GestureDetector(
                onTap: () => setState(() => _selectedVaultId = v.id),
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
                              v.vaultType == 'fund' ? 'Saving Goal' : 'Spending Vault',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'RM ${v.currentBalance.toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colour),
                          ),
                          const Text('current', style: TextStyle(fontSize: 11, color: AppTheme.textHint)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Confirm button
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: (_selectedVaultId == null || _isConfirming) ? null : _confirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 56),
              disabledBackgroundColor: AppTheme.primaryColor.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isConfirming
                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
                : Text(
                    _selectedVaultId == null ? 'Select a vault first' : 'Confirm Deposit',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }
}
