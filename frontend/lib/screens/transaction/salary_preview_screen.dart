// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : salary_preview_screen.dart
// Description   : Salary allocation preview — shows per-vault
//                 amounts before user confirms the deposit
// First Written : 06-06-2026
// Edited on     : 06-06-2026
// ============================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../models/vault_model.dart';
import '../../providers/vault_provider.dart';
import '../../services/api/income_api.dart';

class SalaryPreviewScreen extends ConsumerStatefulWidget {
  final double amount;

  const SalaryPreviewScreen({super.key, required this.amount});

  @override
  ConsumerState<SalaryPreviewScreen> createState() =>
      _SalaryPreviewScreenState();
}

class _SalaryPreviewScreenState extends ConsumerState<SalaryPreviewScreen> {
  bool _isConfirming = false;

  // Calculate allocation for a vault based on amount
  double _calculateAllocation(VaultModel vault) {
    return (widget.amount * vault.allocationPercentage / 100 * 100).round() /
        100;
  }

  // Build the allocation list with rounding correction on first vault
  List<_VaultAllocation> _buildAllocations(List<VaultModel> vaults) {
    if (vaults.isEmpty) return [];

    final allocations = vaults
        .map((v) => _VaultAllocation(
              vault: v,
              allocated: _calculateAllocation(v),
            ))
        .toList();

    // Fix rounding: ensure total equals the full amount
    final total = allocations.fold(0.0, (sum, a) => sum + a.allocated);
    final diff = ((widget.amount - total) * 100).roundToDouble() / 100;
    if (diff != 0.0) {
      allocations[0] = _VaultAllocation(
        vault: allocations[0].vault,
        allocated:
            ((allocations[0].allocated + diff) * 100).round() / 100,
      );
    }

    return allocations;
  }

  Future<void> _confirmDeposit(List<VaultModel> vaults) async {
    setState(() => _isConfirming = true);
    try {
      await IncomeApi().injectIncome(amount: widget.amount);
      // Refresh vault provider so dashboard shows updated balances
      ref.read(vaultProvider.notifier).fetchVaults();
      if (mounted) context.go('/dashboard');
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
      final clean = hex.replaceFirst('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return AppTheme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final vaultState = ref.watch(vaultProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: vaultState.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : vaultState.error != null
              ? Center(
                  child: Text(
                    'Could not load vaults: ${vaultState.error}',
                    style: const TextStyle(color: AppTheme.errorColor),
                  ),
                )
              : _buildContent(vaultState.vaults),
      ),
    );
  }

  Widget _buildContent(List<VaultModel> vaults) {
    final allocations = _buildAllocations(vaults);

    return SafeArea(
      child: Column(
        children: [
          // Back button
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
              onPressed: () => Navigator.pop(context),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            ),
          ),

          // Summary header
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF242018), Color(0xFF0F0D09)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.25)),
            ),
            child: Column(
              children: [
                const Text(
                  'Total Deposit',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'RM ${widget.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Split across ${vaults.length} vaults',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Vault allocation list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: allocations.length,
              itemBuilder: (context, index) {
                final a = allocations[index];
                final colour = _parseColour(a.vault.vaultColour);
                final isLast = index == allocations.length - 1;

                return Container(
                  margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.glassBorderColor),
                  ),
                  child: Row(
                    children: [
                      // Colour dot
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: colour.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            '${a.vault.allocationPercentage}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: colour,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Vault name + type badge
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.vault.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              a.vault.vaultType == 'fund'
                                  ? 'Saving Fund'
                                  : 'Spending Vault',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Allocated amount
                      Text(
                        'RM ${a.allocated.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colour,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Confirm button
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _isConfirming ? null : () => _confirmDeposit(vaults),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: const Color(0xFF0A0800),
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isConfirming
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'Confirm Deposit',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// Simple data holder for preview list
class _VaultAllocation {
  final VaultModel vault;
  final double allocated;
  const _VaultAllocation({required this.vault, required this.allocated});
}
