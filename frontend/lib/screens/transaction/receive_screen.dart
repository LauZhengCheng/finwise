// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : receive_screen.dart
// Description   : Receive screen — shows user's QR code and phone number
//                 so others can scan to send money via P2P transfer.
// First Written : 18-06-2026
// Edited on     : 18-06-2026
// ============================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_theme.dart';
import '../../widgets/shimmer_loading.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  String? _phone;
  String? _name;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  String? _error;

  Future<void> _loadProfile() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('full_name, phone_number')
          .eq('id', userId)
          .single();

      if (!mounted) return;
      setState(() {
        _phone = response['phone_number'] as String?;
        _name = response['full_name'] as String?;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load profile';
        _isLoading = false;
      });
    }
  }

  String get _qrData => jsonEncode({
        'qr_type': 'p2p_receive',
        'phone': _phone ?? '',
        'name': _name ?? '',
      });

  void _copyPhone() {
    if (_phone == null) return;
    Clipboard.setData(ClipboardData(text: _phone!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Phone number copied'), duration: Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: _isLoading
                    ? const Padding(padding: EdgeInsets.all(16), child: SkeletonHero())
                    : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: AppTheme.errorColor, fontSize: 14)))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const Text(
                              'Receive Money',
                              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppTheme.textPrimary, letterSpacing: -0.8),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Share your QR or phone number to receive transfers.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: 32),

                            // QR code card
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Column(
                                children: [
                                  QrImageView(
                                    data: _qrData,
                                    version: QrVersions.auto,
                                    size: 220,
                                    backgroundColor: Colors.white,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _name ?? '',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _phone ?? '',
                                    style: const TextStyle(fontSize: 15, color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Phone number row with copy
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              decoration: BoxDecoration(
                                color: AppTheme.cardColor,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppTheme.glassBorderColor),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.phone_rounded, color: AppTheme.textSecondary, size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _phone ?? 'No phone number',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _copyPhone,
                                    icon: const Icon(Icons.copy_rounded, color: AppTheme.primaryColor, size: 20),
                                    tooltip: 'Copy',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.auto_awesome_rounded, color: AppTheme.primaryColor, size: 18),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Text(
                                      'When someone sends you money, Aion will notify you and help decide which vault to put it in.',
                                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
