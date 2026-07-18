// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : spendingForecast.test.js
// Description   : Unit tests 5.2.7 — Spending Forecast velocity &
//                 runway analysis (SF01–SF04). Supabase and the
//                 calendar (dateUtils) are mocked for determinism.
// First Written : 18-07-2026
// Edited on     : 18-07-2026
// ============================================

let mockTables = {};

const makeFilter = (table, rows) => ({
  eq: (col, val) => makeFilter(table, rows.filter(r => r[col] === val)),
  is: (col, val) => makeFilter(table, rows.filter(r => r[col] === val)),
  gte: (col, val) => makeFilter(table, rows.filter(r => r[col] >= val)),
  lt: (col, val) => makeFilter(table, rows.filter(r => r[col] < val)),
  single: () => Promise.resolve({ data: rows[0] || null, error: null }),
  then: (resolve, reject) =>
    Promise.resolve({ data: rows, error: null }).then(resolve, reject),
});

jest.mock('../config/supabase', () => ({
  from: (table) => ({
    select: () => makeFilter(table, [...(mockTables[table] || [])]),
  }),
}));

// Freeze the calendar: day 13 of 31, 18 days left in the month
jest.mock('../utils/dateUtils', () => ({
  getMonthContext: () => ({ day: 13, total: 31, left: 18, pct: 42 }),
  formatDateMYT: () => '1 Aug',
}));

const { getSpendingForecast } = require('../controllers/financeController');



// ── Helpers ──
const isoDaysAgo = (d) => new Date(Date.now() - d * 86400000).toISOString();

const seed = ({ balance = 500, allocated = 1000, spent = 0, txs = [] }) => {
  mockTables = {
    vaults: [{
      id: 'v1', user_id: 'test-user', name: 'Food & Dining',
      vault_type: 'vault', is_active: true, completed_at: null,
      current_balance: balance, allocated_amount: allocated, spent_amount: spent,
    }],
    transactions: txs.map((t, i) => ({
      id: `t${i}`, user_id: 'test-user', vault_id: 'v1',
      status: 'approved', transaction_type: 'expense',
      amount: t.amount, created_at: isoDaysAgo(t.daysAgo),
    })),
  };
};

const makeReq = () => ({ body: {}, user: { id: 'test-user' } });
const makeRes = () => {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res;
};
const forecastOf = (res) => res.json.mock.calls[0][0].data.forecasts[0];

beforeEach(() => { mockTables = {}; });



// ── 5.2.7 Spending Forecast (Velocity & Runway Analysis) ──
describe('5.2.7 Spending Forecast — getSpendingForecast()', () => {

  test('SF01: RM900 regular spend over 30 days → avg_30d = RM30.00/day', async () => {
    // 30 transactions of RM30, one per day — no bursts (all ≤ 3× median)
    seed({ txs: Array.from({ length: 30 }, (_, i) => ({ amount: 30, daysAgo: i })) });
    const res = makeRes();

    await getSpendingForecast(makeReq(), res);

    /*----------------------------------------------------*/

    expect(forecastOf(res).avg_30d).toBe(30);   // 900 / fixed 30-day divisor
  });

  test('SF02: balance RM300 at RM25/day velocity → runway = 12 days', async () => {
    // Constant RM25 daily spend → EWMA converges to exactly 25
    seed({
      balance: 300,
      txs: Array.from({ length: 30 }, (_, i) => ({ amount: 25, daysAgo: i })),
    });
    const res = makeRes();

    await getSpendingForecast(makeReq(), res);

    /*----------------------------------------------------*/

    const f = forecastOf(res);
    expect(f.weighted_avg_daily).toBe(25);
    expect(f.days_remaining).toBe(12);          // floor(300 / 25)
  });

  test('SF03: RM450 outlier vs RM90 median → flagged as burst, excluded from velocity', async () => {
    // 9 regular RM90 transactions + one RM450 spike
    // sorted median = 90 → threshold = 270 → 450 exceeds it
    seed({
      txs: [
        ...Array.from({ length: 9 }, (_, i) => ({ amount: 90, daysAgo: i + 1 })),
        { amount: 450, daysAgo: 5 },
      ],
    });
    const res = makeRes();

    await getSpendingForecast(makeReq(), res);

    /*----------------------------------------------------*/

    const f = forecastOf(res);
    expect(f.burst_count).toBe(1);
    expect(f.burst_total).toBe(450);
    expect(f.avg_30d).toBe(27);                 // (810 regular only) / 30 — burst excluded
  });

  test('SF04: balance RM900 with 18 days left → target daily spend = RM50.00', async () => {
    seed({ balance: 900, txs: [] });
    const res = makeRes();

    await getSpendingForecast(makeReq(), res);

    /*----------------------------------------------------*/

    expect(forecastOf(res).target_daily).toBe(50);  // 900 / 18 (mocked daysLeft)
  });
});
