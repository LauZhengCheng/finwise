// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : onboarding_provider.dart
// Description   : State management for onboarding chat screen
// First Written : 24-May-2026
// Edited on     : 01-Jun-2026
// ============================================

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message_model.dart';
import '../models/vault_model.dart';
import '../services/api/ai_api.dart';

// ─────────────────────────────────────────────
// ONBOARDING STATE
// ─────────────────────────────────────────────
class OnboardingState {
  final List<MessageModel> messages;
  final bool isLoading;
  final bool vaultPlanExists;
  final bool vaultsSaved;
  final List<VaultModel> vaultRecommendations;
  final Map<String, dynamic>? profileData;
  final String? error;

  OnboardingState({
    this.messages = const [],
    this.isLoading = false,
    this.vaultPlanExists = false,
    this.vaultsSaved = false,
    this.vaultRecommendations = const [],
    this.profileData,
    this.error,
  });

  OnboardingState copyWith({
    List<MessageModel>? messages,
    bool? isLoading,
    bool? vaultPlanExists,
    bool? vaultsSaved,
    List<VaultModel>? vaultRecommendations,
    Map<String, dynamic>? profileData,
    String? error,
    bool clearError = false,
  }) {
    return OnboardingState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      vaultPlanExists: vaultPlanExists ?? this.vaultPlanExists,
      vaultsSaved: vaultsSaved ?? this.vaultsSaved,
      vaultRecommendations: vaultRecommendations ?? this.vaultRecommendations,
      profileData: profileData ?? this.profileData,
      // clearError: true explicitly sets error to null (error: null alone won't work
      // because null ?? this.error returns the old value via the ?? operator)
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ─────────────────────────────────────────────
// ONBOARDING NOTIFIER
// ─────────────────────────────────────────────
class OnboardingNotifier extends StateNotifier<OnboardingState> {
  final AiApi _aiApi = AiApi();

  OnboardingNotifier() : super(OnboardingState());

  Future<void> loadInitialGreeting() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _aiApi.getInitialGreeting();
      state = state.copyWith(
        messages: [
          MessageModel(
            content: response['message'],
            isUser: false,
            timestamp: DateTime.now(),
          ),
        ],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> sendMessage(String userInput) async {
    if (userInput.trim().isEmpty) return;

    state = state.copyWith(
      messages: [
        ...state.messages,
        MessageModel(content: userInput, isUser: true, timestamp: DateTime.now()),
      ],
      isLoading: true,
      clearError: true,
    );

    try {
      final response = await _aiApi.sendOnboardingMessage(
        message: userInput,
        conversationHistory: state.messages,
        currentVaults: state.vaultPlanExists
            ? state.vaultRecommendations.map((v) => v.toJson()).toList()
            : null,
      );

      final ariaMessage = MessageModel(
        content: response['message'],
        isUser: false,
        timestamp: DateTime.now(),
      );

      final bool isComplete = response['vault_plan_ready'] ?? false;

      List<VaultModel> vaults = [];
      if (isComplete && response['vault_recommendations'] != null) {
        vaults = (response['vault_recommendations'] as List)
            .map((v) => VaultModel.fromJson(v))
            .toList();
      }

      // When Aria finalises a vault plan, inject a vault summary card into chat
      final vaultCard = isComplete
          ? MessageModel(
              content: '${vaults.length} vaults · 100% allocated',
              isUser: false,
              timestamp: DateTime.now(),
              messageType: MessageType.vaultSummary,
            )
          : null;

      state = state.copyWith(
        messages: [
          ...state.messages,
          ariaMessage,
          if (vaultCard != null) vaultCard,
        ],
        isLoading: false,
        // Once a vault plan exists it stays true — never reset by a non-plan reply
        vaultPlanExists: isComplete || state.vaultPlanExists,
        vaultRecommendations: isComplete ? vaults : state.vaultRecommendations,
        // Preserve existing profileData when reviewer returns null (vault-only update)
        profileData: (isComplete && response['profile_data'] != null)
            ? response['profile_data']
            : state.profileData,
      );
    } catch (e, st) {
      debugPrint('sendMessage error: $e\n$st');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // Called when user taps confirm on vault summary BottomSheet
  Future<void> confirmVaults() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _aiApi.confirmVaults(
        vaultRecommendations:
            state.vaultRecommendations.map((v) => v.toJson()).toList(),
        profileData: state.profileData ?? {},
      );
      state = state.copyWith(isLoading: false, vaultsSaved: true);
    } catch (e, st) {
      debugPrint('confirmVaults error: $e\n$st');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

// ─────────────────────────────────────────────
// PROVIDER
// ─────────────────────────────────────────────
final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>(
  (ref) => OnboardingNotifier(),
);
