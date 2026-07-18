// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : notification_provider.dart
// Description   : Riverpod provider for Aion notification history.
//                 Feeds the bell badge count and history sheet.
// First Written : 12-06-2026
// Edited on     : 18-06-2026
// ============================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api/notification_api.dart';

class NotificationHistoryState {
  final List<Map<String, dynamic>> notifications;
  final int unreadCount;
  final bool isLoading;

  const NotificationHistoryState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.isLoading = false,
  });

  // Latest unread notification message — shown in dashboard notification card
  String? get latestUnreadMessage {
    final unread = notifications.where((n) => n['is_replied'] == false).toList();
    if (unread.isEmpty) return null;
    return unread.first['message'] as String?;
  }
}

class NotificationNotifier extends StateNotifier<NotificationHistoryState> {
  NotificationNotifier() : super(const NotificationHistoryState());

  Future<void> fetch() async {
    state = NotificationHistoryState(
      notifications: state.notifications,
      unreadCount: state.unreadCount,
      isLoading: true,
    );
    try {
      final data = await NotificationApi().getHistory();
      final list = (data['notifications'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      final unread = data['unread_count'] as int? ?? 0;
      state = NotificationHistoryState(
        notifications: list,
        unreadCount: unread,
        isLoading: false,
      );
    } catch (_) {
      state = NotificationHistoryState(
        notifications: state.notifications,
        unreadCount: state.unreadCount,
        isLoading: false,
      );
    }
  }
}

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationHistoryState>(
  (ref) => NotificationNotifier(),
);
