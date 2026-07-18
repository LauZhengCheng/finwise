// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : goalGuardian.test.js
// Description   : Unit tests 5.2.2 — Goal Guardian AI transaction
//                 interception layer (GG01–GG05). Supabase and
//                 Gemini are mocked; no network is used.
// First Written : 18-07-2026
// Edited on     : 18-07-2026
// ============================================

// ── In-memory fake database ──
let mockTables = {};  // rows served per table
let mockWrites = [];  // every INSERT/UPDATE the controller attempts

// Generic chainable query builder: supports .eq().eq()... , .single(),
// and being awaited directly (thenable) — mirrors supabase-js behaviour.
const makeFilter = (table, rows) => ({
  eq: (col, val) => makeFilter(table, rows.filter(r => r[col] === val)),
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
    update: (payload) => ({
      eq: (col, val) => {
        mockWrites.push({ table, type: 'update', where: { [col]: val }, payload });
        return Promise.resolve({ error: null });
      },
    }),
    insert: (payload) => {
      mockWrites.push({ table, type: 'insert', payload });
      return Promise.resolve({ data: [payload], error: null });
    },
  }),
}));

// ── Mock Gemini: two different prompts, two different answers ──
jest.mock('../services/geminiService', () => ({
  safeGeminiCall: jest.fn(),
  buildCategorizationPrompt: jest.fn(() => 'CATEGORIZE_PROMPT'),
  buildGoalGuardianPrompt: jest.fn(() => 'GUARDIAN_PROMPT'),
}));

jest.mock('../services/notificationService', () => ({
  checkProactiveAfterTransaction: jest.fn(() => Promise.resolve()),
}));
jest.mock('../services/profileUpdateService', () => ({
  assessProfileUpdate: jest.fn(() => Promise.resolve()),
}));

const { safeGeminiCall } = require('../services/geminiService');
const {
  initiateTransaction,
  executeTransaction,
  cancelTransaction,
} = require('../controllers/transactionController');



// ── Helpers ──
const setGeminiResponses = (guardianResult) => {
  safeGeminiCall.mockImplementation(async (prompt) =>
    prompt === 'CATEGORIZE_PROMPT'
      ? { success: true, data: { category_key: 'food_dining' } }
      : { success: true, data: guardianResult }
  );
};

const seedDatabase = () => {
  mockTables = {
    merchant_qr_codes: [{
      id: 'm-1', merchant_id: 'MCD-01', merchant_name: "McDonald's",
      qr_type: 'merchant',
    }],
    vaults: [{
      id: 'v1', user_id: 'test-user', name: 'Food & Dining',
      category_key: 'food_dining', vault_type: 'vault',
      current_balance: 500, spent_amount: 100,
      allocated_amount: 600, allocation_percentage: 40, is_active: true,
    }],
    onboarding_profiles: [{ user_id: 'test-user', monthly_income: 5000 }],
    ai_financial_profiles: [{ user_id: 'test-user', key_insights: {} }],
    debts: [],
    bills: [],
  };
};

const makeReq = (body) => ({ body, user: { id: 'test-user' } });
const makeRes = () => {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res;
};
const writesTo = (table, type) =>
  mockWrites.filter(w => w.table === table && w.type === type);

beforeEach(() => {
  seedDatabase();
  mockWrites = [];
  safeGeminiCall.mockReset();
});



