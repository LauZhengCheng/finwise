// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : transfer_api.dart
// Description   : API service for P2P money transfers between users.
// First Written : 18-06-2026
// Edited on     : 18-06-2026
// ============================================

import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_config.dart';

class TransferApi {
  final Dio _dio = Dio();
  final String _baseUrl = AppConfig.baseUrl;

  String? get _token =>
      Supabase.instance.client.auth.currentSession?.accessToken;

  Options get _auth => Options(headers: {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      });

  // GET /api/transfer/lookup?phone=xxx
  Future<Map<String, dynamic>> lookupRecipient(String phone) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/transfer/lookup',
        queryParameters: {'phone': phone},
        options: _auth,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      final d = e.response?.data;
      final msg = (d is Map ? (d['error'] ?? d['message']) : null) as String?;
      throw Exception(msg ?? 'Failed to look up recipient');
    }
  }

  // POST /api/transfer/send
  Future<Map<String, dynamic>> sendTransfer({
    required String recipientPhone,
    required double amount,
    required String sourceVaultId,
    String? note,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/transfer/send',
        data: {
          'recipient_phone': recipientPhone,
          'amount': amount,
          'source_vault_id': sourceVaultId,
          if (note != null && note.isNotEmpty) 'note': note,
        },
        options: _auth,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      final d = e.response?.data;
      final msg = (d is Map ? (d['error'] ?? d['message']) : null) as String?;
      throw Exception(msg ?? 'Transfer failed. Please try again');
    }
  }

  // POST /api/transfer/allocate
  Future<Map<String, dynamic>> allocateTransfer({
    required List<String> transferIds,
    required String vaultId,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/transfer/allocate',
        data: {'transfer_ids': transferIds, 'vault_id': vaultId},
        options: _auth,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      final d = e.response?.data;
      final msg = (d is Map ? (d['error'] ?? d['message']) : null) as String?;
      throw Exception(msg ?? 'Failed to deposit transfer (${e.response?.statusCode ?? 'no response'})');
    }
  }

  // GET /api/transfer/history
  Future<List<dynamic>> getTransferHistory() async {
    try {
      final response = await _dio.get(
        '$_baseUrl/transfer/history',
        options: _auth,
      );
      return response.data['transfers'] as List<dynamic>;
    } on DioException catch (e) {
      final d = e.response?.data;
      final msg = (d is Map ? (d['error'] ?? d['message']) : null) as String?;
      throw Exception(msg ?? 'Failed to load transfer history');
    }
  }
}
