// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : chat_bubble.dart
// Description   : Chat bubble widget — luxury dark theme.
//                 AI messages = plain text on background (ChatGPT/Claude/Gemini style).
//                 User messages = gold gradient bubble.
//                 Both show timestamps beneath.
// First Written : 24-May-2026
// Edited on     : 11-06-2026
// ============================================

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../models/message_model.dart';

class ChatBubble extends StatefulWidget {
  final MessageModel message;
  final VoidCallback? onViewPlan;
  final VoidCallback? onAnimationComplete;
  final bool shouldAnimate;

  const ChatBubble({
    super.key,
    required this.message,
    this.onViewPlan,
    this.onAnimationComplete,
    this.shouldAnimate = false,
  });

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> {
  String _displayedText = '';
  Timer? _timer;
  int _charIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.shouldAnimate && !widget.message.isUser) {
      _startTypewriter();
    } else {
      _displayedText = widget.message.content;
    }
  }

  void _startTypewriter() {
    final content = widget.message.content;
    _timer = Timer.periodic(const Duration(milliseconds: 18), (timer) {
      if (!mounted) { timer.cancel(); return; }
      if (_charIndex < content.length) {
        _charIndex++;
        // Advance past high surrogate pair to avoid broken characters
        if (_charIndex < content.length &&
            content.codeUnitAt(_charIndex - 1) >= 0xD800 &&
            content.codeUnitAt(_charIndex - 1) <= 0xDBFF) {
          _charIndex++;
        }
        setState(() {
          _displayedText = content.substring(0, _charIndex);
        });
      } else {
        timer.cancel();
        widget.onAnimationComplete?.call();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.message.messageType == MessageType.vaultSummary) {
      return _VaultSummaryCard(
        summary: widget.message.content,
        onViewPlan: widget.onViewPlan,
      );
    }

    return widget.message.isUser ? _buildUserBubble() : _buildAriaMessage();
  }

  // ── Aria message — plain text on dark background (ChatGPT / Claude / Gemini style)
  Widget _buildAriaMessage() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 24, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayedText,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14.5,
                    height: 1.65,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _formatTime(widget.message.timestamp),
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppTheme.textHint,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── User bubble — gold gradient, right-aligned
  // Row(end) + Flexible prevents Container with BoxDecoration from expanding to full width.
  Widget _buildUserBubble() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(64, 5, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: const BoxDecoration(
                    gradient: AppTheme.goldGradient,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(4),
                    ),
                  ),
                  child: Text(
                    widget.message.content,
                    style: const TextStyle(
                      color: Color(0xFF1A1200),
                      fontSize: 14,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            _formatTime(widget.message.timestamp),
            style: const TextStyle(
              fontSize: 10.5,
              color: AppTheme.textHint,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// VAULT SUMMARY CARD — gold-bordered dark card
// ─────────────────────────────────────────────
class _VaultSummaryCard extends StatelessWidget {
  final String summary;
  final VoidCallback? onViewPlan;

  const _VaultSummaryCard({required this.summary, this.onViewPlan});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF242018), Color(0xFF0F0D09)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.25),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Vault Plan Ready',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      summary,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onViewPlan,
                child: const Text(
                  'View Plan',
                  style: TextStyle(color: AppTheme.primaryColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
