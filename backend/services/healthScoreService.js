// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : healthScoreService.js
// Description   : Financial Health Score calculator — FHN FinHealth Score
//                 methodology with 8 sub-indicators across 4 dimensions
//                 (Spend, Save, Borrow, Plan). Score 0-100.
// First Written : 25-06-2026
// Edited on     : 25-06-2026
// ============================================

const supabase = require('../config/supabase');

const INSURANCE_TYPES = ['medical_health', 'life_takaful', 'personal_accident', 'motor_vehicle', 'critical_illness'];

const HEALTH_TIERS = [
  { min: 0, max: 39, label: 'Financially Vulnerable', color: '#E85D3A' },
  { min: 40, max: 79, label: 'Financially Coping', color: '#7B5EA7' },
  { min: 80, max: 100, label: 'Financially Healthy', color: '#3B82C4' },
];

async function calculateHealthScore(userId) {
  let vaults, onboarding, debts, bills, billHistory, debtSnapshots;
  try {
    ([
      { data: vaults },
      { data: onboarding },
      { data: debts },
      { data: bills },
      { data: billHistory },
      { data: debtSnapshots },
    ] = await Promise.all([
      supabase.from('vaults').select('*').eq('user_id', userId).eq('is_active', true),
      supabase.from('onboarding_profiles').select('*').eq('user_id', userId).single(),
      supabase.from('debts').select('*').eq('user_id', userId).eq('is_active', true),
      supabase.from('bills').select('*').eq('user_id', userId).eq('is_active', true),
      supabase.from('bill_payment_history').select('*').eq('user_id', userId).order('paid_at', { ascending: false }).limit(50),
      supabase.from('debt_balance_snapshots').select('*').eq('user_id', userId).order('recorded_at', { ascending: false }).limit(30),
    ]));
  } catch (err) {
    console.error('[HealthScore] Failed to fetch data:', err.message);
    throw new Error('Unable to calculate health score — please try again later');
  }

  const monthlyIncome = parseFloat(onboarding?.monthly_income || 0);
  const activeVaults = (vaults || []).filter(v => !v.completed_at && !v.is_archived);
  const spendingVaults = activeVaults.filter(v => v.vault_type === 'vault');
  const goalVaults = activeVaults.filter(v => v.vault_type === 'fund');
  const insurance = onboarding?.insurance_coverage || {};

  // ── Indicator 1: Spending < Income (0-100) ──
  let spendingScore = 50;
  if (spendingVaults.length > 0 && monthlyIncome > 0) {
    const totalSpent = spendingVaults.reduce((s, v) => s + parseFloat(v.spent_amount || 0), 0);
    const totalAllocated = spendingVaults.reduce((s, v) => s + parseFloat(v.allocated_amount || 0), 0);
    if (totalAllocated > 0) {
      const ratio = totalSpent / totalAllocated;
      if (ratio < 0.7) spendingScore = 100;
      else if (ratio < 0.85) spendingScore = 80;
      else if (ratio < 0.95) spendingScore = 60;
      else if (ratio <= 1.0) spendingScore = 40;
      else spendingScore = 20;
    }
  }

  // ── Indicator 2: Bills Paid On Time (0-100) ──
  let billsScore = 50;
  const history = billHistory || [];
  if (history.length > 0) {
    const onTimeCount = history.filter(h => h.was_on_time).length;
    const ratio = onTimeCount / history.length;
    if (ratio >= 1.0) billsScore = 100;
    else if (ratio >= 0.9) billsScore = 80;
    else if (ratio >= 0.75) billsScore = 60;
    else if (ratio >= 0.5) billsScore = 40;
    else billsScore = 20;
  }

  // ── Indicator 3: Emergency Fund Adequate (0-100) ──
  let emergencyScore = 0;
  const emergencyVault = activeVaults.find(v =>
    v.category_key?.includes('emergency') || v.name?.toLowerCase().includes('emergency')
  );
  if (emergencyVault && monthlyIncome > 0) {
    const balance = parseFloat(emergencyVault.current_balance || 0);
    const monthsCovered = balance / monthlyIncome;
    if (monthsCovered >= 6) emergencyScore = 100;
    else if (monthsCovered >= 3) emergencyScore = 75;
    else if (monthsCovered >= 1) emergencyScore = 50;
    else emergencyScore = 25;
  }

  // ── Indicator 4: Long-term Savings / Goal Vaults (0-100) ──
  let savingsScore = 50;
  if (goalVaults.length > 0) {
    const progressArr = goalVaults.map(v => {
      const target = parseFloat(v.goal_target_amount || 1);
      const current = parseFloat(v.current_balance || 0);
      return Math.min(current / target, 1);
    });
    const avgProgress = progressArr.reduce((s, p) => s + p, 0) / progressArr.length;
    if (avgProgress >= 0.8) savingsScore = 100;
    else if (avgProgress >= 0.6) savingsScore = 75;
    else if (avgProgress >= 0.4) savingsScore = 50;
    else if (avgProgress >= 0.2) savingsScore = 25;
    else savingsScore = 10;
  }

  // ── Indicator 5: Manageable Debt / DTI (0-100) ──
  let dtiScore = 100;
  const activeDebts = debts || [];
  if (activeDebts.length > 0 && monthlyIncome > 0) {
    const totalMonthlyPayments = activeDebts.reduce((s, d) =>
      s + parseFloat(d.current_monthly_payment || d.minimum_payment || 0), 0);
    const dtiRatio = totalMonthlyPayments / monthlyIncome;
    if (dtiRatio < 0.15) dtiScore = 100;
    else if (dtiRatio < 0.20) dtiScore = 80;
    else if (dtiRatio < 0.36) dtiScore = 60;
    else if (dtiRatio < 0.43) dtiScore = 40;
    else dtiScore = 20;
  }

  // ── Indicator 6: Debt Trending Down (0-100) ──
  let debtTrendScore = 50;
  const snapshots = debtSnapshots || [];
  if (snapshots.length >= 2) {
    const decreases = snapshots.filter(s => s.direction === 'decrease').length;
    const increases = snapshots.filter(s => s.direction === 'increase').length;
    const total = snapshots.length;
    const decreaseRatio = decreases / total;
    if (decreaseRatio >= 0.8) debtTrendScore = 100;
    else if (decreaseRatio >= 0.6) debtTrendScore = 75;
    else if (decreases >= increases) debtTrendScore = 50;
    else debtTrendScore = 25;

    // Stagnation penalty: if last update was > 60 days ago, reduce score
    const lastSnapshot = snapshots[0];
    if (lastSnapshot?.recorded_at) {
      const daysSinceUpdate = (Date.now() - new Date(lastSnapshot.recorded_at).getTime()) / 86400000;
      if (daysSinceUpdate > 90) debtTrendScore = Math.max(debtTrendScore - 30, 10);
      else if (daysSinceUpdate > 60) debtTrendScore = Math.max(debtTrendScore - 15, 15);
    }
  } else if (activeDebts.length === 0) {
    debtTrendScore = 100;
  } else if (activeDebts.length > 0 && snapshots.length === 0) {
    // Has debts but never updated — concerning
    debtTrendScore = 30;
  }

  // ── Indicator 7: Insurance Coverage (0-100) ──
  const coveredCount = INSURANCE_TYPES.filter(t => insurance[t] === true).length;
  const insuranceScore = Math.round((coveredCount / INSURANCE_TYPES.length) * 100);

  // ── Indicator 8: Goals On Track (0-100) ──
  let goalsOnTrackScore = 50;
  if (goalVaults.length > 0 && onboarding?.financial_goals?.goals?.length > 0) {
    const goals = onboarding.financial_goals.goals;
    let onTrack = 0;
    for (const gv of goalVaults) {
      const matchingGoal = goals.find(g =>
        gv.linked_goal?.toLowerCase().includes(g.goal?.toLowerCase()) ||
        g.goal?.toLowerCase().includes(gv.linked_goal?.toLowerCase())
      );
      if (!matchingGoal?.timeline) { onTrack++; continue; }

      const target = parseFloat(gv.goal_target_amount || 0);
      const current = parseFloat(gv.current_balance || 0);
      if (target <= 0) continue;
      const progress = current / target;

      const addedDate = matchingGoal.added_date ? new Date(matchingGoal.added_date) : new Date();
      const timelineMonths = _parseTimeline(matchingGoal.timeline);
      const elapsedMonths = Math.max(1, (Date.now() - addedDate.getTime()) / (30 * 86400000));
      const expectedProgress = Math.min(elapsedMonths / timelineMonths, 1);

      if (progress >= expectedProgress * 0.8) onTrack++;
    }
    const ratio = onTrack / goalVaults.length;
    if (ratio >= 0.8) goalsOnTrackScore = 100;
    else if (ratio >= 0.6) goalsOnTrackScore = 75;
    else if (ratio >= 0.4) goalsOnTrackScore = 50;
    else goalsOnTrackScore = 25;
  }

  // ── Weighted Final Score ──
  // FHN: 4 dimensions equally weighted (25% each), 2 indicators per dimension
  const spendDimension = (spendingScore + billsScore) / 2;
  const saveDimension = (emergencyScore + savingsScore) / 2;
  const borrowDimension = (dtiScore + debtTrendScore) / 2;
  const planDimension = (insuranceScore + goalsOnTrackScore) / 2;

  const finalScore = Math.round(
    spendDimension * 0.25 +
    saveDimension * 0.25 +
    borrowDimension * 0.25 +
    planDimension * 0.25
  );

  const tier = HEALTH_TIERS.find(t => finalScore >= t.min && finalScore <= t.max) || HEALTH_TIERS[0];

  return {
    score: finalScore,
    tier: tier.label,
    tier_color: tier.color,
    dimensions: {
      spend: { score: Math.round(spendDimension), indicators: [
        { name: 'Spending within budget', score: spendingScore },
        { name: 'Bills paid on time', score: billsScore },
      ]},
      save: { score: Math.round(saveDimension), indicators: [
        { name: 'Emergency fund', score: emergencyScore },
        { name: 'Long-term savings', score: savingsScore },
      ]},
      borrow: { score: Math.round(borrowDimension), indicators: [
        { name: 'Debt-to-income ratio', score: dtiScore },
        { name: 'Debt trending down', score: debtTrendScore },
      ]},
      plan: { score: Math.round(planDimension), indicators: [
        { name: 'Insurance coverage', score: insuranceScore },
        { name: 'Goals on track', score: goalsOnTrackScore },
      ]},
    },
    insurance_coverage: insurance,
    insurance_types: INSURANCE_TYPES,
  };
}

function _parseTimeline(timeline) {
  if (!timeline) return 12;
  const lower = timeline.toLowerCase();
  const num = parseFloat(lower) || 1;
  if (lower.includes('year')) return num * 12;
  if (lower.includes('month')) return num;
  return 12;
}

module.exports = { calculateHealthScore, INSURANCE_TYPES, HEALTH_TIERS };
