// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : welcome_screen.dart
// Description   : Welcome screen with entrance animations —
//                 logo pulse, text fade-in, buttons slide up.
// First Written : 21-May-2026
// Edited on     : 26-06-2026
// ============================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with TickerProviderStateMixin {
  late AnimationController _logoCtrl;
  late AnimationController _contentCtrl;
  late Animation<double> _logoScale;
  late Animation<double> _logoGlow;
  late Animation<double> _titleFade;
  late Animation<double> _subtitleFade;
  late Animation<Offset> _buttonsSlide;
  late Animation<double> _buttonsFade;

  @override
  void initState() {
    super.initState();

    _logoCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _contentCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));

    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: const Interval(0.0, 0.6, curve: Curves.elasticOut)));
    _logoGlow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: const Interval(0.4, 1.0, curve: Curves.easeOut)));

    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentCtrl, curve: const Interval(0.0, 0.4, curve: Curves.easeOut)));
    _subtitleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentCtrl, curve: const Interval(0.2, 0.6, curve: Curves.easeOut)));
    _buttonsSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _contentCtrl, curve: const Interval(0.4, 1.0, curve: Curves.easeOut)));
    _buttonsFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentCtrl, curve: const Interval(0.4, 1.0, curve: Curves.easeOut)));

    _logoCtrl.forward();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _contentCtrl.forward();
    });
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(),

                // Animated logo
                AnimatedBuilder(
                  animation: _logoCtrl,
                  builder: (_, __) => Transform.scale(
                    scale: _logoScale.value,
                    child: Container(
                      width: 100, height: 100,
                      decoration: BoxDecoration(
                        gradient: AppTheme.goldGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.4 * _logoGlow.value),
                            blurRadius: 28 * _logoGlow.value,
                            spreadRadius: 2 * _logoGlow.value,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 48,
                        color: Color(0xFF0A0800),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Animated title
                FadeTransition(
                  opacity: _titleFade,
                  child: const Text(
                    'FinWise',
                    style: TextStyle(
                      fontSize: 36, fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary),
                  ),
                ),
                const SizedBox(height: 12),

                // Animated subtitle
                FadeTransition(
                  opacity: _subtitleFade,
                  child: const Text(
                    'Your 24/7 AI Financial Advisor',
                    style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ),

                const Spacer(),

                // Animated buttons
                SlideTransition(
                  position: _buttonsSlide,
                  child: FadeTransition(
                    opacity: _buttonsFade,
                    child: Column(children: [
                      ElevatedButton(
                        onPressed: () => context.go('/register'),
                        child: const Text('Get Started',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () => context.go('/login'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                          side: const BorderSide(color: AppTheme.primaryColor),
                        ),
                        child: const Text('I already have an account',
                          style: TextStyle(fontSize: 16, color: AppTheme.primaryColor, fontWeight: FontWeight.w600)),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
