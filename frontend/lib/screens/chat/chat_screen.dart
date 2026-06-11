// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : chat_screen.dart
// Description   : AI Advisory Chat screen — persistent WhatsApp-style
//                 conversation with Aria. Full history always visible.
// First Written : 06-06-2026
// Edited on     : 11-06-2026
// ============================================

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../models/message_model.dart';
import '../../models/vault_model.dart';
import '../../providers/vault_provider.dart';
import '../../services/api/ai_api.dart';
import '../onboarding/widgets/chat_bubble.dart';
import '../onboarding/widgets/chat_input.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  // initialScrollOffset: 999999 gets clamped to maxScrollExtent during layout
  // so the list always opens at the last message with no scroll call needed.
  // keepScrollOffset: false ensures re-entry also starts at the bottom.
  final ScrollController _scrollController = ScrollController(
    initialScrollOffset: 999999,
    keepScrollOffset: false,
  );
  final List<MessageModel> _messages = [];

  bool _isHistoryLoading = true;
  bool _isReplying = false;
  bool _showGap = false;
  bool _shouldAnimateLastMessage = false;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  // Summarise the previous session first, then load history.
  // This ensures key_insights and the session boundary are up to date
  // before the user sends their first message.
  Future<void> _initChat() async {
    await AiApi().summarizeSession();
    await _loadHistory();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final raw = await AiApi().getChatHistory();
      final loaded = raw.map((m) => MessageModel(
            content: m['content'] as String,
            isUser: m['is_user'] as bool,
            timestamp: DateTime.parse(m['created_at'] as String),
          )).toList();

      setState(() {
        _messages.addAll(loaded);
        _isHistoryLoading = false;
      });
      // No scroll call needed — initialScrollOffset: 999999 clamps to bottom on first attach.
    } catch (_) {
      setState(() => _isHistoryLoading = false);
    }
  }

  Future<void> _sendMessage(String text) async {
    final userMsg = MessageModel(
      content: text,
      isUser: true,
      timestamp: DateTime.now(),
    );
    setState(() {
      _messages.add(userMsg);
      _isReplying = true;
      _showGap = true;
    });
    _scrollToMidScreen();

    try {
      final response = await AiApi().sendChatMessage(text);
      final reply = response['message'] as String? ?? '';

      final aiMsg = MessageModel(
        content: reply,
        isUser: false,
        timestamp: DateTime.now(),
      );
      setState(() {
        _messages.add(aiMsg);
        _isReplying = false;
        _shouldAnimateLastMessage = true;
      });

      // Aria proposed vault changes — show confirmation bottom sheet
      if (response['vault_plan_update'] != null && mounted) {
        _showVaultConfirmationSheet(
          response['vault_plan_update'] as Map<String, dynamic>,
        );
      }
    } catch (e) {
      setState(() {
        _isReplying = false;
        _showGap = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppTheme.errorColor,
        ));
      }
    }
  }

  // Scrolls to maxScrollExtent after setState so the frame with updated
  // padding is already rendered and maxScrollExtent is correct.
  void _scrollToBottom({bool animate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(
          max,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(max);
      }
    });
  }

  // After user sends: _showGap=true makes maxScrollExtent the mid-screen position.
  void _scrollToMidScreen() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  // Shows a bottom sheet listing exact vault changes (NEW / UPDATED / DELETED).
  // User must tap "Confirm Changes" to apply — swiping away does nothing.
  void _showVaultConfirmationSheet(Map<String, dynamic> vaultPlanUpdate) {
    final currentVaults = ref.read(vaultProvider).vaults;
    final newPlan = (vaultPlanUpdate['vaults'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final isTemporary = vaultPlanUpdate['is_temporary'] as bool? ?? false;
    final changeReason = vaultPlanUpdate['change_reason'] as String? ?? '';

    final currentKeyMap = {for (final v in currentVaults) v.categoryKey: v};
    final newKeySet = newPlan.map((v) => v['category_key'] as String).toSet();

    final newVaults = newPlan
        .where((v) => !currentKeyMap.containsKey(v['category_key'] as String))
        .toList();
    final deletedVaults = currentVaults
        .where((v) => !newKeySet.contains(v.categoryKey))
        .toList();
    final updatedVaults = newPlan.where((v) {
      final key = v['category_key'] as String;
      if (!currentKeyMap.containsKey(key)) return false;
      final current = currentKeyMap[key]!;
      return current.name != v['name'] as String ||
          current.allocationPercentage !=
              (v['allocation_percentage'] as num).toInt();
    }).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VaultChangesSheet(
        newVaults: newVaults,
        updatedVaults: updatedVaults,
        deletedVaults: deletedVaults,
        currentKeyMap: currentKeyMap,
        isTemporary: isTemporary,
        changeReason: changeReason,
        onConfirm: () async {
          await AiApi().applyVaultChanges(vaultPlanUpdate);
          ref.read(vaultProvider.notifier).fetchVaults();
        },
      ),
    );
  }

  // ── Date helpers ─────────────────────────────
  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Today';
    if (d == yesterday) return 'Yesterday';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: _buildAppBar(),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: Stack(
          children: [
            // Message list fills entire body — pill floats on top of it
            Positioned.fill(
              child: _buildMessageList(),
            ),
            // Input pill floats at the bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ChatInput(onSend: _sendMessage, isLoading: _isReplying),
            ),
          ],
        ),
      ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 0,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: const Color(0xBF15130F), // surfaceColor ~75% — warm gradient shows through
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
        onPressed: () => context.go('/dashboard'),
      ),
      title: Row(
        children: [
          // Avatar with green "online" dot
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                child: const Text(
                  'A',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              Positioned(
                bottom: 1,
                right: 1,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.surfaceColor,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Aria',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                'Your Financial Advisor',
                style: TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_isHistoryLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }

    if (_messages.isEmpty && !_isReplying) {
      return _buildEmptyState();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final children = <Widget>[];

        for (int i = 0; i < _messages.length; i++) {
          final msg = _messages[i];
          final showDate = i == 0 ||
              !_isSameDay(_messages[i - 1].timestamp, msg.timestamp);
          // Only the newest AI message gets the typewriter animation —
          // and only once (flag cleared in onAnimationComplete).
          final isNewestAi = !msg.isUser &&
              i == _messages.length - 1 &&
              !_isReplying &&
              _shouldAnimateLastMessage;

          children.add(Column(
            key: ValueKey(
                '${msg.timestamp.millisecondsSinceEpoch}_${msg.isUser}'),
            children: [
              if (showDate) _DateDivider(label: _formatDate(msg.timestamp)),
              ChatBubble(
                message: msg,
                shouldAnimate: isNewestAi,
                onAnimationComplete: isNewestAi
                    ? () {
                        setState(() {
                          _showGap = false;
                          _shouldAnimateLastMessage = false;
                        });
                        _scrollToBottom(animate: true);
                      }
                    : null,
              ),
            ],
          ));
        }

        if (_isReplying) children.add(const _TypingIndicator());

        return ListView(
          controller: _scrollController,
          padding: EdgeInsets.only(
            top: 12,
            // 96px clears the floating pill height so last message is never hidden.
            // Gap padding is added on top of that while Aria is replying.
            bottom: _showGap ? constraints.maxHeight * 0.5 : 96,
          ),
          children: children,
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
              child: const Text(
                'A',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Hi, I\'m Aria',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ask me anything about your finances — your vaults, goals, spending patterns, or anything else on your mind.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Date Divider ─────────────────────────────
class _DateDivider extends StatelessWidget {
  final String label;
  const _DateDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(
            child: Divider(color: AppTheme.glassBorderColor, thickness: 1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textHint,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const Expanded(
            child: Divider(color: AppTheme.glassBorderColor, thickness: 1),
          ),
        ],
      ),
    );
  }
}

// ─── Typing Indicator ─────────────────────────
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _bounces;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    // 3 dots staggered: each starts 0.2 cycles after the previous
    _bounces = List.generate(3, (i) {
      final start = i * 0.2;
      final end = (start + 0.5).clamp(0.0, 1.0);
      return TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween(begin: 0.0, end: -7.0)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 50,
        ),
        TweenSequenceItem(
          tween: Tween(begin: -7.0, end: 0.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 50,
        ),
      ]).animate(CurvedAnimation(
        parent: _controller,
        curve: Interval(start, end),
      ));
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
            child: const Text(
              'A',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Row(
            children: List.generate(
              3,
              (i) => AnimatedBuilder(
                animation: _bounces[i],
                builder: (_, __) => Transform.translate(
                  offset: Offset(0, _bounces[i].value),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.75),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Vault Changes Confirmation Bottom Sheet ──
class _VaultChangesSheet extends StatefulWidget {
  final List<Map<String, dynamic>> newVaults;
  final List<Map<String, dynamic>> updatedVaults;
  final List<VaultModel> deletedVaults;
  final Map<String, VaultModel> currentKeyMap;
  final bool isTemporary;
  final String changeReason;
  final Future<void> Function() onConfirm;

  const _VaultChangesSheet({
    required this.newVaults,
    required this.updatedVaults,
    required this.deletedVaults,
    required this.currentKeyMap,
    required this.isTemporary,
    required this.changeReason,
    required this.onConfirm,
  });

  @override
  State<_VaultChangesSheet> createState() => _VaultChangesSheetState();
}

class _VaultChangesSheetState extends State<_VaultChangesSheet> {
  bool _isApplying = false;

  @override
  Widget build(BuildContext context) {
    final hasChanges = widget.newVaults.isNotEmpty ||
        widget.updatedVaults.isNotEmpty ||
        widget.deletedVaults.isNotEmpty;

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text(
                'Review Vault Changes',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (widget.isTemporary) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'TEMPORARY',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (widget.changeReason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              widget.changeReason,
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ],
          const SizedBox(height: 16),
          if (!hasChanges)
            const Text(
              'No changes detected.',
              style: TextStyle(color: AppTheme.textSecondary),
            )
          else ...[
            ...widget.newVaults.map((v) => _ChangeTile(
                  label: v['name'] as String,
                  badge: 'NEW',
                  badgeColor: const Color(0xFF4CAF50),
                  detail: '${v['allocation_percentage']}% allocation',
                )),
            ...widget.updatedVaults.map((v) {
              final key = v['category_key'] as String;
              final current = widget.currentKeyMap[key]!;
              final newPct = (v['allocation_percentage'] as num).toInt();
              final parts = <String>[];
              if (current.name != v['name'] as String) {
                parts.add('"${current.name}" → "${v['name']}"');
              }
              if (current.allocationPercentage != newPct) {
                parts.add('${current.allocationPercentage}% → $newPct%');
              }
              return _ChangeTile(
                label: v['name'] as String,
                badge: 'UPDATED',
                badgeColor: AppTheme.primaryColor,
                detail: parts.join('  '),
              );
            }),
            ...widget.deletedVaults.map((v) => _ChangeTile(
                  label: v.name,
                  badge: 'DELETED',
                  badgeColor: AppTheme.errorColor,
                  detail: 'Removed from your vault plan',
                  strikethrough: true,
                )),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isApplying ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(
                        color: AppTheme.textSecondary.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancel',
                      style: TextStyle(color: AppTheme.textSecondary)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isApplying
                      ? null
                      : () async {
                          setState(() => _isApplying = true);
                          final nav = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await widget.onConfirm();
                            nav.pop();
                          } catch (e) {
                            nav.pop();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(e
                                    .toString()
                                    .replaceFirst('Exception: ', '')),
                                backgroundColor: AppTheme.errorColor,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isApplying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text(
                          'Confirm Changes',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 8),
        ],
      ),
    );
  }
}

// ─── Change Tile ──────────────────────────────
class _ChangeTile extends StatelessWidget {
  final String label;
  final String badge;
  final Color badgeColor;
  final String detail;
  final bool strikethrough;

  const _ChangeTile({
    required this.label,
    required this.badge,
    required this.badgeColor,
    required this.detail,
    this.strikethrough = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              badge,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: badgeColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                    decoration:
                        strikethrough ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (detail.isNotEmpty)
                  Text(
                    detail,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
