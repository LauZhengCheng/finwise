// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : achievement_api.dart
// Description   : API service for user achievements — read only
// First Written : 17-06-2026
// Edited on     : 17-06-2026
// ============================================

import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_config.dart';

class AchievementApi {
  final Dio _dio = Dio();
  final String _baseUrl = AppConfig.baseUrl;

  String? get _token =>
      Supabase.instance.client.auth.currentSession?.accessToken;

  Options get _auth => Options(headers: {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      });

  Future<List<Map<String, dynamic>>> getAchievements() async {
    try {
      final response = await _dio.get(
        '$_baseUrl/achievements',
        options: _auth,
      );
      final body = response.data;
      final list = body is List ? body : (body as Map<String, dynamic>)['data'] as List? ?? [];
      return list.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['message'] ?? 'Failed to fetch achievements');
    }
  }
}
