// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : app_constants.dart
// Description   : Global constants for FYP Neobanking Flutter app.
//                 Centralises all enum values, status codes,
//                 and configuration constants.
// First Written : 21-May-2026
// Edited on     : 21-May-2026
// ============================================

class TransactionStatus {
  static const String approved = 'approved';
  static const String blocked = 'blocked';
  static const String cancelled = 'cancelled';
}

class TransactionType {
  static const String expense = 'expense';
  static const String income = 'income';
  static const String transfer = 'transfer';
}

class VaultType {
  static const String vault = 'vault';
  static const String fund = 'fund';
}

class TransferType {
  static const String activePilot = 'active_pilot';
  static const String userRequested = 'user_requested';
  static const String aiSuggested = 'ai_suggested';
}

class BehavioralClassification {
  static const String disciplinedSaver = 'disciplined_saver';
  static const String balancedSpender = 'balanced_spender';
  static const String impulseSpender = 'impulse_spender';
  static const String riskAverse = 'risk_averse';
  static const String highVariabilitySpender = 'high_variability_spender';
  static const String goalOrientedSpender = 'goal_oriented_spender';
}

class AiInteractionType {
  static const String chat = 'chat';
  static const String goalGuardian = 'goal_guardian';
  static const String backgroundAnalysis = 'background_analysis';
  static const String proactive = 'proactive';
  static const String systemNotification = 'system_notification';
}

class AppConstants {
  static const int chatHistoryLimit = 20;
  static const int transactionContextLimit = 10;
  static const int maxAiCategorizationAttempts = 2;
  static const String appName = 'FinWise';
  static const String appVersion = '1.0.0';
}