// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : transaction_api.dart
// Description   : API service for transaction endpoints —
//                 initiate, execute, and cancel
// First Written : 06-06-2026
// Edited on     : 06-06-2026
// ============================================

import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_config.dart';

class TransactionApi {
  final Dio _dio = Dio();
  final String _baseUrl = AppConfig.baseUrl;

  String? get _token =>
      Supabase.instance.client.auth.currentSession?.accessToken;

  Options get _auth => Options(headers: {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      });

  // ─────────────────────────────────────────────
  // CATEGORIZE
  // Lightweight pre-step — AI suggests a vault, no money moved.
  // Returns { suggested_vault, all_vaults, categorization_failed }
  // ─────────────────────────────────────────────
  Future<Map<String, dynamic>> categorize({
    required String merchantId,
    required double amount,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/transactions/categorize',
        data: {'merchant_id': merchantId, 'amount': amount},
        options: _auth,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      final d = e.response?.data;
      final msg = (d is Map ? (d['message'] ?? d['error']) : null) as String?;
      throw Exception(msg ?? 'Categorisation failed (${e.response?.statusCode ?? 'no response'})');
    }
  }

  // ─────────────────────────────────────────────
  // INITIATE
  // Categorises merchant, checks balance, runs Goal Guardian.
  // Returns outcome: 'approved' | 'alert' | 'blocked' | 'categorisation_failed'
  // ─────────────────────────────────────────────
  Future<Map<String, dynamic>> initiate({
    required String merchantId,
    required double amount,
    String? vaultId,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/transactions/initiate',
        data: {
          'merchant_id': merchantId,
          'amount': amount,
          if (vaultId != null) 'vault_id': vaultId,
        },
        options: _auth,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['message'] ?? 'Transaction failed');
    }
  }

  // ─────────────────────────────────────────────
  // EXECUTE
  // Called when user presses "Proceed" on Goal Guardian popup.
  // Deducts vault and writes approved transaction.
  // ─────────────────────────────────────────────
  Future<void> execute(Map<String, dynamic> initiateResult) async {
    try {
      await _dio.post(
        '$_baseUrl/transactions/execute',
        data: {
          'merchant_id': initiateResult['merchant_id'],
          'vault_id': initiateResult['vault_id'],
          'amount': initiateResult['amount'],
          'goal_guardian_result': initiateResult['goal_guardian_result'],
          'categorisation_attempts': initiateResult['categorisation_attempts'] ?? 1,
        },
        options: _auth,
      );
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['message'] ?? 'Failed to complete transaction');
    }
  }

  // ─────────────────────────────────────────────
  // GET HISTORY
  // GET /api/transactions/history
  // Returns all transactions for the user, newest first
  // ─────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getHistory({String? vaultId}) async {
    try {
      String url = '$_baseUrl/transactions/history';
      if (vaultId != null) url += '?vault_id=$vaultId';
      final response = await _dio.get(url, options: _auth);
      final raw = response.data['transactions'] as List<dynamic>;
      return raw.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['message'] ?? 'Failed to load transactions');
    }
  }

  // ─────────────────────────────────────────────
  // CANCEL
  // Called when user presses "Cancel" on Goal Guardian popup.
  // Writes a cancelled transaction record.
  // ─────────────────────────────────────────────
  Future<void> cancel(Map<String, dynamic> initiateResult) async {
    try {
      await _dio.post(
        '$_baseUrl/transactions/cancel',
        data: {
          'merchant_id': initiateResult['merchant_id'],
          'vault_id': initiateResult['vault_id'],
          'amount': initiateResult['amount'],
          'goal_guardian_message': initiateResult['alert_message'],
        },
        options: _auth,
      );
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['message'] ?? 'Failed to cancel transaction');
    }
  }
}
