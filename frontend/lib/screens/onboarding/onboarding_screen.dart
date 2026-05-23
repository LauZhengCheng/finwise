// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : onboarding_screen.dart
// Description   : Onboarding placeholder screen for FYP Neobanking.
//                 Will be fully built in Week 2.
// First Written : 21-May-2026
// Edited on     : 21-May-2026
// ============================================

import 'package:flutter/material.dart';
import '../../config/app_theme.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.psychology,
              color: AppTheme.primaryColor,
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              'Meet Your AI Advisor',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Onboarding will be built in Week 2',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}