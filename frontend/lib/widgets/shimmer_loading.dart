// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : shimmer_loading.dart
// Description   : Reusable shimmer skeleton widgets for loading states.
//                 Replaces CircularProgressIndicator on all list/card screens.
// First Written : 19-06-2026
// Edited on     : 19-06-2026
// ============================================

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

const Color _kBase      = Color(0xFF1E1B14);
const Color _kHighlight = Color(0xFF302B20);

// Single rounded-rectangle or circle placeholder
class _Sk extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  final bool circle;

  const _Sk({
    this.width,
    required this.height,
    this.radius = 6,
    this.circle = false,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: circle ? null : BorderRadius.circular(radius),
          shape: circle ? BoxShape.circle : BoxShape.rectangle,
        ),
      );
}

// Shimmer colour wrapper — all skeletons go through this
class AppShimmer extends StatelessWidget {
  final Widget child;
  const AppShimmer({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
        baseColor: _kBase,
        highlightColor: _kHighlight,
        child: child,
      );
}

// ── Safe-to-Spend hero skeleton ───────────────────────────────────────────────
class SkeletonHero extends StatelessWidget {
  const SkeletonHero({super.key});

  @override
  Widget build(BuildContext context) => AppShimmer(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _kBase,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Sk(width: 90, height: 11),
              SizedBox(height: 8),
              _Sk(width: 210, height: 46),
              SizedBox(height: 6),
              _Sk(width: 150, height: 13),
            ],
          ),
        ),
      );
}

// ── Fund card skeleton (matches fund_card.dart PageView card) ────────────────
class SkeletonFundCard extends StatelessWidget {
  const SkeletonFundCard({super.key});

  @override
  Widget build(BuildContext context) => AppShimmer(
        child: Container(
          height: 162,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          decoration: BoxDecoration(
            color: _kBase,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: _Sk(height: 16)),
                  SizedBox(width: 12),
                  _Sk(width: 50, height: 22, radius: 6),
                ],
              ),
              SizedBox(height: 10),
              _Sk(width: 155, height: 27),
              SizedBox(height: 14),
              _Sk(height: 5, radius: 4),
              SizedBox(height: 8),
              _Sk(width: 115, height: 11),
            ],
          ),
        ),
      );
}

// ── Vault row skeletons (matches vault_card.dart rows) ───────────────────────
class SkeletonVaultList extends StatelessWidget {
  final int count;
  const SkeletonVaultList({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) => AppShimmer(
        child: Column(
          children: List.generate(count, (i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const _Sk(width: 8, height: 8, circle: true),
                        const SizedBox(width: 10),
                        _Sk(width: 95 + (i * 18).toDouble(), height: 13),
                        const Spacer(),
                        const _Sk(width: 72, height: 14),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const _Sk(height: 4, radius: 4),
                    const SizedBox(height: 5),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _Sk(width: 58, height: 10),
                        _Sk(width: 132, height: 10),
                      ],
                    ),
                  ],
                ),
              )),
        ),
      );
}

// ── Transaction list skeletons ────────────────────────────────────────────────
class SkeletonTransactionList extends StatelessWidget {
  final int count;
  const SkeletonTransactionList({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) => AppShimmer(
        child: Container(
          decoration: BoxDecoration(
            color: _kBase,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: List.generate(count, (i) => Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      const _Sk(width: 36, height: 36, circle: true),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Sk(width: 95 + (i % 3) * 28.0, height: 13),
                            const SizedBox(height: 5),
                            const _Sk(width: 62, height: 10),
                          ],
                        ),
                      ),
                      const _Sk(width: 66, height: 14),
                    ],
                  ),
                )),
          ),
        ),
      );
}

// ── Chat bubble skeletons ──────────────────────────────────────────────────────
class SkeletonChatHistory extends StatelessWidget {
  const SkeletonChatHistory({super.key});

  @override
  Widget build(BuildContext context) => AppShimmer(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              _bubble(isUser: false, widths: const [190, 210, 145]),
              _bubble(isUser: true, widths: const [125]),
              _bubble(isUser: false, widths: const [205, 165]),
              _bubble(isUser: true, widths: const [165, 105]),
              _bubble(isUser: false, widths: const [185, 215, 125]),
            ],
          ),
        ),
      );

  Widget _bubble({required bool isUser, required List<double> widths}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          mainAxisAlignment:
              isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isUser) ...[
              const _Sk(width: 30, height: 30, circle: true),
              const SizedBox(width: 8),
            ],
            Column(
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: widths
                  .map((w) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: _Sk(width: w, height: 12, radius: 8),
                      ))
                  .toList(),
            ),
            if (isUser) ...[
              const SizedBox(width: 8),
              const _Sk(width: 30, height: 30, circle: true),
            ],
          ],
        ),
      );
}
