// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : finance_api.dart
// Description   : API service for finance data — health score, net worth,
//                 spending forecast
// First Written : 17-06-2026
// Edited on     : 17-06-2026
// ============================================

import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_config.dart';

class FinanceApi {
  final Dio _dio = Dio();
  final String _baseUrl = AppConfig.baseUrl;

  String? get _token =>
      Supabase.instance.client.auth.currentSession?.accessToken;

  Options get _auth => Options(headers: {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      });

  Future<Map<String, dynamic>> getHealthScore() async {
    try {
      final response = await _dio.get(
        '$_baseUrl/finance/health-score',
        options: _auth,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['message'] ?? 'Failed to fetch health score');
    }
  }

  Future<Map<String, dynamic>> getFDRates() async {
    try {
      final response = await _dio.get(
        '$_baseUrl/finance/fd-rates',
        options: _auth,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['message'] ?? 'Failed to fetch FD rates');
    }
  }

  Future<Map<String, dynamic>> getNews() async {
    try {
      final response = await _dio.get(
        '$_baseUrl/finance/news',
        options: _auth,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['message'] ?? 'Failed to fetch news');
    }
  }

  Future<Map<String, dynamic>> getDeals() async {
    try {
      final response = await _dio.get(
        '$_baseUrl/finance/deals',
        options: _auth,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['message'] ?? 'Failed to fetch deals');
    }
  }

  Future<Map<String, dynamic>> getProtection() async {
    try {
      final response = await _dio.get(
        '$_baseUrl/finance/protection',
        options: _auth,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['message'] ?? 'Failed to fetch protection recommendations');
    }
  }

  Future<Map<String, dynamic>> getInsuranceCoverage() async {
    try {
      final response = await _dio.get('$_baseUrl/finance/insurance', options: _auth);
      return (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>? ?? {};
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to fetch insurance');
    }
  }

  Future<void> updateInsuranceCoverage(Map<String, bool> coverage) async {
    try {
      await _dio.patch('$_baseUrl/finance/insurance',
        data: {'coverage': coverage}, options: _auth);
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to update insurance');
    }
  }

  Future<Map<String, dynamic>> getTickerData() async {
    try {
      final response = await _dio.get('$_baseUrl/finance/ticker', options: _auth);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to fetch ticker');
    }
  }

  Future<Map<String, dynamic>> getSpendingForecast() async {
    try {
      final response = await _dio.get(
        '$_baseUrl/finance/spending-forecast',
        options: _auth,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['message'] ?? 'Failed to fetch spending forecast');
    }
  }
}
