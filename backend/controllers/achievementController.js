// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : achievementController.js
// Description   : Derived achievement checks — no dedicated DB table
// First Written : 17-06-2026
// Edited on     : 17-06-2026
// ============================================

const supabase = require('../config/supabase');

const ACHIEVEMENT_DEFINITIONS = [
  {
    id: 'first_goal_complete',
    title: 'Goal Getter',
    description: 'Reach the target amount in one of your saving goals',
    icon: 'trophy',
  },
  {
    id: 'no_alert_week',
    title: 'Clean Week',
    description: 'Go 7 days without a single Goal Guardian alert',
    icon: 'shield_check',
  },
  {
    id: 'debt_cleared',
    title: 'Debt Slayer',
    description: 'Pay off and remove a debt completely',
    icon: 'scissors',
  },
  {
    id: 'savings_rate_20',
    title: 'Super Saver',
    description: 'Allocate 20% or more of your income to saving goals',
    icon: 'piggy_bank',
  },
  {
    id: 'emergency_funded_3m',
    title: 'Safety Net',
    description: 'Build an emergency fund covering 3 months of income',
    icon: 'umbrella',
  },
];

const getAchievements = async (req, res) => {
  try {
    const user_id = req.user.id;

    const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();

    const [
      { data: vaults },
      { data: onboarding },
      { data: debts },
      { data: recentAlerts },
    ] = await Promise.all([
      supabase.from('vaults').select('vault_type, current_balance, goal_target_amount, allocated_amount, category_key').eq('user_id', user_id).eq('is_active', true),
      supabase.from('onboarding_profiles').select('monthly_income').eq('user_id', user_id).single(),
      supabase.from('debts').select('id, is_active').eq('user_id', user_id),
      supabase.from('ai_logs').select('id').eq('user_id', user_id).eq('interaction_type', 'goal_guardian').gte('created_at', sevenDaysAgo),
    ]);

    const monthlyIncome = parseFloat(onboarding?.monthly_income || 0);
    const results = {};

    // first_goal_complete
    const completedGoal = (vaults || []).find(
      (v) => v.vault_type === 'fund' && parseFloat(v.goal_target_amount) > 0 && parseFloat(v.current_balance) >= parseFloat(v.goal_target_amount)
    );
    results.first_goal_complete = { unlocked: !!completedGoal, unlocked_at: completedGoal ? null : null };

    // no_alert_week
    results.no_alert_week = { unlocked: (recentAlerts || []).length === 0, unlocked_at: null };

    // debt_cleared
    const clearedDebt = (debts || []).find((d) => d.is_active === false);
    results.debt_cleared = { unlocked: !!clearedDebt, unlocked_at: null };

    // savings_rate_20
    if (monthlyIncome > 0) {
      const fundAllocated = (vaults || [])
        .filter((v) => v.vault_type === 'fund')
        .reduce((sum, v) => sum + parseFloat(v.allocated_amount || 0), 0);
      results.savings_rate_20 = { unlocked: fundAllocated / monthlyIncome >= 0.2, unlocked_at: null };
    } else {
      results.savings_rate_20 = { unlocked: false, unlocked_at: null };
    }

    // emergency_funded_3m
    const emergencyVault = (vaults || []).find((v) => v.category_key && v.category_key.includes('emergency'));
    if (emergencyVault && monthlyIncome > 0) {
      results.emergency_funded_3m = {
        unlocked: parseFloat(emergencyVault.current_balance) >= monthlyIncome * 3,
        unlocked_at: null,
      };
    } else {
      results.emergency_funded_3m = { unlocked: false, unlocked_at: null };
    }

    const achievements = ACHIEVEMENT_DEFINITIONS.map((def) => ({
      ...def,
      unlocked: results[def.id]?.unlocked ?? false,
      unlocked_at: results[def.id]?.unlocked_at ?? null,
    }));

    return res.json({ success: true, data: achievements });
  } catch (error) {
    console.error('getAchievements error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

module.exports = { getAchievements };
