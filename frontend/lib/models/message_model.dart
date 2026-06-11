// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : message_model.dart
// Description   : Message model for onboarding chat messages
// First Written : 24-May-2026
// Edited on     : 31-May-2026
// ============================================

enum MessageType { normal, vaultSummary }

class MessageModel {
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final MessageType messageType;

  MessageModel({
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.messageType = MessageType.normal,
  });
}
