// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : vault_provider.dart
// Description   : Riverpod provider for user vault data.
//                 Fetches vaults from Supabase with real-time subscription.
// First Written : 06-06-2026
// Edited on     : 06-06-2026
// ============================================

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/vault_model.dart';

// ─────────────────────────────────────────────
// VAULT STATE
// ─────────────────────────────────────────────
class VaultState {
  final List<VaultModel> vaults;
  final bool isLoading;
  final String? error;

  const VaultState({
    this.vaults = const [],
    this.isLoading = false,
    this.error,
  });

  VaultState copyWith({
    List<VaultModel>? vaults,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return VaultState(
      vaults: vaults ?? this.vaults,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  List<VaultModel> get spendingVaults =>
      vaults.where((v) => v.vaultType == 'vault').toList();

  List<VaultModel> get savingFunds =>
      vaults.where((v) => v.vaultType == 'fund').toList();

  // Sum of spending vault balances only — funds are excluded
  double get totalSafeToSpend => spendingVaults.fold(0.0, (sum, v) => sum + v.currentBalance);
}

// ─────────────────────────────────────────────
// VAULT NOTIFIER
// ─────────────────────────────────────────────
class VaultNotifier extends StateNotifier<VaultState> {
  RealtimeChannel? _channel;

  VaultNotifier() : super(const VaultState()) {
    fetchVaults();
    _subscribeToRealtime();
  }

  Future<void> fetchVaults() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        state = state.copyWith(isLoading: false, error: 'Not logged in');
        return;
      }

      final response = await Supabase.instance.client
          .from('vaults')
          .select()
          .eq('user_id', userId)
          .eq('is_active', true)
          .order('vault_type', ascending: true);

      final vaults = (response as List)
          .map((v) => VaultModel.fromDbJson(v as Map<String, dynamic>))
          .toList();

      state = state.copyWith(vaults: vaults, isLoading: false);
    } catch (e, st) {
      debugPrint('fetchVaults error: $e\n$st');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // Subscribe to real-time changes on the vaults table.
  // Any INSERT/UPDATE/DELETE on this user's vaults triggers a refresh.
  void _subscribeToRealtime() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    _channel = Supabase.instance.client
        .channel('vaults:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'vaults',
          callback: (_) => fetchVaults(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    super.dispose();
  }
}

// ─────────────────────────────────────────────
// PROVIDER
// ─────────────────────────────────────────────
final vaultProvider = StateNotifierProvider<VaultNotifier, VaultState>(
  (ref) => VaultNotifier(),
);
