// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : income_api.dart
// Description   : API service for income/salary deposit endpoints.
//                 Salary uses 2-step flow: stageIncome → dashboard choice → applyIncome.
// First Written : 06-06-2026
// Edited on     : 18-06-2026
// ============================================

import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_config.dart';

class IncomeApi {
  final Dio _dio = Dio();
  final String _baseUrl = AppConfig.baseUrl;

  String? get _token =>
      Supabase.instance.client.auth.currentSession?.accessToken;

  // ─────────────────────────────────────────────
  // INJECT INCOME
  // POST /api/income/inject
  // Sends salary amount to backend Traffic Controller.
  // Backend splits it across vaults by allocation_percentage.
  // ─────────────────────────────────────────────
  Future<Map<String, dynamic>> injectIncome({required double amount}) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/income/inject',
        data: {'amount': amount},
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
          e.response?.data?['message'] ?? 'Failed to process salary deposit');
    }
  }

  // ─────────────────────────────────────────────
  // GENERAL DEPOSIT
  // POST /api/income/deposit
  // Deposits amount into a specific vault.
  // Increases both current_balance and allocated_amount.
  // ─────────────────────────────────────────────
  Future<Map<String, dynamic>> depositToVault({
    required String vaultId,
    required double amount,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/income/deposit',
        data: {'vault_id': vaultId, 'amount': amount},
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
          e.response?.data?['message'] ?? 'Failed to process deposit');
    }
  }

  // ─────────────────────────────────────────────
  // STAGE INCOME
  // POST /api/income/stage
  // Saves a pending salary record. Vaults NOT updated yet.
  // Returns injection_id and total_carryover for the dashboard card.
  // ─────────────────────────────────────────────
  Future<Map<String, dynamic>> stageIncome({required double amount}) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/income/stage',
        data: {'amount': amount},
        options: Options(headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        }),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to stage income');
    }
  }

  // ─────────────────────────────────────────────
  // APPLY INCOME
  // POST /api/income/apply
  // Applies a staged income: carry_over adds on top, sweep moves spending
  // vault balances to a goal vault first then applies fresh allocation.
  // ─────────────────────────────────────────────
  Future<Map<String, dynamic>> applyIncome({
    required String injectionId,
    required String mode,
    String? goalVaultId,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/income/apply',
        data: {
          'injection_id': injectionId,
          'mode': mode,
          if (goalVaultId != null) 'goal_vault_id': goalVaultId,
        },
        options: Options(headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        }),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to apply income');
    }
  }

  // ─────────────────────────────────────────────
  // GET PENDING INCOME
  // GET /api/income/pending
  // Returns pending income metadata or null if none.
  // ─────────────────────────────────────────────
  Future<Map<String, dynamic>?> getPendingIncome() async {
    try {
      final response = await _dio.get(
        '$_baseUrl/income/pending',
        options: Options(headers: {
          'Authorization': 'Bearer $_token',
        }),
      );
      return response.data['pending'] as Map<String, dynamic>?;
    } on DioException catch (_) {
      return null;
    }
  }
}
