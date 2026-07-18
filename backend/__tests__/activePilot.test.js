// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : activePilot.test.js
// Description   : Unit tests 5.2.3 — Active Pilot vault reallocation
//                 on insufficient balance (AP01–AP04). Supabase and
//                 Gemini are mocked; no network is used.
// First Written : 18-07-2026
// Edited on     : 18-07-2026
// ============================================

let mockTables = {};
let mockWrites = [];

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
    // Upgraded: supports plain `await insert(...)` AND `.insert(...).select('id').single()`
    insert: (payload) => {
      mockWrites.push({ table, type: 'insert', payload });
      return {
        select: () => ({
          single: () => Promise.resolve({ data: { id: 'tx-mock-1' }, error: null }),
        }),
        then: (resolve, reject) =>
          Promise.resolve({ data: [payload], error: null }).then(resolve, reject),
      };
    },
  }),
}));

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
const { initiateTransaction } = require('../controllers/transactionController');
const { transferVault } = require('../controllers/vaultController');



const setGeminiResponses = () => {
  safeGeminiCall.mockImplementation(async (prompt) =>
    prompt === 'CATEGORIZE_PROMPT'
      ? { success: true, data: { category_key: 'food_dining' } }
      : { success: true, data: {
          alert_user: false, alert_message: null, alert_severity: null,
          matched_vault_category: 'food_dining',
          profile_update: { update_needed: false, updates: {} },
        } }
  );
};

const seedDatabase = (foodBalance) => {
  mockTables = {
    merchant_qr_codes: [{
      id: 'm-1', merchant_id: 'MCD-01', merchant_name: "McDonald's",
      qr_type: 'merchant',
    }],
    vaults: [
      {
        id: 'v-food', user_id: 'test-user', name: 'Food & Dining',
        category_key: 'food_dining', vault_type: 'vault',
        current_balance: foodBalance, spent_amount: 0,
        allocated_amount: 600, allocation_percentage: 40, is_active: true,
      },
      {
        id: 'v-shop', user_id: 'test-user', name: 'Shopping',
        category_key: 'shopping', vault_type: 'vault',
        current_balance: 500, spent_amount: 0,
        allocated_amount: 500, allocation_percentage: 30, is_active: true,
      },
    ],
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
  mockWrites = [];
  safeGeminiCall.mockReset();
  setGeminiResponses();
});



// ── 5.2.3 Active Pilot (Vault Reallocation on Insufficient Balance) ──
describe('5.2.3 Active Pilot — insufficient balance flow', () => {

  test('AP01: insufficient balance returns "blocked" with shortfall and vault list', async () => {
    seedDatabase(200); // Food has RM200, purchase is RM350
    const res = makeRes();

    await initiateTransaction(makeReq({ merchant_id: 'MCD-01', amount: 350 }), res);

    /*----------------------------------------------------*/

    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      outcome: 'blocked', // transaction blocked
      shortfall: 150,
      matched_vault: expect.objectContaining({ current_balance: 200 }), // food vault has RM200
      all_vaults: expect.any(Array),
    }));

    const tx = writesTo('transactions', 'insert')[0];
    expect(tx.payload.status).toBe('blocked');

    expect(writesTo('vaults', 'update')).toHaveLength(0); // nothing deducted
  });

  test('AP02: transferVault moves RM150 — both balances updated, active_pilot record written', async () => {
    seedDatabase(200);
    mockTables.vaults[1].current_balance = 500; // Shopping = source
    const res = makeRes();

    await transferVault(makeReq({
      from_vault_id: 'v-shop', to_vault_id: 'v-food', amount: 150,
    }), res);

    /*----------------------------------------------------*/

    const updates = writesTo('vaults', 'update');
    const fromUpdate = updates.find(u => u.where.id === 'v-shop');
    const toUpdate = updates.find(u => u.where.id === 'v-food');
    expect(fromUpdate.payload.current_balance).toBe(350); // 500 − 150
    expect(toUpdate.payload.current_balance).toBe(350);   // 200 + 150

    const transfer = writesTo('vault_transfers', 'insert')[0];
    expect(transfer.payload.transfer_type).toBe('active_pilot'); // active_pilot transfer type

    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      from_vault: expect.objectContaining({ new_balance: 350 }),
      to_vault: expect.objectContaining({ new_balance: 350 }),
    }));
  });

  test('AP03: source vault insufficient — HTTP 400, no balances changed', async () => {
    seedDatabase(200);
    mockTables.vaults[1].current_balance = 80; // Shopping only has RM80
    const res = makeRes();

    await transferVault(makeReq({
      from_vault_id: 'v-shop', to_vault_id: 'v-food', amount: 150,
    }), res);

    /*----------------------------------------------------*/

    expect(res.status).toHaveBeenCalledWith(400); // HTTP 400
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: false,
      message: 'Shopping only has RM 80.00', 
    }));

    expect(writesTo('vaults', 'update')).toHaveLength(0); // no balances changed
    expect(writesTo('vault_transfers', 'insert')).toHaveLength(0); // no transfer made
  });

  test('AP04: retry after reallocation — balance now sufficient, proceeds past blocked path', async () => {
    seedDatabase(350); // Food now RM350 after the Active Pilot transfer
    const res = makeRes();

    await initiateTransaction(makeReq({ merchant_id: 'MCD-01', amount: 350 }), res);

    /*----------------------------------------------------*/
    
    expect(res.json).not.toHaveBeenCalledWith(
      expect.objectContaining({ outcome: 'blocked' })
    );
    expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ outcome: 'approved' })
    );

    const vaultUpdate = writesTo('vaults', 'update')[0];
    expect(vaultUpdate.payload.current_balance).toBe(0); // 350 − 350: spent to the cent
  });
});
