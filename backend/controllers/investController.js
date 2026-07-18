// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : investController.js
// Description   : Investment portfolio CRUD + risk score calculation.
//                 Risk methodology: volatility-based scoring (PRIIPs mapping)
//                 + HHI concentration penalty (MPT).
//                 Risk thresholds: Morningstar Signature Research Portfolio.
// First Written : 24-06-2026
// Edited on     : 24-06-2026
// ============================================

const supabase = require('../config/supabase');
const { fetchHistoricalVolatility } = require('../services/marketDataService');
const { cacheGet } = require('../services/cacheService');

async function _getUsdToMyr() {
  const cached = await cacheGet('market:MYRUSD');
  if (cached?.price) return 1 / cached.price;
  try {
    const { connectMongo } = require('../config/mongodb');
    const MarketDataCache = require('../models/MarketDataCache');
    await connectMongo();
    const doc = await MarketDataCache.findOne({ symbol: 'MYRUSD' }).lean();
    if (doc?.price) return 1 / doc.price;
  } catch (_) {}
  return null;
}

const VALID_CATEGORIES = ['stocks', 'crypto', 'etf'];

const RISK_LEVELS = [
  { min: 0, max: 23, label: 'Conservative' },
  { min: 24, max: 47, label: 'Moderate' },
  { min: 48, max: 78, label: 'Aggressive' },
  { min: 79, max: 100, label: 'Very Aggressive' },
];

