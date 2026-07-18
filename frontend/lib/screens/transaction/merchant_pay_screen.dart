// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : merchant_pay_screen.dart
// Description   : Merchant payment screen — shows merchant info,
//                 handles Pay flow, Goal Guardian, and Active Pilot
// First Written : 06-06-2026
// Edited on     : 06-06-2026
// ============================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../providers/vault_provider.dart';
import '../../services/api/transaction_api.dart';
import 'widgets/goal_guardian_popup.dart';
import 'widgets/active_pilot_popup.dart';

class MerchantPayScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> qrPayload;

  const MerchantPayScreen({super.key, required this.qrPayload});

  @override
  ConsumerState<MerchantPayScreen> createState() => _MerchantPayScreenState();
}

class _MerchantPayScreenState extends ConsumerState<MerchantPayScreen> {
  bool _isLoading = false;
  bool _isSuccess = false;
  String? _successVaultName;
  String? _error;

  // Vault selection step state
  bool _isCategorizing = false;
  bool _isCategorized = false;
  bool _categorizationFailed = false;
  Map<String, dynamic>? _selectedVault;
  List<Map<String, dynamic>> _allVaults = [];

  String get _merchantName =>
      widget.qrPayload['merchant_name'] as String? ?? 'Unknown Merchant';
  double get _amount =>
      (widget.qrPayload['default_amount'] as num?)?.toDouble() ?? 0.0;
  String get _merchantId =>
      widget.qrPayload['merchant_id'] as String? ?? '';

  // Step 1: Categorize — AI suggests a vault, no money moved yet
  Future<void> _onCategorize() async {
    setState(() {
      _isCategorizing = true;
      _error = null;
    });
    try {
      final result = await TransactionApi().categorize(
        merchantId: _merchantId,
        amount: _amount,
      );
      if (!mounted) return;
      final vaults = (result['all_vaults'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final suggested = result['suggested_vault'] as Map<String, dynamic>?;
      setState(() {
        _isCategorizing = false;
        _isCategorized = true;
        _categorizationFailed = result['categorization_failed'] == true;
        _allVaults = vaults;
        _selectedVault = suggested ?? (vaults.isNotEmpty ? vaults.first : null);
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCategorizing = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  // Step 2: Pay — run the full transaction with the chosen vault
  Future<void> _onPay({String? vaultId}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await TransactionApi().initiate(
        merchantId: _merchantId,
        amount: _amount,
        vaultId: vaultId ?? _selectedVault?['id'] as String?,
      );
      if (!mounted) return;
      _handleResult(result);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _handleResult(Map<String, dynamic> result) {
    final outcome = result['outcome'] as String?;
    switch (outcome) {
      case 'approved':
        ref.read(vaultProvider.notifier).fetchVaults();
        setState(() {
          _isLoading = false;
          _isSuccess = true;
          _successVaultName = (result['matched_vault'] as Map<String, dynamic>?)?['name'] as String?;
        });
        break;

      case 'alert':
        setState(() => _isLoading = false);
        _showGoalGuardianPopup(result);
        break;

      case 'blocked':
        setState(() => _isLoading = false);
        _showActivePilotPopup(result);
        break;

      case 'categorisation_failed':
        setState(() => _isLoading = false);
        _showVaultSelectionDialog(result);
        break;

      default:
        setState(() {
          _isLoading = false;
          _error = 'Unexpected response from server';
        });
    }
  }

  void _showGoalGuardianPopup(Map<String, dynamic> result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => GoalGuardianPopup(
        result: result,
        onProceed: () async {
          context.pop();
          setState(() => _isLoading = true);
          try {
            await TransactionApi().execute(result);
            ref.read(vaultProvider.notifier).fetchVaults();
            if (mounted) context.go('/dashboard');
          } catch (e) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _error = e.toString().replaceFirst('Exception: ', '');
              });
            }
          }
        },
        onCancel: () async {
          context.pop();
          try {
            await TransactionApi().cancel(result);
          } catch (_) {}
          if (mounted) context.pop();
        },
      ),
    );
  }

  void _showActivePilotPopup(Map<String, dynamic> result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => ActivePilotPopup(
        transactionResult: result,
        onTransferComplete: () => _onPay(),
        onCancel: () => context.pop(),
      ),
    );
  }

  void _showVaultSelectionDialog(Map<String, dynamic> result) {
    final vaults = (result['vaults'] as List<dynamic>)
        .cast<Map<String, dynamic>>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Vault'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Aion couldn't identify which vault to use. Please select one:",
                style: TextStyle(
                    fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              ...vaults.map((v) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(v['name'] as String,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        'RM ${(v['current_balance'] as num).toStringAsFixed(2)} available'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _onPay(vaultId: v['id'] as String);
                    },
                  )),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isSuccess) return _buildSuccessView();

    return PopScope(
      // Block back navigation while loading or categorizing
      canPop: !_isLoading && !_isCategorizing,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
          child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button — hidden during loading/categorising (committed state)
              if (!_isLoading && !_isCategorizing)
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
                  onPressed: () => Navigator.pop(context),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                ),
              Expanded(
              child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),

                // Merchant icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.store_rounded,
                    color: AppTheme.primaryColor,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),

