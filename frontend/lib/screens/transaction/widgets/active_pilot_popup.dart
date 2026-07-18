// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : active_pilot_popup.dart
// Description   : Active Pilot 3-step vault reallocation popup —
//                 shown when vault balance is insufficient
// First Written : 06-06-2026
// Edited on     : 06-06-2026
// ============================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/app_theme.dart';
import '../../../providers/vault_provider.dart';
import '../../../services/api/vault_api.dart';

class ActivePilotPopup extends ConsumerStatefulWidget {
  final Map<String, dynamic> transactionResult;
  final VoidCallback onTransferComplete;
  final VoidCallback onCancel;

  const ActivePilotPopup({
    super.key,
    required this.transactionResult,
    required this.onTransferComplete,
    required this.onCancel,
  });

  @override
  ConsumerState<ActivePilotPopup> createState() => _ActivePilotPopupState();
}

class _ActivePilotPopupState extends ConsumerState<ActivePilotPopup> {
  int _step = 1;
  Map<String, dynamic>? _selectedVault;
  bool _isLoading = false;
  String? _error;

  // Data from the blocked result — vault info is nested under 'matched_vault'
  Map<String, dynamic> get _matchedVault =>
      widget.transactionResult['matched_vault'] as Map<String, dynamic>? ?? {};

  double get _shortfall =>
      (widget.transactionResult['shortfall'] as num?)?.toDouble() ?? 0.0;
  String get _blockedVaultId => _matchedVault['id'] as String? ?? '';
  String get _blockedVaultName => _matchedVault['name'] as String? ?? 'Unknown Vault';
  double get _blockedVaultBalance =>
      (_matchedVault['current_balance'] as num?)?.toDouble() ?? 0.0;
  double get _amount =>
      (widget.transactionResult['amount'] as num?)?.toDouble() ?? 0.0;

  List<Map<String, dynamic>> get _allVaults {
    final raw = widget.transactionResult['all_vaults'] as List<dynamic>? ?? [];
    return raw.cast<Map<String, dynamic>>();
  }

  List<Map<String, dynamic>> get _otherVaults =>
      _allVaults.where((v) => v['id'] != _blockedVaultId).toList();

