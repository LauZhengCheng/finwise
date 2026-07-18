// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : achievement_provider.dart
// Description   : Riverpod provider for user achievements state
// First Written : 17-06-2026
// Edited on     : 17-06-2026
// ============================================

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api/achievement_api.dart';

// ─────────────────────────────────────────────
// ACHIEVEMENT STATE
// ─────────────────────────────────────────────
class AchievementState {
  final List<Map<String, dynamic>> achievements;
  final bool isLoading;
  final String? error;

  const AchievementState({
    this.achievements = const [],
    this.isLoading = false,
    this.error,
  });

  AchievementState copyWith({
    List<Map<String, dynamic>>? achievements,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return AchievementState(
      achievements: achievements ?? this.achievements,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  List<Map<String, dynamic>> get unlocked =>
      achievements.where((a) => a['unlocked'] == true).toList();

  int get unlockedCount => unlocked.length;
}

// ─────────────────────────────────────────────
// ACHIEVEMENT NOTIFIER
// ─────────────────────────────────────────────
class AchievementNotifier extends StateNotifier<AchievementState> {
  final _api = AchievementApi();

  AchievementNotifier() : super(const AchievementState());

  Future<void> fetchAchievements() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final achievements = await _api.getAchievements();
      state = state.copyWith(achievements: achievements, isLoading: false);
    } catch (e, st) {
      debugPrint('fetchAchievements error: $e\n$st');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

// ─────────────────────────────────────────────
// PROVIDER
// ─────────────────────────────────────────────
final achievementProvider =
    StateNotifierProvider<AchievementNotifier, AchievementState>(
  (ref) => AchievementNotifier(),
);
