// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : debt_api.dart
// Description   : API service for debt CRUD operations
// First Written : 17-06-2026
// Edited on     : 17-06-2026
// ============================================

import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_config.dart';

class DebtApi {
  final Dio _dio = Dio();
  final String _baseUrl = AppConfig.baseUrl;

  String? get _token =>
      Supabase.instance.client.auth.currentSession?.accessToken;

  Options get _auth => Options(headers: {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      });

  Future<Map<String, dynamic>> getDebts() async {
    try {
      final response = await _dio.get(
        '$_baseUrl/debt',
        options: _auth,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to fetch debts');
    }
  }

  Future<Map<String, dynamic>> createDebt(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/debt',
        data: data,
        options: _auth,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to create debt');
    }
  }

  Future<void> updateDebt(String id, Map<String, dynamic> data) async {
    try {
      await _dio.patch(
        '$_baseUrl/debt/$id',
        data: data,
        options: _auth,
      );
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to update debt');
    }
  }

  Future<Map<String, dynamic>> getStrategy() async {
    try {
      final response = await _dio.get(
        '$_baseUrl/debt/strategy',
        options: _auth,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to fetch strategy');
    }
  }

  Future<void> deleteDebt(String id) async {
    try {
      await _dio.delete(
        '$_baseUrl/debt/$id',
        options: _auth,
      );
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to delete debt');
    }
  }
}
