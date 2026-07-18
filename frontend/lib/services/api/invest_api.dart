// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : invest_api.dart
// Description   : API service for investment portfolio — CRUD,
//                 risk score, and Aion analysis.
// First Written : 24-06-2026
// Edited on     : 24-06-2026
// ============================================

import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_config.dart';

class InvestApi {
  final Dio _dio = Dio();
  final String _baseUrl = AppConfig.baseUrl;

  String? get _token =>
      Supabase.instance.client.auth.currentSession?.accessToken;

  Options get _auth => Options(headers: {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      });

  Future<List<Map<String, dynamic>>> getInvestments() async {
    try {
      final response = await _dio.get('$_baseUrl/invest', options: _auth);
      final body = response.data as Map<String, dynamic>;
      return (body['data'] as List? ?? []).cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to fetch investments');
    }
  }

  Future<Map<String, dynamic>> saveAll(List<Map<String, dynamic>> holdings) async {
    try {
      final response = await _dio.post('$_baseUrl/invest/save-all',
        data: {'holdings': holdings}, options: _auth);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to save holdings');
    }
  }

  Future<Map<String, dynamic>> getRisk() async {
    try {
      final response = await _dio.get('$_baseUrl/invest/risk', options: _auth);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to fetch risk');
    }
  }

  Future<List<Map<String, dynamic>>> getCryptoPrices() async {
    try {
      final response = await _dio.get('$_baseUrl/invest/crypto-prices', options: _auth);
      final body = response.data as Map<String, dynamic>;
      return (body['data'] as List? ?? []).cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to fetch crypto prices');
    }
  }

  Future<Map<String, dynamic>> getStockQuote(String ticker) async {
    try {
      final response = await _dio.get('$_baseUrl/invest/quote/$ticker', options: _auth);
      final body = response.data as Map<String, dynamic>;
      return (body['data'] as Map<String, dynamic>?) ?? {};
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to fetch quote');
    }
  }

  Future<List<Map<String, dynamic>>> getListings({String? category}) async {
    try {
      String url = '$_baseUrl/invest/listings';
      if (category != null) url += '?category=$category';
      final response = await _dio.get(url, options: _auth);
      final body = response.data as Map<String, dynamic>;
      return (body['data'] as List? ?? []).cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to fetch listings');
    }
  }

  Future<String> getAnalysis() async {
    try {
      final response = await _dio.get('$_baseUrl/invest/analysis', options: _auth);
      final body = response.data as Map<String, dynamic>;
      return (body['data'] as Map<String, dynamic>?)?['analysis'] as String? ?? 'No analysis available';
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to fetch analysis');
    }
  }
}
