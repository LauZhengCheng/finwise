// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : trafficController.test.js
// Description   : Unit tests 5.2.1 — Traffic Controller salary
//                 allocation engine (TC01–TC05). Supabase is mocked;
//                 no real database or network is used.
// First Written : 17-07-2026
// Edited on     : 17-07-2026
// ============================================

// ── In-memory state for the fake database ──
// (Jest requires mock-factory variables to start with "mock")
let mockVaults = [];   // the fake vaults the "database" will return
let mockUpdates = [];  // records every UPDATE the controller attempts
let mockInserts = [];  // records every INSERT the controller attempts

// ── The mock: replaces ../config/supabase everywhere ──
jest.mock('../config/supabase', () => ({
  from: (table) => {
    if (table === 'vaults') {
      return {
        // SELECT ... WHERE user_id = ? AND is_active = ?
        select: () => ({
          eq: (col1, val1) => ({
            eq: (col2, val2) =>
              Promise.resolve({
                data: mockVaults.filter(v => v[col1] === val1 && v[col2] === val2),
                error: null,
              }),
          }),
        }),
        // UPDATE vaults SET ... WHERE id = ?
        update: (payload) => ({
          eq: (col, id) => {
            mockUpdates.push({ id, ...payload });
            return Promise.resolve({ error: null });
          },
        }),
      };
    }
    if (table === 'income_injections') {
      return {
        insert: (payload) => {
          mockInserts.push(payload);
          return Promise.resolve({ error: null });
        },
      };
    }
    return {};
  },
}));

// Fire-and-forget notification — replaced with a no-op
jest.mock('../services/notificationService', () => ({
  checkAfterIncome: jest.fn(() => Promise.resolve()),
}));

const { injectIncome } = require('../controllers/incomeController');



// ── Test helpers ──
const makeVault = (over) => ({
  id: over.id,
  user_id: 'test-user',
  name: over.name || over.id,
  category_key: over.category_key || 'general',
  vault_type: over.vault_type || 'vault',
  allocation_percentage: over.pct,
  current_balance: over.balance ?? 0,
  spent_amount: over.spent ?? 0,
  allocated_amount: 0,
  is_active: over.is_active ?? true,
  vault_colour: '#6366F1',
  vault_icon: 'wallet',
});

const makeReq = (amount) => ({ body: { amount }, user: { id: 'test-user' } });

const makeRes = () => {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res;
};

// wipes the 3 arrays before every test, so no test inherits leftovers from another test
beforeEach(() => {
  mockVaults = [];
  mockUpdates = [];
  mockInserts = [];
});



// ── 5.2.1 Traffic Controller (Salary Allocation Engine) ──
describe('5.2.1 Traffic Controller — injectIncome()', () => {

  test('TC01: splits RM5,000 across 5 vaults by allocation percentage', async () => {
    mockVaults = [
      makeVault({ id: 'v1', pct: 40 }),
      makeVault({ id: 'v2', pct: 20 }),
      makeVault({ id: 'v3', pct: 15 }),
      makeVault({ id: 'v4', pct: 15 }),
      makeVault({ id: 'v5', pct: 10 }),
    ];
    const res = makeRes();

    await injectIncome(makeReq(5000), res);

    /*----------------------------------------------------*/

    const allocated = Object.fromEntries(
      mockUpdates.map(u => [u.id, u.allocated_amount])
    );
    expect(allocated).toEqual({ v1: 2000, v2: 1000, v3: 750, v4: 750, v5: 500 });

    const total = mockUpdates.reduce((s, u) => s + u.allocated_amount, 0);
    expect(total).toBe(5000); // rounding correction guarantees exact total

    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ success: true })
    );
  });

  test('TC02: resets spent_amount to RM0.00 on every vault', async () => {
    mockVaults = [
      makeVault({ id: 'v1', pct: 50, spent: 420 }),
      makeVault({ id: 'v2', pct: 50, spent: 133.55 }),
    ];

    await injectIncome(makeReq(5000), makeRes());

    /*----------------------------------------------------*/
    
    expect(mockUpdates).toHaveLength(2); // check if 2 updates were made
    mockUpdates.forEach(u => expect(u.spent_amount).toBe(0));
  });

  test('TC03: accumulates allocation onto existing carryover balance', async () => {
    mockVaults = [
      makeVault({ id: 'v1', pct: 40, balance: 380 }), // carryover RM380
      makeVault({ id: 'v2', pct: 60, balance: 0 }),
    ];

    await injectIncome(makeReq(5000), makeRes());

    /*----------------------------------------------------*/

    const v1 = mockUpdates.find(u => u.id === 'v1');
    expect(v1.current_balance).toBe(2380); // 380 + (40% of 5000) — carryover preserved
  });

  test('TC04: excludes inactive (archived) vault from allocation', async () => {
    mockVaults = [
      makeVault({ id: 'v1', pct: 40 }),
      makeVault({ id: 'v2', pct: 20 }),
      makeVault({ id: 'v3', pct: 15 }),
      makeVault({ id: 'v4', pct: 15 }),
      makeVault({ id: 'v5', pct: 10 }),
      makeVault({ id: 'v6', pct: 50, is_active: false }), // soft-deleted goal
    ];

    await injectIncome(makeReq(5000), makeRes());

    /*----------------------------------------------------*/

    expect(mockUpdates).toHaveLength(5); // check if 5 updates were made
    expect(mockUpdates.find(u => u.id === 'v6')).toBeUndefined();
  });

  test('TC05: fund (saving goal) vault receives its proportional share', async () => {
    mockVaults = [
      makeVault({ id: 'v1', pct: 80 }),
      makeVault({ id: 'fund1', pct: 20, vault_type: 'fund' }),
    ];

    await injectIncome(makeReq(5000), makeRes());

    /*----------------------------------------------------*/

    const fund = mockUpdates.find(u => u.id === 'fund1');
    expect(fund).toBeDefined();
    expect(fund.allocated_amount).toBe(1000); // 20% of 5000
  });
});
