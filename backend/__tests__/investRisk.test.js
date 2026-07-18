// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : investRisk.test.js
// Description   : Unit tests 5.2.5 — Investment risk score
//                 (PRIIPs volatility mapping + HHI concentration
//                 penalty + Morningstar tiers) (IR01–IR06).
//                 Supabase, cache, and volatility feeds are mocked.
// First Written : 18-07-2026
// Edited on     : 18-07-2026
// ============================================

let mockTables = {};
let mockWrites = [];
let mockPrices = {};  // Redis Tier-1 answers, e.g. { 'market:BTCUSD': 60000 }
let mockVols = {};    // volatility per ticker, e.g. { BTC: 72 }

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
        return { then: (res) => Promise.resolve({ error: null }).then(res),
                 catch: () => {} };
      },
    }),
  }),
}));

jest.mock('../services/cacheService', () => ({
  cacheGet: jest.fn(async (key) =>
    mockPrices[key] !== undefined ? { price: mockPrices[key] } : null),
  cacheSet: jest.fn(async () => {}),
}));

jest.mock('../services/marketDataService', () => ({
  fetchHistoricalVolatility: jest.fn(async (ticker) =>
    mockVols[ticker.toUpperCase()] ?? 15),
}));

// Safety net: Mongo tiers are never reached (Tier 1 always answers),
// but mock them so no real module can load.
jest.mock('../config/mongodb', () => ({ connectMongo: jest.fn(async () => {}) }));
jest.mock('../models/MarketDataCache', () => ({
  findOne: () => ({ lean: async () => null }),
  findOneAndUpdate: async () => null,
}));

const { getPortfolioRisk } = require('../controllers/investController');



// ── Helpers ──
const holding = (id, ticker, category, units, price) => ({
  id, user_id: 'test-user', asset_name: ticker, ticker, category,
  units, purchase_price: price, current_price: price, is_active: true,
});

const seed = (investments, statedRisk = 'moderate') => {
  mockTables = {
    investments,
    onboarding_profiles: [{ user_id: 'test-user', risk_level: statedRisk }],
  };
  // Tier-1 price for every holding (same as stored → no price-sync writes)
  mockPrices = {};
  investments.forEach(inv => {
    const symbol = inv.category === 'crypto'
      ? `${inv.ticker.toUpperCase()}USD` : inv.ticker.toUpperCase();
    mockPrices[`market:${symbol}`] = inv.current_price;
  });
};

const makeReq = () => ({ body: {}, user: { id: 'test-user' } });
const makeRes = () => {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res;
};
const resultOf = (res) => res.json.mock.calls[0][0].data;

beforeEach(() => {
  mockTables = {};
  mockWrites = [];
  mockPrices = {};
  mockVols = {};
});



// ── 5.2.5 Investment Risk Score (PRIIPs Volatility + HHI Concentration) ──
describe('5.2.5 Investment Risk Score — getPortfolioRisk()', () => {

  test('IR01: 100% Bitcoin @72% volatility → capped per-asset 95 + full HHI penalty → 100, Very Aggressive', async () => {
    seed([holding('i1', 'BTC', 'crypto', 1, 60000)]);
    mockVols = { BTC: 72 };
    const res = makeRes();

    await getPortfolioRisk(makeReq(), res);

    /*----------------------------------------------------*/

    const data = resultOf(res);
    expect(data.base_score).toBe(95);      // min(60 + (72−25), 95) capped
    expect(data.hhi_penalty).toBe(25);     // single high-risk holding: HHI = 1.0 × α25
    expect(data.risk_score).toBe(100);     // 95 + 25, capped at 100
    expect(data.risk_level).toBe('Very Aggressive');
  });

  test('IR02: 100% low-volatility ETF @1.8% → PRIIPs floor score 10, Conservative', async () => {
    seed([holding('i1', 'BIL', 'etf', 100, 91)]);
    mockVols = { BIL: 1.8 };               // T-bill ETF: volatility ≤ 2
    const res = makeRes();

    await getPortfolioRisk(makeReq(), res);

    /*----------------------------------------------------*/

    const data = resultOf(res);
    expect(data.risk_score).toBe(10);
    expect(data.hhi_penalty).toBe(0);      // risk < 50 → excluded from HHI
    expect(data.risk_level).toBe('Conservative');
  });

  test('IR03: concentrated 80/20 portfolio → HHI penalty lifts score above raw volatility base', async () => {
    seed([
      holding('i1', 'TSLA', 'stocks', 80, 10),  // value 800 → weight 0.80
      holding('i2', 'BND',  'etf',    20, 10),  // value 200 → weight 0.20
    ]);
    mockVols = { TSLA: 30, BND: 10 };  // scores: 65 (high-risk) and 40
    const res = makeRes();

    await getPortfolioRisk(makeReq(), res);

    /*----------------------------------------------------*/

    const data = resultOf(res);
    expect(data.base_score).toBe(60);      // 0.8×65 + 0.2×40
    expect(data.hhi_penalty).toBe(16);     // HHI = 0.8² = 0.64 → ×25
    expect(data.risk_score).toBe(76);      // 60 + 16 — penalty visible
    expect(data.risk_level).toBe('Aggressive');
  });

  test('IR04: 5 holdings evenly at 20% → minimal HHI penalty (diversified)', async () => {
    seed(['A', 'B', 'C', 'D', 'E'].map((t, i) =>
      holding(`i${i}`, t, 'stocks', 10, 10)));   // equal value → weight 0.20 each
    mockVols = { A: 30, B: 30, C: 30, D: 30, E: 30 };  // each scores 65
    const res = makeRes();

    await getPortfolioRisk(makeReq(), res);

    /*----------------------------------------------------*/

    const data = resultOf(res);
    expect(data.base_score).toBe(65);
    expect(data.hhi_penalty).toBe(5);      // HHI = 5 × 0.2² = 0.20 → ×25
    expect(data.risk_score).toBe(70);      // close to raw base
  });

  test('IR05: Morningstar boundary — 47 → Moderate, 48 → Aggressive', async () => {
    // Score 47: vol 15.03 → 30 + (13.03/23)×30 = 46.996 → rounds to 47
    seed([holding('i1', 'VTI', 'etf', 10, 100)]);
    mockVols = { VTI: 15.03 };
    const res47 = makeRes();
    await getPortfolioRisk(makeReq(), res47);
    /*----------------------------------------------------*/
    expect(resultOf(res47).risk_score).toBe(47);
    expect(resultOf(res47).risk_level).toBe('Moderate');


    // Score 48: vol 15.8 → 30 + (13.8/23)×30 = 48 exactly
    seed([holding('i1', 'VTI', 'etf', 10, 100)]);
    mockVols = { VTI: 15.8 };
    const res48 = makeRes();
    await getPortfolioRisk(makeReq(), res48);
    /*----------------------------------------------------*/
    expect(resultOf(res48).risk_score).toBe(48);
    expect(resultOf(res48).risk_level).toBe('Aggressive');
  });

  test('IR06: empty portfolio → graceful "No investments", no error thrown', async () => {
    seed([]);
    const res = makeRes();

    await getPortfolioRisk(makeReq(), res);

    /*----------------------------------------------------*/

    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: null,
      message: 'No investments',
    }));
    expect(res.status).not.toHaveBeenCalledWith(500);
  });
});
