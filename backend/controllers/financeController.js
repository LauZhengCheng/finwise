// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : financeController.js
// Description   : Financial health score, net worth, and spending forecast
// First Written : 17-06-2026
// Edited on     : 17-06-2026
// ============================================

const supabase = require('../config/supabase');

// FHN FinHealth Score — 8 indicators, 4 dimensions + Aion analysis
const getHealthScore = async (req, res) => {
  try {
    const { calculateHealthScore } = require('../services/healthScoreService');
    const result = await calculateHealthScore(req.user.id);

    // Generate Aion's advice based on the score breakdown
    try {
      const [{ data: onboarding }, { data: aiProfile }, { data: debts }] = await Promise.all([
        supabase.from('onboarding_profiles').select('monthly_income, risk_level, financial_goals, life_situation').eq('user_id', req.user.id).single(),
        supabase.from('ai_financial_profiles').select('behavioral_classification, key_insights').eq('user_id', req.user.id).single(),
        supabase.from('debts').select('name, current_balance, interest_rate').eq('user_id', req.user.id).eq('is_active', true),
      ]);

      const { safeGeminiCall } = require('../services/geminiService');
      const dims = result.dimensions;
      const prompt = `
You are Aion, a warm personal financial advisor. Analyse this user's Financial Health Score (FHN methodology) and give advice.

USER PROFILE:
Income: RM ${onboarding?.monthly_income || 'unknown'}/month
Risk level: ${onboarding?.risk_level || 'unknown'}
Life situation: ${onboarding?.life_situation || 'unknown'}
Goals: ${JSON.stringify(onboarding?.financial_goals || {})}
Behavioural type: ${aiProfile?.behavioral_classification || 'unknown'}
Debts: ${(debts || []).map(d => `${d.name}: RM ${parseFloat(d.current_balance).toFixed(0)} at ${d.interest_rate}%`).join(', ') || 'None'}

HEALTH SCORE: ${result.score}/100 (${result.tier})

DIMENSION BREAKDOWN:
Spend: ${dims.spend.score}/100 (${dims.spend.indicators.map(i => `${i.name}: ${i.score}`).join(', ')})
Save: ${dims.save.score}/100 (${dims.save.indicators.map(i => `${i.name}: ${i.score}`).join(', ')})
Borrow: ${dims.borrow.score}/100 (${dims.borrow.indicators.map(i => `${i.name}: ${i.score}`).join(', ')})
Plan: ${dims.plan.score}/100 (${dims.plan.indicators.map(i => `${i.name}: ${i.score}`).join(', ')})

Give personalised advice. Respond in JSON:
{
  "overall": "2-3 sentence overall assessment and top priority action",
  "spend_advice": "1 sentence specific to their Spend score — why it's this score and what to do",
  "save_advice": "1 sentence specific to their Save score",
  "borrow_advice": "1 sentence specific to their Borrow score",
  "plan_advice": "1 sentence specific to their Plan score"
}

Be warm, specific (use actual numbers), and focus on the WEAKEST dimension first. Do NOT be generic.`;

      const aiResult = await safeGeminiCall(prompt);
      if (aiResult.success && aiResult.data) {
        result.aion_advice = aiResult.data;
      }
    } catch (_) {}

    return res.json({ success: true, data: result });
  } catch (error) {
    console.error('getHealthScore error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

const getInsuranceCoverage = async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('onboarding_profiles')
      .select('insurance_coverage')
      .eq('user_id', req.user.id)
      .single();
    if (error) throw error;
    return res.json({ success: true, data: data?.insurance_coverage || {} });
  } catch (error) {
    console.error('getInsuranceCoverage error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

const updateInsuranceCoverage = async (req, res) => {
  try {
    const { coverage } = req.body;
    const { INSURANCE_TYPES } = require('../services/healthScoreService');
    const safe = {};
    for (const key of INSURANCE_TYPES) {
      if (coverage[key] !== undefined) safe[key] = !!coverage[key];
    }
    await supabase.from('onboarding_profiles')
      .update({ insurance_coverage: safe })
      .eq('user_id', req.user.id);
    return res.json({ success: true, data: safe });
  } catch (error) {
    console.error('updateInsuranceCoverage error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

const getNetWorth = async (req, res) => {
  try {
    const user_id = req.user.id;

    const [{ data: vaults }, { data: debts }] = await Promise.all([
      supabase.from('vaults').select('id, name, vault_type, current_balance, category_key').eq('user_id', user_id).eq('is_active', true),
      supabase.from('debts').select('id, name, debt_type, current_balance').eq('user_id', user_id).eq('is_active', true),
    ]);

    const assets = (vaults || []).reduce((sum, v) => sum + parseFloat(v.current_balance || 0), 0);
    const liabilities = (debts || []).reduce((sum, d) => sum + parseFloat(d.current_balance || 0), 0);
    const net_worth = Math.round((assets - liabilities) * 100) / 100;

    return res.json({
      success: true,
      data: {
        net_worth,
        assets: Math.round(assets * 100) / 100,
        liabilities: Math.round(liabilities * 100) / 100,
        vault_breakdown: (vaults || []).map((v) => ({
          id: v.id,
          name: v.name,
          vault_type: v.vault_type,
          current_balance: parseFloat(v.current_balance),
        })),
        debt_breakdown: (debts || []).map((d) => ({
          id: d.id,
          name: d.name,
          debt_type: d.debt_type,
          current_balance: parseFloat(d.current_balance),
        })),
      },
    });
  } catch (error) {
    console.error('getNetWorth error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

const getSpendingForecast = async (req, res) => {
  try {
    const user_id = req.user.id;
    const { getMonthContext } = require('../utils/dateUtils');
    const { day: dayOfMonth, total: daysInMonth, left: daysLeft, pct: monthProgress } = getMonthContext();

    const thirtyDaysAgo = new Date(Date.now() - 30 * 86400000).toISOString();
    const sevenDaysAgo = new Date(Date.now() - 7 * 86400000).toISOString();
    const sixtyDaysAgo = new Date(Date.now() - 60 * 86400000).toISOString();

    const [{ data: vaults }, { data: txs30 }, { data: txs7 }, { data: txsPrev }] = await Promise.all([
      supabase.from('vaults')
        .select('id, name, current_balance, allocated_amount, spent_amount')
        .eq('user_id', user_id).eq('is_active', true).eq('vault_type', 'vault')
        .is('completed_at', null),
      supabase.from('transactions')
        .select('vault_id, amount, created_at')
        .eq('user_id', user_id).eq('status', 'approved').eq('transaction_type', 'expense')
        .gte('created_at', thirtyDaysAgo),
      supabase.from('transactions')
        .select('vault_id, amount')
        .eq('user_id', user_id).eq('status', 'approved').eq('transaction_type', 'expense')
        .gte('created_at', sevenDaysAgo),
      supabase.from('transactions')
        .select('vault_id, amount')
        .eq('user_id', user_id).eq('status', 'approved').eq('transaction_type', 'expense')
        .gte('created_at', sixtyDaysAgo).lt('created_at', thirtyDaysAgo),
    ]);

    // Group transactions by vault (raw amounts)
    const group = (txs) => {
      const map = {};
      for (const tx of txs || []) {
        if (!tx.vault_id) continue;
        if (!map[tx.vault_id]) map[tx.vault_id] = [];
        map[tx.vault_id].push(parseFloat(tx.amount));
      }
      return map;
    };

    // Group transactions by vault AND by date (for EWMA daily totals)
    const groupByDay = (txs) => {
      const map = {};
      for (const tx of txs || []) {
        if (!tx.vault_id) continue;
        if (!map[tx.vault_id]) map[tx.vault_id] = {};
        const day = tx.created_at.split('T')[0];
        map[tx.vault_id][day] = (map[tx.vault_id][day] || 0) + parseFloat(tx.amount);
      }
      return map;
    };

    const spend30 = group(txs30);
    const spend30ByDay = groupByDay(txs30);
    const spend7 = group(txs7);
    const spendPrev = group(txsPrev);

    const forecasts = (vaults || []).map((v) => {
      const balance = parseFloat(v.current_balance);
      const allocated = parseFloat(v.allocated_amount || 0);
      const spent = parseFloat(v.spent_amount || 0);

      const amounts30 = spend30[v.id] || [];
      const amounts7 = spend7[v.id] || [];
      const amountsPrev = spendPrev[v.id] || [];

      const total30 = amounts30.reduce((s, a) => s + a, 0);
      const total7 = amounts7.reduce((s, a) => s + a, 0);
      const totalPrev = amountsPrev.reduce((s, a) => s + a, 0);

      // Burst detection: remove transactions > 3× median
      const sorted = [...amounts30].sort((a, b) => a - b);
      const median = sorted.length > 0 ? sorted[Math.floor(sorted.length / 2)] : 0;
      const threshold = median * 3;
      const regularAmounts = threshold > 0
        ? amounts30.filter(a => a <= threshold)
        : amounts30;
      const bursts = threshold > 0
        ? amounts30.filter(a => a > threshold)
        : [];

      const regularTotal = regularAmounts.reduce((s, a) => s + a, 0);
      const burstTotal = bursts.reduce((s, a) => s + a, 0);

      // EWMA daily spend estimate (JP Morgan RiskMetrics λ=0.94)
      // Each day's spending decays exponentially — recent days have more influence
      const LAMBDA = 0.94;
      const dailyMap = spend30ByDay[v.id] || {};
      const days = [];
      for (let i = 29; i >= 0; i--) {
        const d = new Date(Date.now() - i * 86400000).toISOString().split('T')[0];
        days.push(dailyMap[d] || 0);
      }

      // Apply Tukey's burst filter per day — remove individual burst transactions, keep regular ones
      const filteredDays = days.map((dayTotal, idx) => {
        if (threshold <= 0 || dayTotal === 0) return dayTotal;
        const d = new Date(Date.now() - (29 - idx) * 86400000).toISOString().split('T')[0];
        const txsForDay = (txs30 || []).filter(tx =>
          tx.vault_id === v.id && tx.created_at.split('T')[0] === d
        );
        return txsForDay.reduce((s, tx) => {
          const amt = parseFloat(tx.amount);
          return amt <= threshold ? s + amt : s;
        }, 0);
      });

      // Find first non-zero day to seed EWMA — avoids leading zeros dragging estimate down
      const firstNonZero = filteredDays.findIndex(d => d > 0);
      let ewma;
      if (firstNonZero === -1) {
        ewma = 0;
      } else {
        ewma = filteredDays[firstNonZero];
        for (let i = firstNonZero + 1; i < filteredDays.length; i++) {
          ewma = LAMBDA * ewma + (1 - LAMBDA) * filteredDays[i];
        }
      }
      const weightedAvg = Math.round(Math.max(ewma, 0) * 100) / 100;

      // Pace comparison
      const expectedSpend = allocated > 0 ? (allocated / daysInMonth) * dayOfMonth : 0;
      const paceRatio = expectedSpend > 0 ? Math.round((spent / expectedSpend) * 100) / 100 : 0;
      const budgetUsedPct = allocated > 0 ? Math.round((spent / allocated) * 100) : 0;

      // Days remaining + run-out date
      const daysRemaining = weightedAvg > 0 ? Math.floor(balance / weightedAvg) : null;
      const runOutDate = daysRemaining != null
        ? require('../utils/dateUtils').formatDateMYT(Date.now() + daysRemaining * 86400000, { day: 'numeric', month: 'short' })
        : null;

      // Target daily spend to last the month
      const targetDaily = daysLeft > 0 ? Math.round((balance / daysLeft) * 100) / 100 : 0;
      const needsReduction = weightedAvg > targetDaily && targetDaily > 0;

      // Last month comparison
      const lastMonthTotal = totalPrev > 0 ? Math.round(totalPrev * 100) / 100 : null;
      const projectedTotal = Math.round(weightedAvg * daysInMonth * 100) / 100;
      const monthOverMonth = lastMonthTotal && lastMonthTotal > 0
        ? Math.round(((projectedTotal - lastMonthTotal) / lastMonthTotal) * 100)
        : null;

      // Status
      let status = 'ok';
      if (daysRemaining !== null && daysRemaining < daysLeft) {
        status = daysRemaining < 7 ? 'critical' : 'warning';
      }
      if (paceRatio > 1.3 && budgetUsedPct > 50) {
        status = status === 'ok' ? 'warning' : status;
      }

      return {
        vault_id: v.id,
        vault_name: v.name,
        current_balance: Math.round(balance * 100) / 100,
        allocated_amount: Math.round(allocated * 100) / 100,
        spent_amount: Math.round(spent * 100) / 100,
        budget_used_pct: budgetUsedPct,
        weighted_avg_daily: weightedAvg,
        avg_30d: Math.round((regularTotal / 30) * 100) / 100,
        avg_7d: Math.round((amounts7.filter(a => threshold <= 0 || a <= threshold).reduce((s, a) => s + a, 0) / 7) * 100) / 100,
        days_remaining: daysRemaining,
        run_out_date: runOutDate,
        target_daily: targetDaily,
        needs_reduction: needsReduction,
        pace_ratio: paceRatio,
        burst_total: Math.round(burstTotal * 100) / 100,
        burst_count: bursts.length,
        last_month_total: lastMonthTotal,
        projected_total: projectedTotal,
        month_over_month_pct: monthOverMonth,
        status,
      };
    });

    // Sort: critical first, then warning, then ok
    const order = { critical: 0, warning: 1, ok: 2 };
    forecasts.sort((a, b) => (order[a.status] ?? 2) - (order[b.status] ?? 2));

    return res.json({
      success: true,
      data: {
        month_progress: { day: dayOfMonth, total: daysInMonth, left: daysLeft, pct: monthProgress },
        forecasts,
      },
    });
  } catch (error) {
    console.error('getSpendingForecast error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

// ─────────────────────────────────────────────
// GET NEWS
// Returns cached news from Redis → MongoDB fallback
// ─────────────────────────────────────────────
const getFinancialNews = async (req, res) => {
  try {
    const { cacheGet } = require('../services/cacheService');
    let articles = await cacheGet('news');

    if (!articles || !Array.isArray(articles) || articles.length === 0) {
      try {
        const { connectMongo } = require('../config/mongodb');
        const NewsArticle = require('../models/NewsArticle');
        await connectMongo();
        articles = await NewsArticle.find().sort({ published_at: -1 }).limit(50).lean();
      } catch { /* MongoDB unavailable */ }
    }

    if (!articles || articles.length === 0) {
      return res.json({ success: true, data: { breaking: [], articles: [] } });
    }

    const breaking = articles.filter(a => a.is_breaking);
    const regular = articles.filter(a => !a.is_breaking);

    return res.json({
      success: true,
      data: {
        breaking: breaking.map(a => ({
          title: a.title, summary: a.summary, sentiment: a.sentiment,
          source: a.source, url: a.url, image_url: a.image_url,
          tags: a.tags || [], published_at: a.published_at,
        })),
        articles: regular.map(a => ({
          title: a.title, summary: a.summary, sentiment: a.sentiment,
          source: a.source, url: a.url, image_url: a.image_url,
          tags: a.tags || [], published_at: a.published_at,
        })),
      },
    });
  } catch (error) {
    console.error('getFinancialNews error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

const getFDRates = async (req, res) => {
  try {
    const { cacheGet } = require('../services/cacheService');
    let rates = await cacheGet('fd_rates');

    if (!rates || !Array.isArray(rates) || rates.length === 0) {
      try {
        const { connectMongo } = require('../config/mongodb');
        const FDRate = require('../models/FDRate');
        await connectMongo();
        rates = await FDRate.find().sort({ interest_rate: -1 }).lean();
      } catch { /* MongoDB unavailable */ }
    }

    const mapped = (rates || []).map(r => ({
      bank: r.bank,
      product: r.product,
      interest_rate: r.interest_rate,
      tenure_months: r.tenure_months,
      min_amount: r.min_amount,
      is_islamic: r.is_islamic || false,
      apply_url: r.apply_url,
      logo_url: r.logo_url || null,
    }));

    return res.json({ success: true, data: mapped });
  } catch (error) {
    console.error('getFDRates error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

const getDeals = async (req, res) => {
  try {
    // Read from MongoDB directly — Redis cache may have stale data without source_url
    let deals = null;
    try {
      const { connectMongo } = require('../config/mongodb');
      const Deal = require('../models/Deal');
      await connectMongo();
      deals = await Deal.find().sort({ scraped_at: -1 }).limit(100).lean();
    } catch { /* MongoDB unavailable */ }

    if (!deals || deals.length === 0) {
      const { cacheGet } = require('../services/cacheService');
      deals = await cacheGet('deals');
    }

    return res.json({
      success: true,
      data: (deals || []).map(d => ({
        merchant: d.merchant,
        deal_title: d.deal_title,
        category: d.category || 'other',
        discount_pct: d.discount_pct,
        max_cashback: d.max_cashback,
        is_need: d.is_need || false,
        is_want: d.is_want || false,
        aion_note: d.aion_note,
        apply_url: d.apply_url || null,
        source_url: d.source_url || null,
      })),
    });
  } catch (error) {
    console.error('getDeals error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

const getProtectionRecommendations = async (req, res) => {
  try {
    const user_id = req.user.id;

    const [{ data: profile }, { data: onboarding }, { data: aiProfile }, { data: debts }, { data: vaults }] = await Promise.all([
      supabase.from('profiles').select('full_name').eq('id', user_id).single(),
      supabase.from('onboarding_profiles').select('*').eq('user_id', user_id).single(),
      supabase.from('ai_financial_profiles').select('*').eq('user_id', user_id).single(),
      supabase.from('debts').select('name, debt_type, current_balance').eq('user_id', user_id).eq('is_active', true),
      supabase.from('vaults').select('name, category_key, vault_type, current_balance, linked_goal')
        .eq('user_id', user_id).eq('is_active', true),
    ]);

    const { safeGeminiCall } = require('../services/geminiService');
    const prompt = `
You are Aion, a personal financial advisor. Analyse this user's profile and recommend personalised insurance/protection products.

USER:
Name: ${profile?.full_name || 'User'}
Life situation: ${onboarding?.life_situation || 'not specified'}
Monthly income: RM ${onboarding?.monthly_income || 'not specified'}
Financial goals: ${JSON.stringify(onboarding?.financial_goals || {})}
Financial challenges: ${onboarding?.financial_challenges || 'not specified'}
Risk level: ${onboarding?.risk_level || 'not specified'}
Behavioural type: ${aiProfile?.behavioral_classification || 'not classified'}
Key insights: ${JSON.stringify(aiProfile?.key_insights || {})}

DEBTS: ${(debts || []).length > 0
      ? debts.map(d => `${d.name} (${d.debt_type}, RM ${parseFloat(d.current_balance).toFixed(2)})`).join(', ')
      : 'None'}

SAVING GOALS: ${(vaults || []).filter(v => v.vault_type === 'fund').map(v => `${v.name}: ${v.linked_goal || 'general savings'}`).join(', ') || 'None'}

CURRENT INSURANCE COVERAGE:
${onboarding?.insurance_coverage ? Object.entries(onboarding.insurance_coverage)
  .map(([k, v]) => `- ${k.replace(/_/g, ' ')}: ${v ? 'YES ✓' : 'NO ✗'}`)
  .join('\n') : 'No insurance data recorded'}

Based on this SPECIFIC user's situation, recommend insurance/protection products.
Focus on what they are MISSING — do not recommend what they already have.
Do NOT give a generic list — only recommend what is RELEVANT to this user.
For each recommendation, explain WHY it matters for THIS user specifically.

Respond in JSON:
{
  "recommendations": [
    {
      "type": "Car Insurance",
      "priority": "essential",
      "icon": "car",
      "reason": "You have a Myvi car loan — legally required and protects your RM 55,000 asset.",
      "benefit": "Covers accident damage, theft, and third-party liability"
    }
  ]
}

Priority levels: "essential" (legally required or critical), "important" (strongly recommended), "suggested" (nice to have), "later" (not urgent for current life stage)
Icon options: "car", "medical", "life", "home", "travel", "disability", "education", "business", "pet", "critical_illness", "personal_accident", "other"
Maximum 6 recommendations. Only include what's relevant.`;

    const result = await safeGeminiCall(prompt);
    return res.json({
      success: true,
      data: result.success ? result.data?.recommendations || [] : [],
    });
  } catch (error) {
    console.error('getProtectionRecommendations error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

const getTickerData = async (req, res) => {
  try {
    const { fetchTickerQuotes } = require('../services/marketDataService');
    const { cacheGet } = require('../services/cacheService');
    const { connectMongo } = require('../config/mongodb');
    const MarketDataCache = require('../models/MarketDataCache');

    // Stocks — use stock_listings from Alpha + quote via Finnhub
    const StockListing = require('../models/StockListing');
    let stocks = [];
    try {
      await connectMongo();

      // Get stock tickers — if empty, populate via Finnhub symbol list
      let allTickers = [];
      let listings = await StockListing.find({ category: 'stocks' }).select('ticker').limit(100).lean();

      // If stock_listings empty, get symbols from Finnhub (free endpoint)
      console.log(`[Ticker] stock_listings count: ${listings.length}, FINNHUB_KEY: ${process.env.FINNHUB_API_KEY ? 'SET' : 'MISSING'}`);
      if (listings.length === 0 && process.env.FINNHUB_API_KEY) {
        try {
          const axios = require('axios');
          const { data } = await axios.get(
            `https://finnhub.io/api/v1/stock/symbol?exchange=US&mic=XNYS&token=${process.env.FINNHUB_API_KEY}`,
            { timeout: 15000 });
          if (data?.length > 0) {
            const nyseSymbols = data
              .filter(s => s.type === 'Common Stock' && !s.symbol.includes('.'))
              .slice(0, 200);
            const bulkOps = nyseSymbols.map(s => ({
              ticker: s.symbol, name: s.description, exchange: 'NYSE', category: 'stocks',
              fetched_at: new Date(),
            }));
            await StockListing.insertMany(bulkOps, { ordered: false }).catch(() => {});
            listings = await StockListing.find({ category: 'stocks' }).select('ticker').limit(100).lean();
            console.log(`[Ticker] Populated ${nyseSymbols.length} NYSE stocks from Finnhub`);
          }
        } catch (e) { console.error('[Ticker] Finnhub symbol list error:', e.message); }
      }

      if (listings.length > 0) {
        allTickers = listings.map(l => l.ticker);
      }

      // Find which need refresh
      const freshCutoff = new Date(Date.now() - 5 * 60 * 1000);
      const alreadyFresh = await MarketDataCache.find({
        type: 'stock', symbol: { $in: allTickers }, updated_at: { $gte: freshCutoff }
      }).select('symbol').lean();
      const freshSymbols = new Set(alreadyFresh.map(d => d.symbol));

      // Refresh stale ones in background — don't block page load
      const needRefresh = allTickers.filter(s => !freshSymbols.has(s)).slice(0, 50);
      if (needRefresh.length > 0) {
        fetchTickerQuotes(needRefresh).catch(() => {});
      }

      // Return ALL stocks from MongoDB
      const allStockDocs = await MarketDataCache.find({ type: 'stock' }).lean();
      stocks = allStockDocs.map(d => ({
        symbol: d.symbol, price: d.price, change_pct: d.change_pct_24h, type: 'stock',
      }));
    } catch (_) {}

    // Crypto — Redis first, MongoDB fallback
    let crypto = [];
    const cryptoList = await cacheGet('crypto:market_list');
    if (cryptoList && cryptoList.length > 0) {
      crypto = cryptoList.map(c => ({
        symbol: c.ticker, price: c.price, change_pct: c.change_24h, type: 'crypto',
      }));
    } else {
      try {
        await connectMongo();
        const cryptoDocs = await MarketDataCache.find({ type: 'crypto' }).sort({ price: -1 }).lean();
        crypto = cryptoDocs.map(d => ({
          symbol: d.symbol.replace('USD', ''), price: d.price, change_pct: d.change_pct_24h, type: 'crypto',
        }));
      } catch (_) {}
    }

    // FX from MongoDB (all pairs)
    const fx = [];
    try {
      await connectMongo();
      const fxDocs = await MarketDataCache.find({ type: 'fx' }).lean();
      for (const doc of fxDocs) {
        fx.push({ symbol: doc.symbol.replace('MYR', 'MYR/'), price: doc.price, type: 'fx' });
      }
    } catch (_) {}

    return res.json({
      success: true,
      data: {
        stocks,
        crypto,
        fx,
      },
    });
  } catch (error) {
    console.error('getTickerData error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

module.exports = { getHealthScore, getInsuranceCoverage, updateInsuranceCoverage, getNetWorth, getSpendingForecast, getFinancialNews, getFDRates, getDeals, getProtectionRecommendations, getTickerData };
