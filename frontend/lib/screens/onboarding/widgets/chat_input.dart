// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : chat_input.dart
// Description   : Chat input widget — floating pill (ChatGPT style).
//                 Single pill contains text field + send button.
//                 Floats over the message list via Stack in chat_screen.
// First Written : 24-May-2026
// Edited on     : 11-06-2026
// ============================================

import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';

class ChatInput extends StatefulWidget {
  final Function(String) onSend;
  final bool isLoading;

  const ChatInput({
    super.key,
    required this.onSend,
    required this.isLoading,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.isLoading) return;
    widget.onSend(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xF01E1B14), // cardColor ~94% — pill is clean, no artifact
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(width: 18),

              // Text field — transparent inside the pill
              Expanded(
                child: TextField(
                  controller: _controller,
                  enabled: !widget.isLoading,
                  maxLines: null,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                  ),
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    filled: false,
                    hintText: widget.isLoading
                        ? 'Aion is thinking...'
                        : 'Type your message...',
                    hintStyle: const TextStyle(
                      color: AppTheme.textHint,
                      fontSize: 14,
                    ),
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                  onSubmitted: (_) => _handleSend(),
                ),
              ),

              const SizedBox(width: 8),

              // Send button nestled inside the right curve of the pill
              Padding(
                padding: const EdgeInsets.all(5),
                child: GestureDetector(
                  onTap: _handleSend,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: widget.isLoading
                          ? AppTheme.silverMuted
                          : AppTheme.primaryColor,
                      shape: BoxShape.circle,
                      boxShadow: widget.isLoading
                          ? null
                          : [
                              BoxShadow(
                                color: AppTheme.primaryColor
                                    .withValues(alpha: 0.55),
                                blurRadius: 12,
                                spreadRadius: 1,
                                offset: const Offset(0, 1),
                              ),
                              BoxShadow(
                                color: AppTheme.goldBright
                                    .withValues(alpha: 0.12),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                    ),
                    child: widget.isLoading
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
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
