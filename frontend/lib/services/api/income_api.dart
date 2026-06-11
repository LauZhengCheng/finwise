// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : income_api.dart
// Description   : API service for income/salary deposit endpoints
// First Written : 06-06-2026
// Edited on     : 06-06-2026
// ============================================

import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class IncomeApi {
  final Dio _dio = Dio();
  final String _baseUrl = 'http://192.168.100.15:3000/api';

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
}