                // Merchant name
                Text(
                  _merchantName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Merchant',
                  style:
                      TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                ),

                const SizedBox(height: 40),

                // Amount
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF242018), Color(0xFF0F0D09)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.glassBorderColor),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Amount',
                        style: TextStyle(
                            fontSize: 13, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'RM ${_amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Vault selector — shown after categorization
                if (_isCategorized && _selectedVault != null)
                  _buildVaultSelector()
                else
                  Text(
                    _isCategorizing
                        ? 'Asking Aion which vault to use...'
                        : 'Aion will choose the right vault for you',
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.textSecondary),
                  ),

                const Spacer(),

                // Error
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                          color: AppTheme.errorColor, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Button / loading area
                if (_isLoading)
                  _buildLoadingState()
                else if (_isCategorizing)
                  _buildCategorizingState()
                else if (_isCategorized)
                  ElevatedButton(
                    onPressed: _onPay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      'Confirm & Pay RM ${_amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  )
                else
                  ElevatedButton(
                    onPressed: _onCategorize,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      'Pay RM ${_amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ),

                const SizedBox(height: 16),
              ],
            ),
          ),
          ),        // closes Expanded
        ],          // closes outer Column children
      ),            // closes outer Column
      ),            // closes SafeArea
    ),              // closes DecoratedBox
  ),                // closes Scaffold
);
  }

  Widget _buildSuccessView() {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),

              // Animated checkmark
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  color: Color(0xFF16A34A),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 52,
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Payment Successful',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _merchantName,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppTheme.textSecondary,
                ),
              ),

              const SizedBox(height: 32),

              // Amount + vault row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF242018), Color(0xFF0F0D09)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.glassBorderColor),
                ),
                child: Column(
                  children: [
                    Text(
                      'RM ${_amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (_successVaultName != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.account_balance_wallet_rounded,
                              size: 14, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            'Charged to $_successVaultName',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const Spacer(),

              ElevatedButton(
                onPressed: () => context.go('/dashboard'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Back to Dashboard',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // Vault card shown after categorization — user can tap Change to swap vault
  Widget _buildVaultSelector() {
    final vault = _selectedVault!;
    final balance = (vault['current_balance'] as num).toDouble();
    final label = _categorizationFailed
        ? 'Please select a vault:'
        : 'Aion suggests:';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet_rounded,
              color: AppTheme.primaryColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
                Text(vault['name'] as String,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary)),
                Text('RM ${balance.toStringAsFixed(2)} available',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          TextButton(
            onPressed: _showVaultChangeSheet,
            child: const Text('Change',
                style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // Bottom sheet listing all vaults so user can pick a different one
  void _showVaultChangeSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text('Select Vault',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary)),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: _allVaults.map((v) {
                    final bal = (v['current_balance'] as num).toDouble();
                    final isSelected = v['id'] == _selectedVault?['id'];
                    return ListTile(
                      leading: Icon(
                        isSelected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        color: AppTheme.primaryColor,
                      ),
                      title: Text(v['name'] as String,
                          style:
                              const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          'RM ${bal.toStringAsFixed(2)} available'),
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() => _selectedVault = v);
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // Spinner shown while the categorization call is in flight
  Widget _buildCategorizingState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: AppTheme.primaryColor),
          ),
          SizedBox(width: 14),
          Text('Asking Aion which vault to use...',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor)),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.2)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppTheme.primaryColor,
            ),
          ),
          SizedBox(width: 14),
          Text(
            'Aion is reviewing your transaction...',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
