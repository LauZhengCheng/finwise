// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : auth_api.dart
// Description   : API service for account profile operations —
//                 fetch and update user name and phone number
// First Written : 11-06-2026
// Edited on     : 11-06-2026
// ============================================

import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_config.dart';

class AuthApi {
  final Dio _dio = Dio();
  final String _baseUrl = AppConfig.baseUrl;

  String? get _token =>
      Supabase.instance.client.auth.currentSession?.accessToken;

  Options get _auth => Options(headers: {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      });

  // ─────────────────────────────────────────────
  // GET PROFILE
  // GET /api/auth/profile
  // Returns name, email, phone_number from profiles table.
  // ─────────────────────────────────────────────
  Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await _dio.get(
        '$_baseUrl/auth/profile',
        options: _auth,
      );
      return response.data['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(e.response?.data?['error'] ?? 'Failed to load profile');
    }
  }

  // ─────────────────────────────────────────────
  // UPDATE PROFILE
  // PATCH /api/auth/profile
  // Updates full_name and/or phone_number.
  // ─────────────────────────────────────────────
  Future<Map<String, dynamic>> updateProfile({
    String? fullName,
    String? phoneNumber,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (fullName != null) data['full_name'] = fullName;
      if (phoneNumber != null) data['phone_number'] = phoneNumber;

      final response = await _dio.patch(
        '$_baseUrl/auth/profile',
        data: data,
        options: _auth,
      );
      return response.data['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(e.response?.data?['error'] ?? 'Failed to update profile');
    }
  }
}
