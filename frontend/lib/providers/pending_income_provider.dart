// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : pending_income_provider.dart
// Description   : Riverpod provider for staged (pending) salary income.
//                 Drives the Aion income-choice card on the dashboard.
// First Written : 18-06-2026
// Edited on     : 18-06-2026
// ============================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api/income_api.dart';

class PendingIncomeState {
  final bool isLoading;
  final String? injectionId;
  final double? amount;
  final double? totalCarryover;

  const PendingIncomeState({
    this.isLoading = false,
    this.injectionId,
    this.amount,
    this.totalCarryover,
  });

  bool get hasPending => injectionId != null;

  PendingIncomeState copyWith({
    bool? isLoading,
    String? injectionId,
    double? amount,
    double? totalCarryover,
    bool clear = false,
  }) {
    if (clear) return const PendingIncomeState();
    return PendingIncomeState(
      isLoading: isLoading ?? this.isLoading,
      injectionId: injectionId ?? this.injectionId,
      amount: amount ?? this.amount,
      totalCarryover: totalCarryover ?? this.totalCarryover,
    );
  }
}

class PendingIncomeNotifier extends StateNotifier<PendingIncomeState> {
  PendingIncomeNotifier() : super(const PendingIncomeState());

  Future<void> fetchPending() async {
    state = state.copyWith(isLoading: true);
    try {
      final data = await IncomeApi().getPendingIncome();
      if (data != null) {
        state = PendingIncomeState(
          isLoading: false,
          injectionId: data['id'] as String,
          amount: (data['amount'] as num).toDouble(),
          totalCarryover: (data['total_carryover'] as num).toDouble(),
        );
      } else {
        state = const PendingIncomeState(isLoading: false);
      }
    } catch (_) {
      state = const PendingIncomeState(isLoading: false);
    }
  }

  void clear() => state = const PendingIncomeState();
}

final pendingIncomeProvider =
    StateNotifierProvider<PendingIncomeNotifier, PendingIncomeState>(
  (ref) => PendingIncomeNotifier(),
);
