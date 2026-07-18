// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : qr_scanner_screen.dart
// Description   : QR scanner screen — reads merchant or salary QR codes.
//                 Salary QR navigates to salary deposit flow.
//                 Merchant QR navigates to merchant pay screen.
// First Written : 06-06-2026
// Edited on     : 06-06-2026
// ============================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../config/app_theme.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _scanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    setState(() => _scanned = true);
    _controller.stop();

    try {
      final payload =
          jsonDecode(barcode!.rawValue!) as Map<String, dynamic>;

      void restart() {
        if (mounted) {
          setState(() => _scanned = false);
          _controller.start();
        }
      }

      if (payload['qr_type'] == 'salary_deposit') {
        context.push('/salary-deposit', extra: payload).then((_) => restart());
      } else if (payload['qr_type'] == 'general_deposit') {
        context.push('/general-deposit', extra: payload).then((_) => restart());
      } else if (payload['qr_type'] == 'p2p_receive') {
        final phone = payload['phone'] as String? ?? '';
        context.push('/transfer', extra: phone).then((_) => restart());
      } else {
        context.push('/merchant-pay', extra: payload).then((_) => restart());
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid QR code — please scan a FinWise QR'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      setState(() => _scanned = false);
      _controller.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Camera access denied.\nPlease enable camera permission in Settings.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
            ),
          ),

          // Floating back + torch row
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    IconButton(
                      icon: const Icon(Icons.flash_on_rounded, color: Colors.white),
                      onPressed: () => _controller.toggleTorch(),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Overlay with scan frame
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppTheme.primaryColor,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          // Instruction text
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const Text(
                  'Point camera at a FinWise QR code',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Supported: Merchant QR • Salary QR',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
