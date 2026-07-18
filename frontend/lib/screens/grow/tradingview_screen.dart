// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : tradingview_screen.dart
// Description   : Full-screen TradingView chart page with
//                 symbol change and dark theme.
// First Written : 25-06-2026
// Edited on     : 25-06-2026
// ============================================

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';

class TradingViewScreen extends StatelessWidget {
  const TradingViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0B08),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Icon(Icons.arrow_back_rounded,
                        color: AppTheme.textPrimary, size: 24),
                  ),
                  const SizedBox(width: 16),
                  const Text('Market Chart', style: TextStyle(
                    color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: InAppWebView(
                initialUrlRequest: URLRequest(
                  url: WebUri('https://s.tradingview.com/widgetembed/?frameElementId=tv&symbol=BINANCE:BTCUSDT&interval=D&theme=dark&style=1&locale=en&toolbar_bg=%230D0B08&enable_publishing=false&hide_side_toolbar=0&allow_symbol_change=1&save_image=false&backgroundColor=%230D0B08'),
                ),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  transparentBackground: true,
                  supportZoom: false,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
