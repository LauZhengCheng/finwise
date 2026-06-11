// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : ai_api.dart
// Description   : API service for AI endpoints in FinWise
//                 Handles onboarding chat calls to backend
// First Written : 24-May-2026
// Edited on     : 31-May-2026
// ============================================

import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/message_model.dart';

class AiApi {
  final Dio _dio = Dio();
  final String _baseUrl = 'http://192.168.100.15:3000/api';

  // Get JWT token from current Supabase session
  String? get _token =>
      Supabase.instance.client.auth.currentSession?.accessToken;

  // ─────────────────────────────────────────────
  // SEND ONBOARDING MESSAGE
  // Sends user message + full history to backend
  // Returns AI response
  // ─────────────────────────────────────────────
  Future<Map<String, dynamic>> sendOnboardingMessage({
    required String message,
    required List<MessageModel> conversationHistory,
    List<Map<String, dynamic>>? currentVaults,
  }) async {
    try {
      final historyJson = conversationHistory
          .where((msg) => msg.messageType == MessageType.normal)
          .map((msg) => {
                'role': msg.isUser ? 'user' : 'assistant',
                'content': msg.content,
              })
          .toList();

      final response = await _dio.post(
        '$_baseUrl/ai/onboarding/chat',
        data: {
          'message': message,
          'conversation_history': historyJson,
          if (currentVaults != null) 'current_vaults': currentVaults,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $_token',
            'Content-Type': 'application/json',
          },
        ),
      );

      return response.data;
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['message'] ?? 'Failed to connect to AI service');
    }
  }

  // ─────────────────────────────────────────────
  // CONFIRM VAULTS
  // Called after user confirms vault recommendations
  // Saves all onboarding data to Supabase via backend
  // ─────────────────────────────────────────────
  Future<Map<String, dynamic>> confirmVaults({
    required List<Map<String, dynamic>> vaultRecommendations,
    required Map<String, dynamic> profileData,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/ai/onboarding/confirm-vaults',
        data: {
          'vault_recommendations': vaultRecommendations,
          'profile_data': profileData,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $_token',
            'Content-Type': 'application/json',
          },
        ),
      );

      return response.data;
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['message'] ?? 'Failed to save your vaults');
    }
  }

  // ─────────────────────────────────────────────
  // GET INITIAL GREETING
  // Called when onboarding screen first opens
  // Triggers Aria to send welcome message
  // ─────────────────────────────────────────────
  Future<Map<String, dynamic>> getInitialGreeting() async {
    try {
      final response = await _dio.post(
        '$_baseUrl/ai/onboarding/chat',
        data: {
          'message': '__INIT__',
          'conversation_history': [],
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $_token',
            'Content-Type': 'application/json',
          },
        ),
      );

      return response.data;
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['message'] ?? 'Failed to connect to AI service');
    }
  }

  // ─────────────────────────────────────────────
  // SUMMARIZE SESSION
  // POST /api/ai/chat/summarize
  // Called on chat screen open — summarises previous session
  // into key_insights and updates the session boundary.
  // Fire and forget — failures are silently ignored.
  // ─────────────────────────────────────────────
  Future<void> summarizeSession() async {
    try {
      await _dio.post(
        '$_baseUrl/ai/chat/summarize',
        options: Options(headers: {'Authorization': 'Bearer $_token'}),
      );
    } catch (_) {
      // Silently ignore — summarisation is best-effort
    }
  }

  // ─────────────────────────────────────────────
  // SEND ADVISORY CHAT MESSAGE
  // POST /api/ai/chat
  // Returns { message, vault_created?, vault? }
  // vault_created is true when Aria created a new vault this turn
  // ─────────────────────────────────────────────
  Future<Map<String, dynamic>> sendChatMessage(String message) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/ai/chat',
        data: {'message': message},
        options: Options(headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        }),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['message'] ?? 'Failed to reach Aria');
    }
  }

  // ─────────────────────────────────────────────
  // APPLY VAULT CHANGES
  // POST /api/ai/chat/apply-vault-changes
  // Called after user confirms vault changes via the bottom sheet.
  // ─────────────────────────────────────────────
  Future<void> applyVaultChanges(Map<String, dynamic> vaultPlanUpdate) async {
    try {
      await _dio.post(
        '$_baseUrl/ai/chat/apply-vault-changes',
        data: {'vault_plan_update': vaultPlanUpdate},
        options: Options(headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        }),
      );
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to apply vault changes');
    }
  }

  // ─────────────────────────────────────────────
  // GET MY PROFILE
  // GET /api/ai/profile
  // ─────────────────────────────────────────────
  Future<Map<String, dynamic>> getMyProfile() async {
    try {
      final response = await _dio.get(
        '$_baseUrl/ai/profile',
        options: Options(headers: {'Authorization': 'Bearer $_token'}),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to load profile');
    }
  }

  // ─────────────────────────────────────────────
  // GET CHAT HISTORY
  // GET /api/ai/chat/history
  // Returns all past messages for persistent display
  // ─────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getChatHistory() async {
    try {
      final response = await _dio.get(
        '$_baseUrl/ai/chat/history',
        options: Options(headers: {
          'Authorization': 'Bearer $_token',
        }),
      );
      final raw = response.data['messages'] as List<dynamic>;
      return raw.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['message'] ?? 'Failed to load chat history');
    }
  }
}