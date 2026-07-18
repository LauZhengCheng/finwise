// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : bills_api.dart
// Description   : API service for bill reminders — CRUD operations
// First Written : 17-06-2026
// Edited on     : 17-06-2026
// ============================================

import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_config.dart';

class BillsApi {
  final Dio _dio = Dio();
  final String _baseUrl = AppConfig.baseUrl;

  String? get _token =>
      Supabase.instance.client.auth.currentSession?.accessToken;

  Options get _auth => Options(headers: {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      });

  Future<List<Map<String, dynamic>>> getBills() async {
    try {
      final response = await _dio.get(
        '$_baseUrl/bills',
        options: _auth,
      );
      final body = response.data as Map<String, dynamic>;
      final list = body['data'] as List? ?? [];
      return list.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to fetch bills');
    }
  }

  Future<Map<String, dynamic>> createBill(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/bills',
        data: data,
        options: _auth,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to create bill');
    }
  }

  Future<void> updateBill(String id, Map<String, dynamic> data) async {
    try {
      await _dio.patch(
        '$_baseUrl/bills/$id',
        data: data,
        options: _auth,
      );
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to update bill');
    }
  }

  Future<void> deleteBill(String id) async {
    try {
      await _dio.delete(
        '$_baseUrl/bills/$id',
        options: _auth,
      );
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to delete bill');
    }
  }
}
