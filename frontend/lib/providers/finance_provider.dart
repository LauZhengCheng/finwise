// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : finance_provider.dart
// Description   : Riverpod providers for health score, net worth,
//                 and spending forecast
// First Written : 17-06-2026
// Edited on     : 17-06-2026
// ============================================

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api/finance_api.dart';

// ─────────────────────────────────────────────
// HEALTH SCORE STATE
// ─────────────────────────────────────────────
class HealthScoreState {
  final Map<String, dynamic>? data;
  final bool isLoading;
  final String? error;

  const HealthScoreState({
    this.data,
    this.isLoading = false,
    this.error,
  });

  HealthScoreState copyWith({
    Map<String, dynamic>? data,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return HealthScoreState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class HealthScoreNotifier extends StateNotifier<HealthScoreState> {
  final FinanceApi _api = FinanceApi();

  HealthScoreNotifier() : super(const HealthScoreState());

  Future<void> fetchHealthScore() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await _api.getHealthScore();
      state = state.copyWith(data: data, isLoading: false);
    } catch (e, st) {
      debugPrint('fetchHealthScore error: $e\n$st');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final healthScoreProvider =
    StateNotifierProvider<HealthScoreNotifier, HealthScoreState>(
  (ref) => HealthScoreNotifier(),
);

