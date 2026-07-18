// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : healthScore.test.js
// Description   : Unit tests 5.2.4 — FHN FinHealth Score calculation
//                 (FH01–FH07). Supabase is mocked; each test seeds
//                 table data and verifies indicator scoring branches.
// First Written : 18-07-2026
// Edited on     : 18-07-2026
// ============================================

let mockTables = {};

const makeFilter = (table, rows) => ({
  eq: (col, val) => makeFilter(table, rows.filter(r => r[col] === val)),
  order: () => makeFilter(table, rows),
  limit: () => makeFilter(table, rows),
  single: () => Promise.resolve({
    data: rows[0] || null,
    error: rows[0] ? null : { message: 'Row not found' },
  }),
  then: (resolve, reject) =>
    Promise.resolve({ data: rows, error: null }).then(resolve, reject),
});

jest.mock('../config/supabase', () => ({
  from: (table) => ({
    select: () => makeFilter(table, [...(mockTables[table] || [])]),
  }),
}));

const { calculateHealthScore } = require('../services/healthScoreService');



// ── Seed helper: a neutral baseline every test overrides ──
const seed = (over = {}) => {
  mockTables = {
    vaults: over.vaults || [],
    onboarding_profiles: [{
      user_id: 'test-user',
      monthly_income: over.income ?? 3000,
      insurance_coverage: over.insurance || {},
      financial_goals: over.goals || { goals: [] },
    }],
    debts: over.debts || [],
    bills: [],
    bill_payment_history: over.billHistory || [],
    debt_balance_snapshots: over.snapshots || [],
  };
};

const spendVault = (allocated, spent) => ({
  id: 'v-spend', user_id: 'test-user', name: 'Daily Spending',
  category_key: 'daily', vault_type: 'vault', is_active: true,
  allocated_amount: allocated, spent_amount: spent, current_balance: 0,
});



// ── 5.2.4 Financial Health Score (FHN FinHealth Score Calculation) ──
describe('5.2.4 FHN FinHealth Score — calculateHealthScore()', () => {

  test('FH01: over-budget (ratio 1.05) → spendingScore = 20', async () => {
    seed({ income: 1000, vaults: [spendVault(1000, 1050)] });

    const result = await calculateHealthScore('test-user');

    /*----------------------------------------------------*/

    expect(result.dimensions.spend.indicators[0].score).toBe(20);
  });

  test('FH02: well under budget (ratio 0.42) → spendingScore = 100', async () => {
    seed({ income: 1000, vaults: [spendVault(1000, 420)] });

    const result = await calculateHealthScore('test-user');

    /*----------------------------------------------------*/

    expect(result.dimensions.spend.indicators[0].score).toBe(100);
  });

  test('FH03: emergency fund covers 3.0 months → emergencyScore = 75', async () => {
    seed({
      income: 3000,
      vaults: [{
        id: 'v-em', user_id: 'test-user', name: 'Emergency Fund',
        category_key: 'emergency_fund', vault_type: 'vault', is_active: true,
        current_balance: 9000, allocated_amount: 0, spent_amount: 0,
      }],
    });

    const result = await calculateHealthScore('test-user');

    /*----------------------------------------------------*/

    expect(result.dimensions.save.indicators[0].score).toBe(75);
  });

  test('FH04: DTI ratio 0.40 → dtiScore = 40', async () => {
    seed({
      income: 4500,
      debts: [{ id: 'd1', user_id: 'test-user', is_active: true,
                current_monthly_payment: 1800 }],
    });

    const result = await calculateHealthScore('test-user');

    /*----------------------------------------------------*/

    expect(result.dimensions.borrow.indicators[0].score).toBe(40);
  });

  test('FH05: 4 of 5 insurance types covered → insuranceScore = 80', async () => {
    seed({
      insurance: {
        medical_health: true, life_takaful: true,
        personal_accident: true, motor_vehicle: true,
        critical_illness: false,
      },
    });

    const result = await calculateHealthScore('test-user');

    /*----------------------------------------------------*/

    expect(result.dimensions.plan.indicators[0].score).toBe(80);
  });

  test('FH06: 9 of 10 bills paid on time → billsScore = 80', async () => {
    seed({
      billHistory: [
        ...Array(9).fill({ user_id: 'test-user', was_on_time: true }),
        { user_id: 'test-user', was_on_time: false },
      ],
    });

    const result = await calculateHealthScore('test-user');

    /*----------------------------------------------------*/

    expect(result.dimensions.spend.indicators[1].score).toBe(80);
  });

  test('FH07: full aggregation — dimensions 70/75/80/65 → final 73, "Financially Coping"', async () => {
    seed({
      income: 3000,
      // Spend: ratio 0.90 → 60, bills 9/10 → 80  ⇒ dimension 70
      vaults: [
        spendVault(1000, 900),
        { id: 'v-em', user_id: 'test-user', name: 'Emergency Fund',
          category_key: 'emergency_fund', vault_type: 'vault', is_active: true,
          current_balance: 9000, allocated_amount: 0, spent_amount: 0 },   // 3 months → 75
        { id: 'v-goal', user_id: 'test-user', name: 'Japan Trip',
          category_key: 'travel_fund_japan', vault_type: 'fund', is_active: true,
          linked_goal: 'Trip to Japan', goal_target_amount: 1000,
          current_balance: 650, allocated_amount: 0, spent_amount: 0 },    // 65% → 75
      ],                                                    // Save dimension ⇒ 75
      // Borrow: DTI 750/3000 = 0.25 → 60; snapshots all decreasing → 100 ⇒ 80
      debts: [{ id: 'd1', user_id: 'test-user', is_active: true,
                current_monthly_payment: 750 }],
      snapshots: Array(5).fill({
        user_id: 'test-user', direction: 'decrease',
        recorded_at: new Date().toISOString(),
      }),
      billHistory: [
        ...Array(9).fill({ user_id: 'test-user', was_on_time: true }),
        { user_id: 'test-user', was_on_time: false },
      ],
      // Plan: insurance 4/5 → 80; goals default 50 ⇒ 65
      insurance: {
        medical_health: true, life_takaful: true,
        personal_accident: true, motor_vehicle: true,
        critical_illness: false,
      },
    });

    const result = await calculateHealthScore('test-user');

    /*----------------------------------------------------*/

    expect(result.dimensions.spend.score).toBe(70);
    expect(result.dimensions.save.score).toBe(75);
    expect(result.dimensions.borrow.score).toBe(80);
    expect(result.dimensions.plan.score).toBe(65);
    expect(result.score).toBe(73);                    // Math.round(72.5) = 73
    expect(result.tier).toBe('Financially Coping');   // 40–79 band
  });
});
