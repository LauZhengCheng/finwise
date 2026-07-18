// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : vault_api.dart
// Description   : API service for vault operations — Active Pilot transfer
// First Written : 06-06-2026
// Edited on     : 06-06-2026
// ============================================

import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_config.dart';

class VaultApi {
  final Dio _dio = Dio();
  final String _baseUrl = AppConfig.baseUrl;

  String? get _token =>
      Supabase.instance.client.auth.currentSession?.accessToken;

  Options get _auth => Options(headers: {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      });

  // ─────────────────────────────────────────────
  // ARCHIVE GOAL
  // POST /api/vaults/:id/archive
  // Hides a completed goal from the dashboard.
  // ─────────────────────────────────────────────
  Future<void> archiveGoal(String vaultId) async {
    try {
      await _dio.post('$_baseUrl/vaults/$vaultId/archive', options: _auth);
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Archive failed');
    }
  }

  // ─────────────────────────────────────────────
  // UNARCHIVE GOAL
  // POST /api/vaults/:id/unarchive
  // Restores an archived goal to the dashboard.
  // ─────────────────────────────────────────────
  Future<void> unarchiveGoal(String vaultId) async {
    try {
      await _dio.post('$_baseUrl/vaults/$vaultId/unarchive', options: _auth);
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Unarchive failed');
    }
  }

  // ─────────────────────────────────────────────
  // TRANSFER
  // POST /api/vaults/transfer
  // Active Pilot: moves money between vaults.
  // ─────────────────────────────────────────────
  Future<Map<String, dynamic>> transfer({
    required String fromVaultId,
    required String toVaultId,
    required double amount,
    String? triggeredByTransactionId,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/vaults/transfer',
        data: {
          'from_vault_id': fromVaultId,
          'to_vault_id': toVaultId,
          'amount': amount,
          if (triggeredByTransactionId != null)
            'triggered_by_transaction_id': triggeredByTransactionId,
        },
        options: _auth,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['message'] ?? 'Transfer failed');
    }
  }
}
