// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : vault_model.dart
// Description   : Vault model — used for onboarding recommendations
//                 and live vault data from Supabase
// First Written : 24-May-2026
// Edited on     : 06-06-2026
// ============================================

class VaultModel {
  final String? id;
  final String name;
  final String categoryKey;
  final String vaultType;
  final int allocationPercentage;
  final double allocatedAmount;
  final double currentBalance;
  final double spentAmount;
  final String vaultColour;
  final String vaultIcon;
  final String? linkedGoal;
  final double? goalTargetAmount;

  VaultModel({
    this.id,
    required this.name,
    required this.categoryKey,
    required this.vaultType,
    required this.allocationPercentage,
    this.allocatedAmount = 0.0,
    this.currentBalance = 0.0,
    this.spentAmount = 0.0,
    required this.vaultColour,
    required this.vaultIcon,
    this.linkedGoal,
    this.goalTargetAmount,
  });

  // Used during onboarding — maps Gemini-returned field names
  factory VaultModel.fromJson(Map<String, dynamic> json) {
    return VaultModel(
      name: json['name'],
      categoryKey: json['category_key'],
      vaultType: json['vault_type'],
      allocationPercentage: (json['allocation_percentage'] as num).toInt(),
      vaultColour: json['vault_colour'],
      vaultIcon: json['vault_icon'],
      linkedGoal: json['linked_goal'],
      goalTargetAmount: json['goal_target_amount']?.toDouble(),
    );
  }

  // Used when reading from Supabase DB (includes balance fields and UUID id)
  factory VaultModel.fromDbJson(Map<String, dynamic> json) {
    return VaultModel(
      id: json['id'],
      name: json['name'],
      categoryKey: json['category_key'],
      vaultType: json['vault_type'],
      allocationPercentage: (json['allocation_percentage'] as num).toInt(),
      allocatedAmount: (json['allocated_amount'] as num?)?.toDouble() ?? 0.0,
      currentBalance: (json['current_balance'] as num?)?.toDouble() ?? 0.0,
      spentAmount: (json['spent_amount'] as num?)?.toDouble() ?? 0.0,
      vaultColour: json['vault_colour'],
      vaultIcon: json['vault_icon'],
      linkedGoal: json['linked_goal'],
      goalTargetAmount: (json['goal_target_amount'] as num?)?.toDouble(),
    );
  }

  // Convert VaultModel back to JSON for sending to backend
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'category_key': categoryKey,
      'vault_type': vaultType,
      'allocation_percentage': allocationPercentage,
      'vault_colour': vaultColour,
      'vault_icon': vaultIcon,
      'linked_goal': linkedGoal,
      'goal_target_amount': goalTargetAmount,
    };
  }
}