// ── 5.2.2 Goal Guardian (AI Transaction Interception Layer) ──
describe('5.2.2 Goal Guardian — transaction interception', () => {

  test('GG01: alert_user=true returns outcome "alert" without deducting vault', async () => {
    setGeminiResponses({
      alert_user: true,
      alert_message: 'This purchase may impact your savings goal',
      alert_severity: 'high',
      matched_vault_category: 'food_dining',
      profile_update: { update_needed: false, updates: {} },
    });
    const res = makeRes();

    await initiateTransaction(makeReq({ merchant_id: 'MCD-01', amount: 50 }), res);

    /*----------------------------------------------------*/

    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      outcome: 'alert',
      alert_message: 'This purchase may impact your savings goal',
      alert_severity: 'high',
    }));
    expect(writesTo('vaults', 'update')).toHaveLength(0);       // money untouched
    expect(writesTo('transactions', 'insert')).toHaveLength(0); // decision deferred to user
  });

  test('GG02: alert_user=false auto-approves — vault deducted, transaction approved', async () => {
    setGeminiResponses({
      alert_user: false,
      alert_message: null,
      alert_severity: null,
      matched_vault_category: 'food_dining',
      profile_update: { update_needed: false, updates: {} },
    });
    const res = makeRes();

    await initiateTransaction(makeReq({ merchant_id: 'MCD-01', amount: 50 }), res);

    /*----------------------------------------------------*/

    const vaultUpdate = writesTo('vaults', 'update')[0];
    expect(vaultUpdate.payload.current_balance).toBe(450); // 500 − 50
    expect(vaultUpdate.payload.spent_amount).toBe(150);    // 100 + 50

    const tx = writesTo('transactions', 'insert')[0];
    expect(tx.payload.status).toBe('approved');

    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ outcome: 'approved' })
    );
  });

  test('GG03: profile_update passes whitelist — disallowed fields silently discarded', async () => {
    setGeminiResponses({
      alert_user: false,
      matched_vault_category: 'food_dining',
      profile_update: {
        update_needed: true,
        updates: {
          behavioral_classification: 'impulse_spender', // allowed
          monthly_income: 99999,                        // NOT allowed
          current_balance: 0,                           // NOT allowed
        },
      },
    });

    await initiateTransaction(makeReq({ merchant_id: 'MCD-01', amount: 50 }), makeRes());

    /*----------------------------------------------------*/

    const profileUpdate = writesTo('ai_financial_profiles', 'update')[0];
    expect(profileUpdate.payload).toEqual({
      behavioral_classification: 'impulse_spender',
    }); // ONLY the whitelisted field survived
  });

  test('GG04: user overrides alert — executeTransaction records override flags', async () => {
    const res = makeRes();

    await executeTransaction(makeReq({
      merchant_id: 'MCD-01',
      vault_id: 'v1',
      amount: 50,
      goal_guardian_result: {
        alert_message: 'This purchase may impact your savings goal',
        alert_severity: 'high',
        profile_update: { update_needed: false, updates: {} },
      },
    }), res);

    /*----------------------------------------------------*/

    const vaultUpdate = writesTo('vaults', 'update')[0];
    expect(vaultUpdate.payload.current_balance).toBe(450); // 500 − 50

    const tx = writesTo('transactions', 'insert')[0];
    expect(tx.payload.status).toBe('approved'); // transaction approved
    expect(tx.payload.user_overrode_guardian).toBe(true);
    expect(tx.payload.goal_conflict_detected).toBe(true); // goal conflict detected

    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ success: true, outcome: 'approved' })
    );
  });

  test('GG05: user cancels — transaction recorded as cancelled, vault untouched', async () => {
    const res = makeRes();

    await cancelTransaction(makeReq({
      merchant_id: 'MCD-01',
      vault_id: 'v1',
      amount: 50,
      goal_guardian_message: 'This purchase may impact your savings goal',
    }), res);

    /*----------------------------------------------------*/

    const tx = writesTo('transactions', 'insert')[0];
    expect(tx.payload.status).toBe('cancelled'); // transaction cancelled
    expect(tx.payload.user_overrode_guardian).toBe(false);
    expect(tx.payload.goal_conflict_detected).toBe(true); // goal conflict detected

    expect(writesTo('vaults', 'update')).toHaveLength(0); // no money moved, vault untouched

    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ success: true, outcome: 'cancelled' })
    );
  });
});
