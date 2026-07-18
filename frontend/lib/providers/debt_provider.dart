// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : debt_provider.dart
// Description   : Riverpod provider for comprehensive debt data.
//                 Exposes debt list + summary totals from backend.
// First Written : 17-06-2026
// Edited on     : 20-06-2026
// ============================================

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api/debt_api.dart';

class DebtState {
  final List<Map<String, dynamic>> debts;
  final Map<String, dynamic> summary;
  final bool isLoading;
  final String? error;

  const DebtState({
    this.debts = const [],
    this.summary = const {},
    this.isLoading = false,
    this.error,
  });

  DebtState copyWith({
    List<Map<String, dynamic>>? debts,
    Map<String, dynamic>? summary,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return DebtState(
      debts: debts ?? this.debts,
      summary: summary ?? this.summary,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  double get totalBalance =>
      (summary['total_balance'] as num?)?.toDouble() ?? 0.0;

  double get totalMinimumPayment =>
      (summary['total_minimum_monthly'] as num?)?.toDouble() ?? 0.0;

  double get monthlyInterestCost =>
      (summary['monthly_interest_cost'] as num?)?.toDouble() ?? 0.0;

  int get debtCount =>
      (summary['total_debts'] as int?) ?? debts.length;
}

class DebtNotifier extends StateNotifier<DebtState> {
  final DebtApi _api = DebtApi();

  DebtNotifier() : super(const DebtState());

  Future<void> fetchDebts() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _api.getDebts();
      final debts = (response['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final summary = response['summary'] as Map<String, dynamic>? ?? {};
      state = state.copyWith(debts: debts, summary: summary, isLoading: false);
    } catch (e, st) {
      debugPrint('fetchDebts error: $e\n$st');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> createDebt(Map<String, dynamic> data) async {
    try {
      await _api.createDebt(data);
      await fetchDebts();
    } catch (e, st) {
      debugPrint('createDebt error: $e\n$st');
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> updateDebt(String id, Map<String, dynamic> data) async {
    try {
      await _api.updateDebt(id, data);
      await fetchDebts();
    } catch (e, st) {
      debugPrint('updateDebt error: $e\n$st');
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteDebt(String id) async {
    try {
      await _api.deleteDebt(id);
      await fetchDebts();
    } catch (e, st) {
      debugPrint('deleteDebt error: $e\n$st');
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }
}

final debtProvider = StateNotifierProvider<DebtNotifier, DebtState>(
  (ref) => DebtNotifier(),
);