const getInvestments = async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('investments')
      .select('*')
      .eq('user_id', req.user.id)
      .eq('is_active', true)
      .order('created_at', { ascending: false });

    if (error) throw error;
    return res.json({ success: true, data: data || [] });
  } catch (error) {
    console.error('getInvestments error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

const createInvestment = async (req, res) => {
  try {
    const { asset_name, ticker, category, units, purchase_price, current_price, purchase_date, notes } = req.body;

    if (!asset_name || !category || units == null || purchase_price == null) {
      return res.status(400).json({ success: false, message: 'asset_name, category, units, and purchase_price are required' });
    }
    if (!VALID_CATEGORIES.includes(category)) {
      return res.status(400).json({ success: false, message: `category must be one of: ${VALID_CATEGORIES.join(', ')}` });
    }

    const { data, error } = await supabase
      .from('investments')
      .insert({
        user_id: req.user.id,
        asset_name, ticker: ticker || null, category, units,
        purchase_price, current_price: current_price || purchase_price,
        purchase_date: purchase_date || null, notes: notes || null,
      })
      .select().single();

    if (error) throw error;
    return res.status(201).json({ success: true, data });
  } catch (error) {
    console.error('createInvestment error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

const updateInvestment = async (req, res) => {
  try {
    const { id } = req.params;
    const allowed = ['asset_name', 'ticker', 'category', 'units', 'purchase_price', 'current_price', 'purchase_date', 'notes', 'is_active'];
    const updates = {};
    for (const key of allowed) {
      if (req.body[key] !== undefined) updates[key] = req.body[key];
    }

    const { data, error } = await supabase
      .from('investments')
      .update(updates)
      .eq('id', id)
      .eq('user_id', req.user.id)
      .select().single();

    if (error) throw error;
    return res.json({ success: true, data });
  } catch (error) {
    console.error('updateInvestment error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

const deleteInvestment = async (req, res) => {
  try {
    const { id } = req.params;
    await supabase.from('investments').update({ is_active: false })
      .eq('id', id).eq('user_id', req.user.id);
    return res.json({ success: true });
  } catch (error) {
    console.error('deleteInvestment error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

// Save all holdings at once (edit mode save button)
const saveAllInvestments = async (req, res) => {
  try {
    const { holdings } = req.body;
    const user_id = req.user.id;

    if (!Array.isArray(holdings)) {
      return res.status(400).json({ success: false, message: 'holdings array required' });
    }

    // Deactivate all existing
    await supabase.from('investments').update({ is_active: false }).eq('user_id', user_id);

    // Insert/reactivate all
    const toInsert = holdings.filter(h => h.asset_name && h.category && h.units != null).map(h => ({
      user_id,
      asset_name: h.asset_name,
      ticker: h.ticker || null,
      category: h.category,
      units: h.units,
      purchase_price: h.purchase_price || 0,
      current_price: h.current_price || h.purchase_price || 0,
      purchase_date: h.purchase_date || null,
      notes: h.notes || null,
      is_active: true,
    }));

    if (toInsert.length > 0) {
      const { error } = await supabase.from('investments').insert(toInsert);
      if (error) throw error;
    }

    // Calculate fresh risk + analysis and return in response
    let riskData = null;
    let analysisText = '';
    try {
      const fakeReq = { user: { id: user_id } };
      const riskResult = {};
      await getPortfolioRisk(fakeReq, { json: (d) => Object.assign(riskResult, d) });
      riskData = riskResult.data || null;
      analysisText = await _buildAnalysis(user_id, riskData);

      // Proactive notification only when risk mismatches stated risk
      if (riskData?.mismatch) {
        const { checkProactiveAfterInvestmentChange } = require('../services/notificationService');
        checkProactiveAfterInvestmentChange(user_id).catch(() => {});
      }
    } catch (e) {
      console.error('Post-save risk/analysis error:', e.message);
    }

    const { assessProfileUpdate } = require('../services/profileUpdateService');
    assessProfileUpdate(user_id, 'investment_changed', {
      holdings_count: toInsert.length,
      risk_score: riskData?.risk_score,
      risk_level: riskData?.risk_level,
      mismatch: riskData?.mismatch,
    }).catch(() => {});

    return res.json({ success: true, message: `${toInsert.length} holdings saved`, risk: riskData, analysis: analysisText });
  } catch (error) {
    console.error('saveAllInvestments error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

// Portfolio risk score calculation
const getPortfolioRisk = async (req, res) => {
  try {
    const user_id = req.user.id;

    const [{ data: investments }, { data: onboarding }] = await Promise.all([
      supabase.from('investments').select('*').eq('user_id', user_id).eq('is_active', true),
      supabase.from('onboarding_profiles').select('risk_level').eq('user_id', user_id).single(),
    ]);

    if (!investments?.length) {
      return res.json({ success: true, data: null, message: 'No investments' });
    }

    // Fetch live prices using 4-tier: Redis → MongoDB fresh → API → MongoDB stale
    const { connectMongo } = require('../config/mongodb');
    const MarketDataCache = require('../models/MarketDataCache');
    const axios = require('axios');
    const { cacheSet } = require('../services/cacheService');
    const STOCK_TTL = 24 * 60 * 60;
    const CRYPTO_TTL_PRICE = 60;

    async function _getLivePrice(ticker, category, storedPrice) {
      if (!ticker) return storedPrice;
      const upperTicker = ticker.toUpperCase();
      const symbol = category === 'crypto' ? `${upperTicker}USD` : upperTicker;
      const ttl = category === 'crypto' ? CRYPTO_TTL_PRICE : STOCK_TTL;

      // Tier 1: Redis
      const cached = await cacheGet(`market:${symbol}`);
      if (cached?.price) return cached.price;

      // Tier 2: MongoDB fresh (within TTL)
      try {
        await connectMongo();
        const doc = await MarketDataCache.findOne({ symbol }).lean();
        if (doc?.price && doc.updated_at &&
            (Date.now() - new Date(doc.updated_at).getTime()) < ttl * 1000) {
          return doc.price;
        }
      } catch (_) {}

      // Tier 3: API call → write to both
      try {
        if (category === 'crypto') {
          const cryptoList = await cacheGet('crypto:market_list');
          const match = (cryptoList || []).find(c => c.ticker === upperTicker);
          if (match?.price) return match.price;
        } else {
          const url = `https://www.alphavantage.co/query?function=GLOBAL_QUOTE&symbol=${ticker}&apikey=${process.env.ALPHA_VANTAGE_API_KEY}`;
          const { data } = await axios.get(url, { timeout: 10000 });
          const quote = data['Global Quote'];
          if (quote?.['05. price']) {
            const price = parseFloat(quote['05. price']);
            await cacheSet(`market:${symbol}`, { price, change_pct_24h: parseFloat(quote['10. change percent']?.replace('%', '') || 0) }, STOCK_TTL);
            connectMongo().then(() =>
              MarketDataCache.findOneAndUpdate({ symbol }, { symbol, type: 'stock', price, updated_at: new Date() }, { upsert: true })
            ).catch(() => {});
            return price;
          }
        }
      } catch (_) {}

      // Tier 4: MongoDB stale (any data)
      try {
        await connectMongo();
        const staleDoc = await MarketDataCache.findOne({ symbol }).lean();
        if (staleDoc?.price) return staleDoc.price;
      } catch (_) {}

      return storedPrice;
    }

    // Step 1: Asset weights — using LIVE prices from 4-tier cache
    const livePrices = await Promise.all(investments.map(inv =>
      _getLivePrice(inv.ticker, inv.category, parseFloat(inv.current_price || inv.purchase_price))
    ));

    // Sync live prices back to Supabase so all consumers (LangGraph, notifications, frontend) have latest
    for (let i = 0; i < investments.length; i++) {
      const storedPrice = parseFloat(investments[i].current_price || 0);
      if (livePrices[i] !== storedPrice && livePrices[i] > 0) {
        supabase.from('investments').update({ current_price: livePrices[i] })
          .eq('id', investments[i].id).then(() => {}).catch(() => {});
      }
    }

    const totalValue = investments.reduce((s, inv, i) => {
      return s + parseFloat(inv.units) * livePrices[i];
    }, 0);

    const holdings = investments.map((inv, i) => {
      const livePrice = livePrices[i];
      const value = parseFloat(inv.units) * livePrice;
      const purchaseValue = parseFloat(inv.units) * parseFloat(inv.purchase_price);
      return {
        name: inv.asset_name,
        ticker: inv.ticker,
        category: inv.category,
        value: Math.round(value * 100) / 100,
        weight: totalValue > 0 ? value / totalValue : 0,
        units: parseFloat(inv.units),
        purchase_price: parseFloat(inv.purchase_price),
        current_price: livePrice,
        pnl: Math.round((value - purchaseValue) * 100) / 100,
        pnl_pct: purchaseValue > 0 ? Math.round((value - purchaseValue) / purchaseValue * 10000) / 100 : 0,
      };
    });

    // Step 2: Volatility-based risk score per asset (real historical data)
    await Promise.all(holdings.map(async h => {
      const volatility = await fetchHistoricalVolatility(h.ticker, h.category);
      let riskScore;
      if (volatility <= 2) {
        riskScore = 10;
      } else if (volatility <= 25) {
        riskScore = 30 + ((volatility - 2) / (25 - 2)) * 30;
      } else {
        riskScore = Math.min(60 + (volatility - 25) * 1.0, 95);
      }
      h.risk_score = Math.round(riskScore);
      h.volatility = volatility;
    }));

    // Step 3: Weighted base risk score
    const sBase = holdings.reduce((s, h) => s + h.weight * h.risk_score, 0);

    // Step 4: HHI concentration penalty (only high-risk assets Ri >= 50)
    const highRisk = holdings.filter(h => h.risk_score >= 50);
    const hhi = highRisk.reduce((s, h) => s + h.weight * h.weight, 0);
    const alpha = 25;
    const penalty = Math.round(alpha * hhi * 100) / 100;

    // Final score
    const sPort = Math.min(Math.round(sBase + penalty), 100);
    const riskLevel = RISK_LEVELS.find(r => sPort >= r.min && sPort <= r.max)?.label || 'Unknown';
    const statedRisk = onboarding?.risk_level || 'not specified';

    // Allocation breakdown
    const allocation = {};
    holdings.forEach(h => {
      allocation[h.category] = (allocation[h.category] || 0) + Math.round(h.weight * 100);
    });

    // Total P&L
    const totalPnl = holdings.reduce((s, h) => s + h.pnl, 0);
    const totalPurchase = holdings.reduce((s, h) => s + h.units * h.purchase_price, 0);
    const totalPnlPct = totalPurchase > 0 ? Math.round(totalPnl / totalPurchase * 10000) / 100 : 0;

    return res.json({
      success: true,
      data: {
        total_value: Math.round(totalValue * 100) / 100,
        total_pnl: Math.round(totalPnl * 100) / 100,
        total_pnl_pct: totalPnlPct,
        risk_score: sPort,
        risk_level: riskLevel,
        stated_risk: statedRisk,
        mismatch: _checkMismatch(sPort, statedRisk),
        base_score: Math.round(sBase),
        hhi_penalty: penalty,
        allocation,
        holdings,
      },
    });
  } catch (error) {
    console.error('getPortfolioRisk error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

function _checkMismatch(score, stated) {
  const statedLower = (stated || '').toLowerCase();
  if (statedLower === 'conservative' && score > 23) return true;
  if (statedLower === 'moderate' && (score < 24 || score > 47)) return true;
  if (statedLower === 'aggressive' && (score < 48 || score > 78)) return true;
  return false;
}

// Aion's portfolio analysis
async function _buildAnalysis(user_id, riskData) {
  const [{ data: investments }, { data: onboarding }, { data: aiProfile }, { data: debts }] = await Promise.all([
    supabase.from('investments').select('*').eq('user_id', user_id).eq('is_active', true),
    supabase.from('onboarding_profiles').select('*').eq('user_id', user_id).single(),
    supabase.from('ai_financial_profiles').select('*').eq('user_id', user_id).single(),
    supabase.from('debts').select('name, current_balance, interest_rate').eq('user_id', user_id).eq('is_active', true),
  ]);

  if (!investments?.length) return 'Add your investment holdings to get personalised analysis from Aion.';

  const { safeGeminiCall } = require('../services/geminiService');
  const usdToMyr = await _getUsdToMyr();

  // Use live prices from risk data, convert to RM for comparison with user's RM finances
  const riskHoldings = riskData?.holdings || [];
  const rmSuffix = (usd) => usdToMyr ? ` (RM ${(usd * usdToMyr).toFixed(2)})` : '';
  const holdingsSummary = investments.map(i => {
    const live = riskHoldings.find(h => h.ticker === i.ticker);
    const nowUsd = live?.current_price || parseFloat(i.purchase_price);
    const buyUsd = parseFloat(i.purchase_price);
    const valueUsd = parseFloat(i.units) * nowUsd;
    return `${i.asset_name} (${i.category}): ${i.units} units, bought $${buyUsd}${rmSuffix(buyUsd)}, now $${nowUsd}${rmSuffix(nowUsd)}, value $${valueUsd.toFixed(2)}${rmSuffix(valueUsd)}`;
  }).join('\n');

  const totalValueUsd = riskData?.total_value || investments.reduce((s, i) => {
    const live = riskHoldings.find(h => h.ticker === i.ticker);
    return s + parseFloat(i.units) * (live?.current_price || parseFloat(i.purchase_price));
  }, 0);

  const debtSummary = (debts || []).map(d =>
    `${d.name}: RM ${parseFloat(d.current_balance).toFixed(2)} at ${d.interest_rate}%`
  ).join(', ') || 'None';

  // Read market data: Redis first, MongoDB fallback
  async function _getMarketPrice(symbol) {
    const cached = await cacheGet(`market:${symbol}`);
    if (cached) return cached;
    try {
      const { connectMongo } = require('../config/mongodb');
      const MarketDataCache = require('../models/MarketDataCache');
      await connectMongo();
      return await MarketDataCache.findOne({ symbol }).lean();
    } catch { return null; }
  }

  const marketContext = [];
  const spy = await _getMarketPrice('SPY');
  const qqq = await _getMarketPrice('QQQ');
  const btc = await _getMarketPrice('BTCUSD');
  const eth = await _getMarketPrice('ETHUSD');
  if (spy) marketContext.push(`S&P 500 (SPY): $${spy.price} (${spy.change_pct_24h > 0 ? '+' : ''}${spy.change_pct_24h?.toFixed(2)}%)`);
  if (qqq) marketContext.push(`NASDAQ (QQQ): $${qqq.price} (${qqq.change_pct_24h > 0 ? '+' : ''}${qqq.change_pct_24h?.toFixed(2)}%)`);
  if (btc) marketContext.push(`BTC: $${btc.price} (${btc.change_pct_24h > 0 ? '+' : ''}${btc.change_pct_24h?.toFixed(2)}%)`);
  if (eth) marketContext.push(`ETH: $${eth.price} (${eth.change_pct_24h > 0 ? '+' : ''}${eth.change_pct_24h?.toFixed(2)}%)`);

  const riskSection = riskData
    ? `\nRISK SCORE: ${riskData.risk_score}/100 (${riskData.risk_level})\nStated risk tolerance: ${riskData.stated_risk}\nMismatch: ${riskData.mismatch ? 'YES — portfolio risk does not match stated tolerance' : 'No'}\nBase score: ${riskData.base_score}, HHI penalty: ${riskData.hhi_penalty}`
    : '';

  const prompt = `
You are Aion, a personal financial advisor for a Malaysian user. Analyse their investment portfolio.

CURRENCY NOTE: Investment prices are in USD. User's income, debts, and vaults are in RM (Malaysian Ringgit).
Total portfolio: $${typeof totalValueUsd === 'number' ? totalValueUsd.toFixed(2) : totalValueUsd}${rmSuffix(typeof totalValueUsd === 'number' ? totalValueUsd : 0)}
When comparing investments with income/debts, use the RM values for accurate comparison.
When discussing investment prices, use USD primary with (RM xxx) behind.

USER PROFILE:
Risk tolerance: ${onboarding?.risk_level || 'not specified'}
Life situation: ${onboarding?.life_situation || 'not specified'}
Monthly income: RM ${onboarding?.monthly_income || 'unknown'}
Financial goals: ${JSON.stringify(onboarding?.financial_goals || {})}
Debts: ${debtSummary}
Behavioural type: ${aiProfile?.behavioral_classification || 'not classified'}

HOLDINGS:
${holdingsSummary}
${riskSection}

CURRENT MARKET:
${marketContext.length > 0 ? marketContext.join('\n') : 'Market data unavailable'}

Give a SHORT personalised analysis (under 120 words). PRIORITY ORDER:
1. User-specific advice FIRST — risk score vs stated tolerance, concentration risk, debt vs investing trade-off
2. How their holdings relate to current market movement
3. Any trending opportunities or risks in the broader market relevant to them

Be warm, specific, use actual numbers. Do NOT be generic.
${riskData?.mismatch ? '\nIMPORTANT: The user\'s portfolio risk MISMATCHES their stated tolerance. Address this directly.' : ''}

Respond in JSON: { "analysis": "your analysis here" }`;

  const result = await safeGeminiCall(prompt);
  return result.success ? result.data?.analysis || 'Analysis unavailable.' : 'Analysis unavailable.';
}

const getPortfolioAnalysis = async (req, res) => {
  try {
    // Calculate risk first so analysis has the actual score
    let riskData = null;
    try {
      const riskResult = {};
      await getPortfolioRisk(req, { json: (d) => Object.assign(riskResult, d) });
      riskData = riskResult.data || null;
    } catch (_) {}

    const analysis = await _buildAnalysis(req.user.id, riskData);
    return res.json({ success: true, data: { analysis } });
  } catch (error) {
    console.error('getPortfolioAnalysis error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

const getCryptoPrices = async (req, res) => {
  try {
    // Tier 1: Redis
    const cached = await cacheGet('crypto:market_list');
    if (cached) return res.json({ success: true, data: cached });

    // Tier 2: MongoDB fresh (within 1 min)
    try {
      const { connectMongo } = require('../config/mongodb');
      const MarketDataCache = require('../models/MarketDataCache');
      await connectMongo();
      const newest = await MarketDataCache.findOne({ type: 'crypto' }).sort({ updated_at: -1 }).lean();
      if (newest && newest.updated_at && (Date.now() - new Date(newest.updated_at).getTime()) < 60 * 1000) {
        const docs = await MarketDataCache.find({ type: 'crypto' }).sort({ price: -1 }).lean();
        const fresh = docs.map(d => ({
          ticker: d.symbol.replace('USD', ''),
          name: d.symbol.replace('USD', ''),
          price: d.price,
          change_24h: d.change_pct_24h,
        }));
        console.log('[CryptoPrices] MongoDB fresh hit — skipping CoinGecko');
        return res.json({ success: true, data: fresh });
      }
    } catch (_) {}

    // Tier 3: Call CoinGecko → write to both Redis + MongoDB
    try {
      const axios = require('axios');
      const url = 'https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=100&page=1&price_change_percentage=24h';
      const { data } = await axios.get(url, {
        headers: { 'x-cg-demo-api-key': process.env.COINGECKO_API_KEY },
        timeout: 15000,
      });

      const coins = data.map(c => ({
        id: c.id,
        ticker: c.symbol.toUpperCase(),
        name: c.name,
        price: c.current_price,
        change_24h: c.price_change_percentage_24h,
      }));

      const { cacheSet } = require('../services/cacheService');
      await cacheSet('crypto:market_list', coins, 60);

      // MongoDB backup
      const { connectMongo } = require('../config/mongodb');
      const MarketDataCache = require('../models/MarketDataCache');
      connectMongo().then(async () => {
        for (const c of coins.slice(0, 20)) {
          const symbol = `${c.ticker}USD`;
          await MarketDataCache.findOneAndUpdate({ symbol }, {
            symbol, type: 'crypto', price: c.price,
            change_pct_24h: c.change_24h, updated_at: new Date(),
          }, { upsert: true }).catch(() => {});
        }
      }).catch(() => {});

      return res.json({ success: true, data: coins });
    } catch (apiErr) {
      console.error('getCryptoPrices API error:', apiErr.message);
    }

    // Tier 4: MongoDB stale (last resort)
    try {
      const { connectMongo } = require('../config/mongodb');
      const MarketDataCache = require('../models/MarketDataCache');
      await connectMongo();
      const docs = await MarketDataCache.find({ type: 'crypto' }).sort({ price: -1 }).lean();
      const fallback = docs.map(d => ({
        ticker: d.symbol.replace('USD', ''),
        name: d.symbol.replace('USD', ''),
        price: d.price,
        change_24h: d.change_pct_24h,
      }));
      return res.json({ success: true, data: fallback });
    } catch (_) {}

    return res.json({ success: true, data: [] });
  } catch (error) {
    console.error('getCryptoPrices error:', error.message);
    res.status(500).json({ success: false, message: 'Failed to fetch crypto list' });
  }
};

const getStockQuote = async (req, res) => {
  try {
    const { ticker } = req.params;
    const upperTicker = ticker.toUpperCase();
    const cacheKey = `market:${upperTicker}`;

    // Tier 1: Redis
    const cached = await cacheGet(cacheKey);
    if (cached) return res.json({ success: true, data: { ticker: upperTicker, price: cached.price, change_24h: cached.change_pct_24h } });

    // Tier 2: MongoDB fresh (within 24h)
    try {
      const { connectMongo } = require('../config/mongodb');
      const MarketDataCache = require('../models/MarketDataCache');
      await connectMongo();
      const mongoDoc = await MarketDataCache.findOne({ symbol: upperTicker }).lean();
      if (mongoDoc && mongoDoc.price && mongoDoc.updated_at &&
          (Date.now() - new Date(mongoDoc.updated_at).getTime()) < 86400 * 1000) {
        console.log(`[StockQuote] ${upperTicker} MongoDB fresh hit — skipping Alpha`);
        return res.json({ success: true, data: { ticker: upperTicker, price: mongoDoc.price, change_24h: mongoDoc.change_pct_24h } });
      }
    } catch (_) {}

    // Tier 3: Call Alpha Vantage → write to Redis + MongoDB
    try {
      const axios = require('axios');
      const url = `https://www.alphavantage.co/query?function=GLOBAL_QUOTE&symbol=${ticker}&apikey=${process.env.ALPHA_VANTAGE_API_KEY}`;
      const { data } = await axios.get(url, { timeout: 10000 });
      const quote = data['Global Quote'];
      if (quote && quote['05. price']) {
        const { cacheSet } = require('../services/cacheService');
        const price = parseFloat(quote['05. price']);
        const changePct = parseFloat(quote['10. change percent'].replace('%', ''));
        await cacheSet(cacheKey, { price, change_pct_24h: changePct }, 86400);

        // MongoDB backup
        const { connectMongo } = require('../config/mongodb');
        const MarketDataCache = require('../models/MarketDataCache');
        connectMongo().then(() =>
          MarketDataCache.findOneAndUpdate({ symbol: upperTicker }, {
            symbol: upperTicker, type: 'stock', price, change_pct_24h: changePct, updated_at: new Date(),
          }, { upsert: true })
        ).catch(() => {});

        return res.json({ success: true, data: { ticker: upperTicker, price, change_24h: changePct } });
      }
    } catch (apiErr) {
      console.error('getStockQuote API error:', apiErr.message);
    }

    // Tier 4: MongoDB stale (last resort)
    try {
      const { connectMongo } = require('../config/mongodb');
      const MarketDataCache = require('../models/MarketDataCache');
      await connectMongo();
      const doc = await MarketDataCache.findOne({ symbol: upperTicker }).lean();
      if (doc) {
        console.log(`[StockQuote] ${upperTicker} MongoDB stale fallback`);
        return res.json({ success: true, data: { ticker: upperTicker, price: doc.price, change_24h: doc.change_pct_24h } });
      }
    } catch (_) {}

    return res.json({ success: true, data: { ticker: upperTicker, price: null, change_24h: null } });
  } catch (error) {
    console.error('getStockQuote error:', error.message);
    res.status(500).json({ success: false, message: 'Failed to fetch quote' });
  }
};

const LISTING_CACHE_KEY = 'invest:stock_listings';
const LISTING_TTL = 7 * 24 * 60 * 60; // 7 days
async function _ensureStockList() {
  // Tier 1: Redis
  const cached = await cacheGet(LISTING_CACHE_KEY);
  if (cached) return cached;

  // Tier 2: MongoDB fresh (within 7 days)
  try {
    const { connectMongo: connectMongo2 } = require('../config/mongodb');
    const StockListing2 = require('../models/StockListing');
    await connectMongo2();
    const sample = await StockListing2.findOne().lean();
    if (sample && sample.fetched_at && (Date.now() - new Date(sample.fetched_at).getTime()) < LISTING_TTL * 1000) {
      const mongoDocs = await StockListing2.find().lean();
      if (mongoDocs.length > 0) {
        const listings = mongoDocs.map(d => ({ ticker: d.ticker, name: d.name, exchange: d.exchange, category: d.category }));
        console.log(`[Invest] Loaded ${listings.length} listings from MongoDB fresh — skipping Alpha`);
        return listings;
      }
    }
  } catch (_) {}

  // Tier 3: Call Alpha Vantage → write to Redis + MongoDB
  try {
    const axios = require('axios');
    const url = `https://www.alphavantage.co/query?function=LISTING_STATUS&apikey=${process.env.ALPHA_VANTAGE_API_KEY}`;
    const { data } = await axios.get(url, { timeout: 15000, responseType: 'text' });

    const lines = data.split('\n').slice(1);
    const listings = [];
    for (const line of lines) {
      const cols = line.split(',');
      if (cols.length < 7 || cols[6]?.trim() !== 'Active') continue;
      const assetType = cols[3].trim();
      if (assetType !== 'Stock' && assetType !== 'ETF') continue;
      listings.push({
        ticker: cols[0].trim(),
        name: cols[1].trim(),
        exchange: cols[2].trim(),
        category: assetType === 'ETF' ? 'etf' : 'stocks',
      });
    }

    if (listings.length > 0) {
      const { cacheSet } = require('../services/cacheService');
      await cacheSet(LISTING_CACHE_KEY, listings, LISTING_TTL);

      // MongoDB backup
      const { connectMongo } = require('../config/mongodb');
      const StockListing = require('../models/StockListing');
      connectMongo().then(async () => {
        await StockListing.deleteMany({});
        const batch = listings.slice(0, 5000);
        await StockListing.insertMany(batch, { ordered: false }).catch(() => {});
      }).catch(() => {});

      console.log(`[Invest] Cached ${listings.length} stock/ETF listings for 7 days`);
      return listings;
    }
  } catch (apiErr) {
    console.error('[Invest] Alpha Vantage listing error:', apiErr.message);
  }

  // Tier 4: MongoDB stale (last resort)
  try {
    const { connectMongo } = require('../config/mongodb');
    const StockListing = require('../models/StockListing');
    await connectMongo();
    const docs = await StockListing.find().lean();
    if (docs.length > 0) {
      const listings = docs.map(d => ({ ticker: d.ticker, name: d.name, exchange: d.exchange, category: d.category }));
      console.log(`[Invest] Loaded ${listings.length} listings from MongoDB stale fallback`);
      return listings;
    }
  } catch (_) {}

  return [];
}

const getListings = async (req, res) => {
  try {
    const category = req.query.category;
    const listings = await _ensureStockList();
    const filtered = category ? listings.filter(l => l.category === category) : listings;
    return res.json({ success: true, data: filtered });
  } catch (error) {
    console.error('getListings error:', error.message);
    res.status(500).json({ success: false, message: 'Failed to fetch listings' });
  }
};

module.exports = { getInvestments, createInvestment, updateInvestment, deleteInvestment, saveAllInvestments, getPortfolioRisk, getPortfolioAnalysis, getCryptoPrices, getStockQuote, getListings };
