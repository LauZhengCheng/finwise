// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : main_scaffold.dart
// Description   : Persistent shell for the 4 main tabs.
//                 Floating pill nav bar with BackdropFilter blur.
//                 Scanner button elevated at centre — pushes /qr-scanner.
//                 Visual order: Home | Chat | [Scanner] | Transactions | Profile
// First Written : 10-06-2026
// Edited on     : 10-06-2026
// ============================================

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/app_theme.dart';
import 'transaction/transaction_history_screen.dart';

class MainScaffold extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  const MainScaffold({super.key, required this.navigationShell});

  // Visual positions: 0=Home, 1=Chat, 2=Scanner(push), 3=Transactions, 4=Profile
  // Shell indices:    0=Home, 1=Chat,                   2=Transactions, 3=Profile
  void _onNavTap(BuildContext context, WidgetRef ref, int visualIndex) {
    if (visualIndex == 2) {
      context.push('/qr-scanner');
      return;
    }
    final shellIndex = visualIndex > 2 ? visualIndex - 1 : visualIndex;
    // Transactions tab (shell index 2) — trigger a silent reload
    if (shellIndex == 2) {
      ref.read(transactionRefreshTriggerProvider.notifier).state++;
    }
    navigationShell.goBranch(
      shellIndex,
      initialLocation: shellIndex == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Stack(
        children: [
          navigationShell,
          // Hide nav bar on chat tab (index 1) — full-screen focused experience
          if (navigationShell.currentIndex != 1)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: _FloatingNavBar(
                currentShellIndex: navigationShell.currentIndex,
                onTap: (i) => _onNavTap(context, ref, i),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Floating pill nav bar ─────────────────────────────────────────────
class _FloatingNavBar extends StatelessWidget {
  final int currentShellIndex;
  final void Function(int visualIndex) onTap;
  const _FloatingNavBar({
    required this.currentShellIndex,
    required this.onTap,
  });

  // Shell index → visual position (scanner at visual 2 is skipped)
  int get _activeVisual =>
      currentShellIndex < 2 ? currentShellIndex : currentShellIndex + 1;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Glass pill
          ClipRRect(
            borderRadius: BorderRadius.circular(38),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0x1AFFFFFF), // ~10% white
                  borderRadius: BorderRadius.circular(38),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _NavItem(
                      icon: Icons.home_rounded,
                      visualIndex: 0,
                      activeVisual: _activeVisual,
                      onTap: onTap,
                    ),
                    _NavItem(
                      icon: Icons.chat_bubble_rounded,
                      visualIndex: 1,
                      activeVisual: _activeVisual,
                      onTap: onTap,
                    ),
                    const SizedBox(width: 60), // gap for scanner button
                    _NavItem(
                      icon: Icons.receipt_long_rounded,
                      visualIndex: 3,
                      activeVisual: _activeVisual,
                      onTap: onTap,
                    ),
                    _NavItem(
                      icon: Icons.person_rounded,
                      visualIndex: 4,
                      activeVisual: _activeVisual,
                      onTap: onTap,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Elevated scanner button (floats above the pill)
          Positioned(
            top: -20,
            child: GestureDetector(
              onTap: () => onTap(2),
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppTheme.goldGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.55),
                      blurRadius: 22,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: AppTheme.goldBright.withValues(alpha: 0.15),
                      blurRadius: 34,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Color(0xFF0A0A0F),
                  size: 26,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Single nav icon ───────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final IconData icon;
  final int visualIndex;
  final int activeVisual;
  final void Function(int) onTap;
  const _NavItem({
    required this.icon,
    required this.visualIndex,
    required this.activeVisual,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = visualIndex == activeVisual;
    return GestureDetector(
      onTap: () => onTap(visualIndex),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: Curves.easeOut,
          transitionBuilder: (child, anim) => ScaleTransition(
            scale: anim,
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: Icon(
            icon,
            key: ValueKey(active),
            size: active ? 26 : 22,
            color: active ? AppTheme.primaryColor : AppTheme.silverMuted,
          ),
        ),
      ),
    );
  }
}
