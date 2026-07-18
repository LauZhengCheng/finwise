// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : onboardingValidation.test.js
// Description   : Unit tests 5.2.9 — AI onboarding vault plan
//                 validation (OB01–OB06). Verifies the validation
//                 gate rejects invalid Gemini vault plans BEFORE
//                 any database write. Supabase and AI mocked.
// First Written : 18-07-2026
// Edited on     : 18-07-2026
// ============================================

let mockWrites = [];

jest.mock('../config/supabase', () => ({
  from: (table) => ({
    upsert: (payload) => {
      mockWrites.push({ table, type: 'upsert', payload });
      return Promise.resolve({ error: null });
    },
    insert: (payload) => {
      mockWrites.push({ table, type: 'insert', payload });
      return {
        select: () => Promise.resolve({ data: Array.isArray(payload) ? payload : [payload], error: null }),
        then: (resolve, reject) =>
          Promise.resolve({ data: [payload], error: null }).then(resolve, reject),
      };
    },
  }),
}));

// aiController pulls in the whole AI stack at import — neutralise it
jest.mock('../services/langGraphService', () => ({ runAionAgent: jest.fn() }));
jest.mock('../services/geminiService', () => ({
  safeGeminiCall: jest.fn(),
  buildOnboardingPrompt: jest.fn(),
  buildReviewerPrompt: jest.fn(),
  buildChatPrompt: jest.fn(),
  buildSummarizationPrompt: jest.fn(),
}));
jest.mock('../services/embeddingService', () => ({ embedText: jest.fn() }));

jest.mock('../services/notificationService', () => ({
    checkGoalCompletion: jest.fn(() => Promise.resolve()),
  }));  

const { confirmVaults } = require('../controllers/aiController');



// ── Helpers ──
const vault = (name, key, pct, extra = {}) => ({
  name, category_key: key, allocation_percentage: pct,
  vault_type: 'vault', vault_colour: '#6366F1', vault_icon: 'wallet',
  ...extra,
});

const validProfile = () => ({
  monthly_income: 5000,
  financial_goals: { goals: [] },
  spending_habit: 'balanced spender',
  risk_level: 'moderate',
  life_situation: 'single working adult',
});

const fiveVaults = (lastPct = 5) => [
  vault('Food & Dining', 'food_dining', 35),
  vault('Transport', 'transport', 25),
  vault('Shopping', 'shopping', 20),
  vault('Emergency Fund', 'emergency_fund', 15),
  vault('Savings', 'savings', lastPct),
];

const makeReq = (profile_data, vault_recommendations) => ({
  body: { profile_data, vault_recommendations },
  user: { id: 'test-user' },
});
const makeRes = () => {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res;
};

beforeEach(() => { mockWrites = []; });



// ── 5.2.9 AI Onboarding Vault Plan Validation ──
describe('5.2.9 Onboarding validation — confirmVaults()/saveOnboardingData()', () => {

  test('OB01: valid plan (sum = 100%) → all rows saved', async () => {
    const res = makeRes();

    await confirmVaults(makeReq(validProfile(), fiveVaults(5)), res);

    /*----------------------------------------------------*/

    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ success: true })
    );
    const tables = mockWrites.map(w => w.table);
    expect(tables).toContain('onboarding_profiles');
    expect(tables).toContain('ai_financial_profiles');
    expect(tables).toContain('vaults');
    expect(tables).toContain('allocation_history');

    const vaultInsert = mockWrites.find(w => w.table === 'vaults');
    expect(vaultInsert.payload).toHaveLength(5);
  });

  test('OB02: allocations sum to 99% (below 99.5 tolerance) → rejected, nothing saved', async () => {
    const res = makeRes();

    await confirmVaults(makeReq(validProfile(), fiveVaults(4)), res); // 35+25+20+15+4 = 99

    /*----------------------------------------------------*/

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: false,
      message: 'Allocation percentages sum to 99, not 100',
    }));
    expect(mockWrites).toHaveLength(0); // rejected BEFORE any DB write
  });

  test('OB03: valid category_key "food_dining" passes the regex → saved', async () => {
    const res = makeRes();

    await confirmVaults(makeReq(validProfile(), fiveVaults(5)), res);

    /*----------------------------------------------------*/

    const vaultInsert = mockWrites.find(w => w.table === 'vaults');
    expect(vaultInsert.payload[0].category_key).toBe('food_dining');
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ success: true })
    );
  });

  test('OB04: category_key "Food & Dining" fails the regex → rejected, nothing saved', async () => {
    const bad = fiveVaults(5);
    bad[0].category_key = 'Food & Dining'; // spaces + capitals + symbol
    const res = makeRes();

    await confirmVaults(makeReq(validProfile(), bad), res);

    /*----------------------------------------------------*/

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      message: 'Invalid category_key format: Food & Dining',
    }));
    expect(mockWrites).toHaveLength(0);
  });

  test('OB05: fund vault missing linked_goal/goal_target_amount → rejected', async () => {
    const plan = [
      vault('Daily Spending', 'daily_spending', 80),
      vault('Japan Trip', 'travel_fund_japan', 20, { vault_type: 'fund' }),
      // fund but NO linked_goal / goal_target_amount
    ];
    const res = makeRes();

    await confirmVaults(makeReq(validProfile(), plan), res);

    /*----------------------------------------------------*/

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      message: 'Fund vault Japan Trip missing linked_goal or goal_target_amount',
    }));
    expect(mockWrites).toHaveLength(0);
  });

  test('OB06: monthly_income missing/zero → rejected before everything else', async () => {
    const profile = validProfile();
    profile.monthly_income = 0;
    const res = makeRes();

    await confirmVaults(makeReq(profile, fiveVaults(5)), res);

    /*----------------------------------------------------*/

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      message: 'Monthly budget is missing. Aion must ask for it before saving.',
    }));
    expect(mockWrites).toHaveLength(0);
  });
});