  Future<void> _confirmTransfer() async {
    if (_selectedVault == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await VaultApi().transfer(
        fromVaultId: _selectedVault!['id'] as String,
        toVaultId: _blockedVaultId,
        amount: _shortfall,
      );
      ref.read(vaultProvider.notifier).fetchVaults();
      if (mounted) {
        Navigator.pop(context);
        widget.onTransferComplete();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Step indicator
          Row(
            children: [
              _StepDot(step: 1, current: _step),
              _StepLine(active: _step >= 2),
              _StepDot(step: 2, current: _step),
              _StepLine(active: _step >= 3),
              _StepDot(step: 3, current: _step),
            ],
          ),
          const SizedBox(height: 20),

          if (_step == 1) _buildStep1(),
          if (_step == 2) _buildStep2(),
          if (_step == 3) _buildStep3(),
        ],
      ),
    );
  }

  // ─── Step 1: Insufficient balance notification ───
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.block_rounded,
                  color: AppTheme.errorColor, size: 24),
            ),
            const SizedBox(width: 12),
            const Text(
              'Transaction Blocked',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.errorColor.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: AppTheme.errorColor.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              _InfoRow(
                  label: 'Vault', value: _blockedVaultName),
              const SizedBox(height: 8),
              _InfoRow(
                  label: 'Transaction',
                  value: 'RM ${_amount.toStringAsFixed(2)}'),
              const SizedBox(height: 8),
              _InfoRow(
                  label: 'Current Balance',
                  value: 'RM ${_blockedVaultBalance.toStringAsFixed(2)}'),
              const Divider(height: 20),
              _InfoRow(
                label: 'Shortfall',
                value: 'RM ${_shortfall.toStringAsFixed(2)}',
                valueStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.errorColor,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Transfer from another vault to cover the shortfall.',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: widget.onCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  side: const BorderSide(color: AppTheme.glassBorderColor),
                  minimumSize: const Size(0, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Cancel',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => setState(() => _step = 2),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Transfer Funds',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Step 2: Select source vault ───
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Source Vault',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary),
        ),
        Text(
          'Which vault should cover RM ${_shortfall.toStringAsFixed(2)}?',
          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _otherVaults.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final vault = _otherVaults[index];
              final balance =
                  (vault['current_balance'] as num?)?.toDouble() ?? 0.0;
              final isFund =
                  (vault['vault_type'] as String?) == 'fund';
              final canAfford = balance >= _shortfall;
              final isSelected =
                  _selectedVault?['id'] == vault['id'];

              return GestureDetector(
                onTap: canAfford
                    ? () => setState(() => _selectedVault = vault)
                    : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryColor.withValues(alpha: 0.08)
                        : canAfford
                            ? AppTheme.cardColor
                            : AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : canAfford
                              ? AppTheme.glassBorderColor
                              : AppTheme.glassBorderColor,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              vault['name'] as String? ?? '',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: canAfford
                                    ? AppTheme.textPrimary
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle_rounded,
                                color: AppTheme.primaryColor, size: 20),
                          if (!canAfford)
                            const Text('Insufficient',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'RM ${balance.toStringAsFixed(2)} available',
                        style: TextStyle(
                          fontSize: 12,
                          color: canAfford
                              ? AppTheme.textSecondary
                              : AppTheme.textHint,
                        ),
                      ),
                      // Fund warning
                      if (isFund && canAfford) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  size: 12,
                                  color: Color(0xFFF59E0B)),
                              SizedBox(width: 4),
                              Text(
                                'This will impact your saving goal',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.primaryColor),
                              ),
                            ],
                          ),
                        ),
                      ],
                      // AI-driven warnings (bills, debts, emergency fund)
                      if (vault['warnings'] != null)
                        ...(vault['warnings'] as List<dynamic>).map((w) =>
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline_rounded,
                                    size: 11,
                                    color: const Color(0xFFF59E0B).withValues(alpha: 0.7)),
                                const SizedBox(width: 4),
                                Flexible(child: Text(
                                  w as String,
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: const Color(0xFFF59E0B).withValues(alpha: 0.8)),
                                )),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _step = 1),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  side: const BorderSide(color: AppTheme.glassBorderColor),
                  minimumSize: const Size(0, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Back',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _selectedVault == null
                    ? null
                    : () => setState(() => _step = 3),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Next',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Step 3: Confirm transfer ───
  Widget _buildStep3() {
    if (_selectedVault == null) return const SizedBox.shrink();
    final fromBalance =
        (_selectedVault!['current_balance'] as num?)?.toDouble() ?? 0.0;
    final afterFrom = fromBalance - _shortfall;
    final afterTo = _blockedVaultBalance + _shortfall;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Confirm Transfer',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary),
        ),
        Text(
          'Moving RM ${_shortfall.toStringAsFixed(2)} between vaults',
          style:
              const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 16),

        // From vault
        _TransferCard(
          label: 'From',
          name: _selectedVault!['name'] as String? ?? '',
          before: fromBalance,
          after: afterFrom,
          direction: 'out',
        ),
        const SizedBox(height: 2),
        const Center(
          child: Icon(Icons.arrow_downward_rounded,
              color: AppTheme.textSecondary, size: 20),
        ),
        const SizedBox(height: 2),
        // To vault
        _TransferCard(
          label: 'To',
          name: _blockedVaultName,
          before: _blockedVaultBalance,
          after: afterTo,
          direction: 'in',
        ),

        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_error!,
                style: const TextStyle(
                    color: AppTheme.errorColor, fontSize: 13)),
          ),

        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isLoading
                    ? null
                    : () => setState(() => _step = 2),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  side: const BorderSide(color: AppTheme.glassBorderColor),
                  minimumSize: const Size(0, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Back',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _isLoading ? null : _confirmTransfer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white),
                      )
                    : const Text('Confirm Transfer',
                        style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Helper Widgets ───

class _StepDot extends StatelessWidget {
  final int step;
  final int current;
  const _StepDot({required this.step, required this.current});

  @override
  Widget build(BuildContext context) {
    final done = step < current;
    final active = step == current;
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done || active
            ? AppTheme.primaryColor
            : AppTheme.glassBorderColor,
      ),
      alignment: Alignment.center,
      child: done
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
          : Text(
              '$step',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color:
                    active ? Colors.white : AppTheme.textSecondary,
              ),
            ),
    );
  }
}

class _StepLine extends StatelessWidget {
  final bool active;
  const _StepLine({required this.active});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 2,
        color: active
            ? AppTheme.primaryColor
            : AppTheme.glassBorderColor,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? valueStyle;
  const _InfoRow(
      {required this.label, required this.value, this.valueStyle});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13, color: AppTheme.textSecondary)),
        Text(
          value,
          style: valueStyle ??
              const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppTheme.textPrimary),
        ),
      ],
    );
  }
}

class _TransferCard extends StatelessWidget {
  final String label;
  final String name;
  final double before;
  final double after;
  final String direction;
  const _TransferCard({
    required this.label,
    required this.name,
    required this.before,
    required this.after,
    required this.direction,
  });

  @override
  Widget build(BuildContext context) {
    final isOut = direction == 'out';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.glassBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(name,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('RM ${before.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textSecondary)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.arrow_forward_rounded,
                    size: 14, color: AppTheme.textSecondary),
              ),
              Text(
                'RM ${after.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isOut
                      ? AppTheme.errorColor
                      : const Color(0xFF16A34A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
