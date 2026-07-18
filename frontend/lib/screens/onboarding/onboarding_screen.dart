// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : onboarding_screen.dart
// Description   : AI onboarding chat screen for FinWise
//                 Aion converses with user to create personalised vaults
// First Written : 21-May-2026
// Edited on     : 31-May-2026
// ============================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/vault_provider.dart';
import '../../models/message_model.dart';
import '../../models/vault_model.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/chat_input.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final ScrollController _scrollController = ScrollController();
  DateTime? _animatingMessageTimestamp;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(onboardingProvider.notifier).loadInitialGreeting();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Scrolls so user's bubble sits at ~50% of screen, leaving space for Aion's reply
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Show vault recommendations summary
  void _showVaultSummary(List<VaultModel> vaults, Map<String, dynamic> profileData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => _VaultSummarySheet(
        vaults: vaults,
        profileData: profileData,
        onConfirm: () async {
          await ref.read(onboardingProvider.notifier).confirmVaults();
          if (context.mounted && ref.read(onboardingProvider).vaultsSaved) {
            ref.read(vaultProvider.notifier).fetchVaults();
            Navigator.pop(context);
            context.go('/dashboard');
          }
        },
        onDiscuss: () {
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);

    // Show vault summary whenever showVaultSheet becomes true
    // Triggers on first proposal AND every re-proposal after discussions
    ref.listen<OnboardingState>(onboardingProvider, (previous, next) {
      final prevCount = previous?.messages.length ?? 0;
      if (next.messages.length > prevCount && next.messages.isNotEmpty) {
        final newest = next.messages.last;
        if (newest.isUser) {
          _scrollToBottom();
        } else {
          // A vault card may be appended alongside a normal message in one
          // state update, making newest.last point to the card instead of
          // the text bubble. Search all newly added messages for the last
          // normal Aion message so the typewriter effect is never skipped.
          final newMessages = next.messages.sublist(prevCount);
          final normalMsgs = newMessages
              .where((m) => !m.isUser && m.messageType == MessageType.normal)
              .toList();
          if (normalMsgs.isNotEmpty) {
            setState(() => _animatingMessageTimestamp = normalMsgs.last.timestamp);
          }
        }
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
        children: [
          // ── Aion header ───────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceColor,
              border: Border(
                bottom: BorderSide(color: AppTheme.glassBorderColor),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppTheme.primaryColor,
                  child: const Text(
                    'A',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Aion',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      state.isLoading ? 'Typing...' : 'Your Financial Advisor',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Chat messages list
          Expanded(
            child: state.messages.isEmpty && state.isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Connecting to your advisor...',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(top: 12, bottom: 180),
                    children: () {
                      final lastVaultCardIndex = state.messages.lastIndexWhere(
                        (m) => m.messageType == MessageType.vaultSummary,
                      );
                      return state.messages.asMap().entries.map((entry) {
                        final index = entry.key;
                        final msg = entry.value;
                        return ChatBubble(
                          message: msg,
                          shouldAnimate: msg.timestamp == _animatingMessageTimestamp,
                          onAnimationComplete: msg.timestamp == _animatingMessageTimestamp
                              ? () => setState(() => _animatingMessageTimestamp = null)
                              : null,
                          onViewPlan: msg.messageType == MessageType.vaultSummary
                              ? (index == lastVaultCardIndex
                                  ? () => _showVaultSummary(
                                        state.vaultRecommendations,
                                        state.profileData ?? {},
                                      )
                                  : null)
                              : null,
                        );
                      }).toList();
                    }(),
                  ),
          ),

          // Typing indicator — shown while waiting for Aion's response
          if (state.isLoading && state.messages.isNotEmpty)
            const _TypingIndicatorBubble(),

          // Error message if any
          if (state.error != null)
            Container(
              padding: const EdgeInsets.all(8),
              color: AppTheme.errorColor.withValues(alpha: 0.1),
              child: const Text(
                'Something went wrong. Please try again.',
                style: TextStyle(
                  color: AppTheme.errorColor,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          // Chat input
          ChatInput(
            isLoading: state.isLoading,
            onSend: (message) {
              ref.read(onboardingProvider.notifier).sendMessage(message);
            },
          ),
        ],
      ),        // closes Column
        ),      // closes SafeArea
      ),        // closes DecoratedBox
    );
  }
}

// ─────────────────────────────────────────────
// VAULT SUMMARY BOTTOM SHEET
// Shows vault recommendations after onboarding
// ─────────────────────────────────────────────
class _VaultSummarySheet extends StatelessWidget {
  final List<VaultModel> vaults;
  final Map<String, dynamic> profileData;
  final VoidCallback onConfirm;
  final VoidCallback onDiscuss;

  const _VaultSummarySheet({
    required this.vaults,
    required this.profileData,
    required this.onConfirm,
    required this.onDiscuss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.textSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Your Personalised Vaults',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ),

          // Vault list — split into Spending Vaults and Saving Funds sections
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                if (vaults.any((v) => v.vaultType == 'vault')) ...[
                  _buildSectionHeader('MY VAULTS', 'Spending'),
                  ...vaults
                      .where((v) => v.vaultType == 'vault')
                      .map(_buildVaultCard),
                  const SizedBox(height: 8),
                ],
                if (vaults.any((v) => v.vaultType == 'fund')) ...[
                  _buildSectionHeader('MY GOALS', 'Saving Goals'),
                  ...vaults
                      .where((v) => v.vaultType == 'fund')
                      .map(_buildVaultCard),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),

          // Confirm + discuss buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: onConfirm,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Looks good! Let\'s get started',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: onDiscuss,
                  child: const Text(
                    'I want to discuss changes',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '· $subtitle',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVaultCard(VaultModel vault) {
    final colour = _hexToColor(vault.vaultColour);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colour.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colour,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.account_balance_wallet,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vault.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (vault.linkedGoal != null)
                  Text(
                    vault.linkedGoal!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '${vault.allocationPercentage}%',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: colour,
            ),
          ),
        ],
      ),
    );
  }

  Color _hexToColor(String hex) {
    try {
      return Color(int.parse(hex.replaceAll('#', '0xFF')));
    } catch (e) {
      return Colors.blue;
    }
  }
}

// ─────────────────────────────────────────────
// TYPING INDICATOR BUBBLE
// Shows animated 3-dot bubble while Aion is responding
// ─────────────────────────────────────────────
class _TypingIndicatorBubble extends StatefulWidget {
  const _TypingIndicatorBubble();

  @override
  State<_TypingIndicatorBubble> createState() => _TypingIndicatorBubbleState();
}

class _TypingIndicatorBubbleState extends State<_TypingIndicatorBubble>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();

    _controllers = List.generate(
      3,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      ),
    );

    _animations = _controllers
        .map((c) => Tween<double>(begin: 0, end: -6).animate(
              CurvedAnimation(parent: c, curve: Curves.easeInOut),
            ))
        .toList();

    // Stagger each dot by 150ms so they bounce one after another
    _controllers[0].repeat(reverse: true);
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _controllers[1].repeat(reverse: true);
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _controllers[2].repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.primaryColor,
            child: Text(
              'A',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: AppTheme.glassBorderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return AnimatedBuilder(
                  animation: _animations[i],
                  builder: (_, __) => Transform.translate(
                    offset: Offset(0, _animations[i].value),
                    child: Container(
                      width: 7,
                      height: 7,
                      margin: EdgeInsets.only(right: i < 2 ? 5 : 0),
                      decoration: const BoxDecoration(
                        color: AppTheme.textSecondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}