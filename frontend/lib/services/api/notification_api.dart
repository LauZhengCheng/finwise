// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : notification_api.dart
// Description   : API service for FCM token registration
//                 and notification history (bell icon).
// First Written : 18-06-2026
// Edited on     : 18-06-2026
// ============================================

import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_config.dart';

class NotificationApi {
  final Dio _dio = Dio();
  final String _baseUrl = AppConfig.baseUrl;

  Options get _auth => Options(headers: {
        'Authorization':
            'Bearer ${Supabase.instance.client.auth.currentSession?.accessToken}',
        'Content-Type': 'application/json',
      });

  Future<void> registerToken(String fcmToken) async {
    try {
      await _dio.post(
        '$_baseUrl/notifications/register-token',
        data: {'fcm_token': fcmToken},
        options: _auth,
      );
    } on DioException catch (_) {
      // Silent — token registration is best-effort, retried on next app open
    }
  }

  Future<void> clearToken() async {
    try {
      await _dio.delete(
        '$_baseUrl/notifications/clear-token',
        options: _auth,
      );
    } on DioException catch (_) {
      // Silent — token clear is best-effort on logout
    }
  }

  Future<Map<String, dynamic>> getHistory() async {
    try {
      final response = await _dio.get(
        '$_baseUrl/notifications/history',
        options: _auth,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      final d = e.response?.data;
      final msg = (d is Map ? (d['error'] ?? d['message']) : null) as String?;
      throw Exception(msg ?? 'Failed to load notifications');
    }
  }

  Future<void> markChatOpened() async {
    try {
      await _dio.post('$_baseUrl/notifications/mark-chat-opened', options: _auth);
    } catch (_) {}
  }
}
