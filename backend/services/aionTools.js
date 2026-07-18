// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : aionTools.js
// Description   : Tool definitions for Aion LangGraph agent.
//                 Each tool is a function Aion can call on-demand
//                 to fetch data or perform actions. Zod schemas
//                 validate inputs. Tools query Supabase/Redis/MongoDB.
//                 Every tool is wrapped in try-catch — runtime errors
//                 return a friendly message instead of crashing the agent.
// First Written : 20-06-2026
// Edited on     : 20-06-2026
// ============================================

const { tool } = require('@langchain/core/tools');
const { z } = require('zod');
const supabase = require('../config/supabase');
const { formatDateMYT } = require('../utils/dateUtils');

// ─────────────────────────────────────────────
// TOOL: get_vault_transactions
// ─────────────────────────────────────────────
const getVaultTransactions = tool(
  async ({ vault_name, limit }, config) => {
    try {
      const userId = config.configurable?.userId;
      if (!userId) return 'Error: no user context';

      const { data: vaults } = await supabase
        .from('vaults')
        .select('id, name')
        .eq('user_id', userId)
        .eq('is_active', true);

      const match = (vaults || []).find(
        (v) => v.name.toLowerCase().includes(vault_name.toLowerCase())
      );
      if (!match) return `No vault found matching "${vault_name}". Available vaults: ${(vaults || []).map(v => v.name).join(', ')}`;

      const { data: txs } = await supabase
        .from('transactions')
        .select('merchant_name, amount, status, transaction_type, created_at')
        .eq('user_id', userId)
        .eq('vault_id', match.id)
        .order('created_at', { ascending: false })
        .limit(limit || 10);

      if (!txs?.length) return `No transactions found for ${match.name}`;

      return JSON.stringify(txs.map((t) => ({
        merchant: t.merchant_name,
        amount: parseFloat(t.amount),
        status: t.status,
        type: t.transaction_type,
        date: formatDateMYT(t.created_at),
      })));
    } catch (err) {
      return `Could not fetch vault transactions: ${err.message}`;
    }
  },
  {
    name: 'get_vault_transactions',
    description: 'Get recent transactions for a specific vault. Use when the user asks about spending in a particular vault, why a vault is empty, or what they spent on.',
    schema: z.object({
      vault_name: z.string().describe('Name or partial name of the vault to look up'),
      limit: z.number().optional().default(10).describe('Max number of transactions to return'),
    }),
  }
);

// ─────────────────────────────────────────────
// TOOL: get_recent_transactions
// ─────────────────────────────────────────────
const getRecentTransactions = tool(
  async ({ limit }, config) => {
    try {
      const userId = config.configurable?.userId;
      if (!userId) return 'Error: no user context';

      const { data: txs } = await supabase
        .from('transactions')
        .select('merchant_name, amount, status, transaction_type, created_at, vaults(name)')
        .eq('user_id', userId)
        .order('created_at', { ascending: false })
        .limit(limit || 15);

      if (!txs?.length) return 'No transactions found';

      return JSON.stringify(txs.map((t) => ({
        merchant: t.merchant_name,
        amount: parseFloat(t.amount),
        status: t.status,
        type: t.transaction_type,
        vault: t.vaults?.name || 'Unknown',
        date: formatDateMYT(t.created_at),
      })));
    } catch (err) {
      return `Could not fetch recent transactions: ${err.message}`;
    }
  },
  {
    name: 'get_recent_transactions',
    description: 'Get recent transactions across all vaults. Use when the user asks "what did I spend this week", "show my recent transactions", or general spending questions.',
    schema: z.object({
      limit: z.number().optional().default(15).describe('Max number of transactions to return'),
    }),
  }
);

// ─────────────────────────────────────────────
// TOOL: get_spending_velocity
// ─────────────────────────────────────────────
const getSpendingVelocity = tool(
  async (_, config) => {
    try {
      const userId = config.configurable?.userId;
      if (!userId) return 'Error: no user context';

      const { data: vaults } = await supabase
        .from('vaults')
        .select('id, name, vault_type, current_balance, allocated_amount, spent_amount')
        .eq('user_id', userId)
        .eq('is_active', true)
        .eq('vault_type', 'vault');

      if (!vaults?.length) return 'No spending vaults found';

      const thirtyDaysAgo = new Date();
      thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

      const results = [];
      for (const v of vaults) {
        const { data: txs } = await supabase
          .from('transactions')
          .select('amount, created_at')
          .eq('user_id', userId)
          .eq('vault_id', v.id)
          .eq('status', 'approved')
          .gte('created_at', thirtyDaysAgo.toISOString());

        const totalSpent = (txs || []).reduce((sum, t) => sum + parseFloat(t.amount), 0);
        const days = Math.max(1, (txs || []).length > 0
          ? Math.ceil((Date.now() - new Date(txs[txs.length - 1].created_at).getTime()) / 86400000)
          : 30);
        const avgPerDay = Math.round((totalSpent / days) * 100) / 100;
        const daysLeft = avgPerDay > 0
          ? Math.floor(parseFloat(v.current_balance) / avgPerDay)
          : null;

        results.push({
          vault: v.name,
          current_balance: parseFloat(v.current_balance),
          avg_daily_spend: avgPerDay,
          days_until_empty: daysLeft,
          total_spent_30d: Math.round(totalSpent * 100) / 100,
        });
      }
      return JSON.stringify(results);
    } catch (err) {
      return `Could not calculate spending velocity: ${err.message}`;
    }
  },
  {
    name: 'get_spending_velocity',
    description: 'Calculate spending velocity for each vault — average daily spend and days until empty. Use when user asks "will my budget last", "am I overspending", or for proactive advice.',
    schema: z.object({}),
  }
);

// ─────────────────────────────────────────────
// TOOL: get_user_debts
// Returns comprehensive debt data + summary
// ─────────────────────────────────────────────
const getUserDebts = tool(
  async (_, config) => {
    try {
      const userId = config.configurable?.userId;
      if (!userId) return 'Error: no user context';

      const { data: debts } = await supabase
        .from('debts')
        .select('*')
        .eq('user_id', userId)
        .eq('is_active', true)
        .order('interest_rate', { ascending: false, nullsFirst: false });

      if (!debts?.length) return 'No active debts';

      const totalBalance = debts.reduce((s, d) => s + parseFloat(d.current_balance || 0), 0);
      const totalMinimum = debts.reduce((s, d) => s + parseFloat(d.minimum_payment || 0), 0);
      const monthlyInterest = debts.reduce((s, d) => {
        const rate = parseFloat(d.interest_rate || 0) / 100 / 12;
        return s + parseFloat(d.current_balance || 0) * rate;
      }, 0);

      return JSON.stringify({
        summary: {
          total_debts: debts.length,
          total_balance: Math.round(totalBalance * 100) / 100,
          total_minimum_monthly: Math.round(totalMinimum * 100) / 100,
          monthly_interest_cost: Math.round(monthlyInterest * 100) / 100,
        },
        debts: debts.map((d) => ({
          name: d.name,
          type: d.debt_type,
          lender: d.lender,
          principal: parseFloat(d.principal_amount),
          remaining: parseFloat(d.current_balance),
          interest_rate: d.interest_rate ? parseFloat(d.interest_rate) : null,
          interest_type: d.interest_type,
          promotional_until: d.promotional_rate_until,
          minimum_payment: d.minimum_payment ? parseFloat(d.minimum_payment) : null,
          actual_payment: d.current_monthly_payment ? parseFloat(d.current_monthly_payment) : null,
          remaining_months: d.remaining_months,
          due_day: d.due_date,
          is_secured: d.is_secured,
          collateral: d.collateral,
          paid_percentage: d.principal_amount > 0
            ? Math.round((1 - parseFloat(d.current_balance) / parseFloat(d.principal_amount)) * 100)
            : 0,
        })),
      });
    } catch (err) {
      return `Could not fetch debts: ${err.message}`;
    }
  },
  {
    name: 'get_user_debts',
    description: 'Get all active debts with full details — balances, interest rates, payment schedules, collateral, and summary totals. Use when user asks about debts, wants payoff advice, or when you need to consider debt obligations before giving financial advice.',
    schema: z.object({}),
  }
);

// ─────────────────────────────────────────────
// TOOL: get_debt_strategy
// Calculates avalanche vs snowball payoff plans
// ─────────────────────────────────────────────
const getDebtStrategy = tool(
  async ({ extra_monthly_payment }, config) => {
    try {
      const userId = config.configurable?.userId;
      if (!userId) return 'Error: no user context';

      const [{ data: debts }, { data: aiProfile }] = await Promise.all([
        supabase.from('debts')
          .select('name, current_balance, interest_rate, minimum_payment, interest_type, promotional_rate_until')
          .eq('user_id', userId).eq('is_active', true),
        supabase.from('ai_financial_profiles')
          .select('behavioral_classification').eq('user_id', userId).single(),
      ]);

      if (!debts?.length) return 'No active debts to strategise';
      const classification = aiProfile?.behavioral_classification || 'balanced_spender';

      const extra = extra_monthly_payment || 0;
      const debtList = debts.map(d => ({
        name: d.name,
        balance: parseFloat(d.current_balance),
        rate: parseFloat(d.interest_rate || 0),
        minimum: parseFloat(d.minimum_payment || 0),
        isPromotional: d.interest_type === 'promotional',
        promoEnd: d.promotional_rate_until,
      }));

      // Avalanche: highest interest first
      const avalancheOrder = [...debtList].sort((a, b) => b.rate - a.rate);
      const avalancheResult = _simulatePayoff(avalancheOrder, extra);

      // Snowball: smallest balance first
      const snowballOrder = [...debtList].sort((a, b) => a.balance - b.balance);
      const snowballResult = _simulatePayoff(snowballOrder, extra);

      return JSON.stringify({
        avalanche: {
          strategy: 'Pay highest interest rate first — saves the most money',
          order: avalancheOrder.map(d => `${d.name} (${d.rate}%)`),
          months_to_debt_free: avalancheResult.months,
          total_interest_paid: avalancheResult.totalInterest,
        },
        snowball: {
          strategy: 'Pay smallest balance first — fastest psychological wins',
          order: snowballOrder.map(d => `${d.name} (RM ${d.balance})`),
          months_to_debt_free: snowballResult.months,
          total_interest_paid: snowballResult.totalInterest,
        },
        interest_saved_by_avalanche: Math.round((snowballResult.totalInterest - avalancheResult.totalInterest) * 100) / 100,
        extra_payment_used: extra,
        user_profile: classification,
        recommendation: (() => {
          const saved = Math.round(snowballResult.totalInterest - avalancheResult.totalInterest);
          const snowballTypes = ['impulse_spender', 'high_variability_spender', 'risk_averse'];
          if (saved > 500) return `Recommend AVALANCHE — saves RM ${saved} in interest, too significant to pass up.`;
          if (saved < 50) return `Recommend SNOWBALL — interest difference is only RM ${saved}, clearing small debts first gives quick wins.`;
          if (snowballTypes.includes(classification)) return `Recommend SNOWBALL — based on spending profile, quick wins from clearing small debts will keep motivation high.`;
          return `Recommend AVALANCHE — user has discipline to follow through. Saves RM ${saved} in interest.`;
        })(),
      });
    } catch (err) {
      return `Could not calculate debt strategy: ${err.message}`;
    }
  },
  {
    name: 'get_debt_strategy',
    description: 'Calculate and compare debt payoff strategies (avalanche vs snowball). Shows months to debt-free, total interest paid, and which to prioritise. Use when user asks how to pay off debts efficiently.',
    schema: z.object({
      extra_monthly_payment: z.number().optional().default(0).describe('Extra RM the user can put toward debt each month beyond minimums'),
    }),
  }
);

// Simulates paying off debts in a given order with extra payment going to the first debt
function _simulatePayoff(debts, extraMonthly) {
  const balances = debts.map(d => d.balance);
  const rates = debts.map(d => d.rate / 100 / 12);
  const mins = debts.map(d => d.minimum);
  let months = 0;
  let totalInterest = 0;
  const maxMonths = 360;

  while (balances.some(b => b > 0.01) && months < maxMonths) {
    months++;
    let extraLeft = extraMonthly;
    for (let i = 0; i < balances.length; i++) {
      if (balances[i] <= 0) continue;
      const interest = balances[i] * rates[i];
      totalInterest += interest;
      balances[i] += interest;
      const payment = Math.min(balances[i], mins[i]);
      balances[i] -= payment;
    }
    // Apply extra to first non-zero debt in priority order
    for (let i = 0; i < balances.length; i++) {
      if (balances[i] <= 0 || extraLeft <= 0) continue;
      const apply = Math.min(balances[i], extraLeft);
      balances[i] -= apply;
      extraLeft -= apply;
      break;
    }
  }

  return { months, totalInterest: Math.round(totalInterest * 100) / 100 };
}

// ─────────────────────────────────────────────
// TOOL: get_market_data
// Redis first → MongoDB fallback
// ─────────────────────────────────────────────
const getMarketData = tool(
  async ({ symbols }) => {
    try {
      const { cacheGet } = require('./cacheService');
      const results = [];
      for (const sym of symbols) {
        const key = sym.toUpperCase();
        const cached = await cacheGet(`market:${key}`);
        if (cached) {
          results.push(cached);
        } else {
          try {
            const { connectMongo } = require('../config/mongodb');
            const MarketDataCache = require('../models/MarketDataCache');
            await connectMongo();
            const doc = await MarketDataCache.findOne({ symbol: key }).lean();
            if (doc) results.push(doc);
          } catch { /* MongoDB unavailable — skip */ }
        }
      }
      return results.length > 0 ? JSON.stringify(results) : 'No market data available';
    } catch (err) {
      return `Could not fetch market data: ${err.message}`;
    }
  },
  {
    name: 'get_market_data',
    description: 'Get live market prices for stocks, crypto, or forex. Available symbols: BTCUSD, ETHUSD, BNBUSD, SPY, MYRUSD, MYRSGD, KLCI. Use when user asks about market prices or investments.',
    schema: z.object({
      symbols: z.array(z.string()).describe('List of market symbols to fetch, e.g. ["BTCUSD", "KLCI"]'),
    }),
  }
);

// ─────────────────────────────────────────────
// TOOL: get_news
// Redis first → MongoDB fallback
// ─────────────────────────────────────────────
const getNews = tool(
  async ({ limit }) => {
    try {
      const { cacheGet } = require('./cacheService');
      const max = limit || 5;
      const cached = await cacheGet('news');
      if (cached && Array.isArray(cached) && cached.length > 0) {
        return JSON.stringify(cached.slice(0, max).map((a) => ({
          title: a.title, summary: a.summary, sentiment: a.sentiment, source: a.source,
        })));
      }
      try {
        const { connectMongo } = require('../config/mongodb');
        const NewsArticle = require('../models/NewsArticle');
        await connectMongo();
        const docs = await NewsArticle.find().sort({ published_at: -1 }).limit(max).lean();
        if (docs.length > 0) {
          return JSON.stringify(docs.map((a) => ({
            title: a.title, summary: a.summary, sentiment: a.sentiment, source: a.source,
          })));
        }
      } catch { /* MongoDB unavailable */ }
      return 'No news available';
    } catch (err) {
      return `Could not fetch news: ${err.message}`;
    }
  },
  {
    name: 'get_news',
    description: 'Get latest financial news headlines with AI summaries. Use when user asks about news, market updates, or current financial events.',
    schema: z.object({
      limit: z.number().optional().default(5).describe('Max number of articles'),
    }),
  }
);

// ─────────────────────────────────────────────
// TOOL: calculate_loan
// ─────────────────────────────────────────────
const calculateLoan = tool(
  async ({ principal, annual_rate, tenure_months }) => {
    try {
      const r = annual_rate / 100 / 12;
      if (r === 0) {
        const emi = principal / tenure_months;
        return JSON.stringify({ emi: Math.round(emi * 100) / 100, total: principal, interest: 0 });
      }
      const emi = principal * r * Math.pow(1 + r, tenure_months) / (Math.pow(1 + r, tenure_months) - 1);
      const total = Math.round(emi * tenure_months * 100) / 100;
      return JSON.stringify({
        emi: Math.round(emi * 100) / 100,
        total,
        total_interest: Math.round((total - principal) * 100) / 100,
        tenure_months,
      });
    } catch (err) {
      return `Could not calculate loan: ${err.message}`;
    }
  },
  {
    name: 'calculate_loan',
    description: 'Calculate monthly EMI for a loan. Use when user asks about loan affordability, car/home loan calculations.',
    schema: z.object({
      principal: z.number().describe('Loan amount in RM'),
      annual_rate: z.number().describe('Annual interest rate as percentage, e.g. 3.5 for 3.5%'),
      tenure_months: z.number().describe('Loan tenure in months'),
    }),
  }
);

// ─────────────────────────────────────────────
// TOOL: calculate_goal_timeline
// ─────────────────────────────────────────────
const calculateGoalTimeline = tool(
  async ({ target_amount, current_saved, monthly_contribution }) => {
    try {
      const remaining = target_amount - current_saved;
      if (remaining <= 0) return JSON.stringify({ months: 0, message: 'Goal already reached!' });
      if (monthly_contribution <= 0) return JSON.stringify({ months: null, message: 'No monthly contribution — goal cannot be reached at current rate' });
      const months = Math.ceil(remaining / monthly_contribution);
      return JSON.stringify({
        months,
        remaining: Math.round(remaining * 100) / 100,
        estimated_completion: formatDateMYT(Date.now() + months * 30 * 86400000),
      });
    } catch (err) {
      return `Could not calculate goal timeline: ${err.message}`;
    }
  },
  {
    name: 'calculate_goal_timeline',
    description: 'Calculate how many months to reach a savings goal at current contribution rate. Use when user asks "how long to save for X".',
    schema: z.object({
      target_amount: z.number().describe('Target goal amount in RM'),
      current_saved: z.number().describe('Amount already saved in RM'),
      monthly_contribution: z.number().describe('Monthly saving contribution in RM'),
    }),
  }
);

// ─────────────────────────────────────────────
// TOOL: get_fd_rates
// Redis first → MongoDB fallback
// ─────────────────────────────────────────────
const getFDRates = tool(
  async ({ tenure_months, islamic_only }) => {
    try {
      const { cacheGet } = require('./cacheService');
      let rates = await cacheGet('fd_rates');

      if (!rates || !Array.isArray(rates) || rates.length === 0) {
        try {
          const { connectMongo } = require('../config/mongodb');
          const FDRate = require('../models/FDRate');
          await connectMongo();
          rates = await FDRate.find().sort({ interest_rate: -1 }).lean();
        } catch { /* MongoDB unavailable */ }
      }

      if (!rates || rates.length === 0) return 'No FD rate data available';

      let filtered = rates;
      if (tenure_months) filtered = filtered.filter(r => r.tenure_months === tenure_months);
      if (islamic_only) filtered = filtered.filter(r => r.is_islamic === true);

      filtered.sort((a, b) => b.interest_rate - a.interest_rate);
      const top = filtered.slice(0, 10);

      return JSON.stringify(top.map(r => ({
        bank: r.bank,
        product: r.product,
        rate: r.interest_rate,
        tenure: r.tenure_months,
        min_amount: r.min_amount,
        islamic: r.is_islamic,
      })));
    } catch (err) {
      return `Could not fetch FD rates: ${err.message}`;
    }
  },
  {
    name: 'get_fd_rates',
    description: 'Get Malaysian fixed deposit rates comparison. Use when user asks about FD rates, best savings rates, or where to park money. Can filter by tenure and Islamic products.',
    schema: z.object({
      tenure_months: z.number().optional().describe('Filter by specific tenure in months, e.g. 12 for 1 year'),
      islamic_only: z.boolean().optional().default(false).describe('Only show Islamic FD products'),
    }),
  }
);

// ─────────────────────────────────────────────
// TOOL: get_deals
// Redis first → MongoDB fallback
// ─────────────────────────────────────────────
const getDeals = tool(
  async ({ category, needs_only }) => {
    try {
      const { cacheGet } = require('./cacheService');
      let deals = await cacheGet('deals');

      if (!deals || !Array.isArray(deals) || deals.length === 0) {
        try {
          const { connectMongo } = require('../config/mongodb');
          const Deal = require('../models/Deal');
          await connectMongo();
          deals = await Deal.find().sort({ scraped_at: -1 }).limit(30).lean();
        } catch { /* MongoDB unavailable */ }
      }

      if (!deals || deals.length === 0) return 'No deals data available';

      let filtered = deals;
      if (category) filtered = filtered.filter(d => d.category === category);
      if (needs_only) filtered = filtered.filter(d => d.is_need === true);

      return JSON.stringify(filtered.slice(0, 10).map(d => ({
        merchant: d.merchant,
        deal: d.deal_title,
        category: d.category,
        discount: d.discount_pct,
        cashback: d.max_cashback,
        is_need: d.is_need,
        note: d.aion_note,
      })));
    } catch (err) {
      return `Could not fetch deals: ${err.message}`;
    }
  },
  {
    name: 'get_deals',
    description: 'Get current merchant deals and cashback offers in Malaysia. Use when user asks about deals, discounts, or saving money on purchases. Can filter by category and needs vs wants.',
    schema: z.object({
      category: z.string().optional().describe('Filter by category: food, transport, shopping, entertainment, health, education, utilities'),
      needs_only: z.boolean().optional().default(false).describe('Only show necessity deals (not wants)'),
    }),
  }
);

// ─────────────────────────────────────────────
// TOOL: search_past_conversations (RAG)
// Multi-query → embed → cosine search → RRF merge
// Aion calls this to recall past discussions.
// ─────────────────────────────────────────────
const searchPastConversations = tool(
  async ({ query }, config) => {
    try {
      const userId = config.configurable?.userId;
      if (!userId) return 'Error: no user context';

      const { generateQueryVariations, embedBatch, reciprocalRankFusion } = require('./embeddingService');

      // Step 1: Multi-query — generate 2 variations + original
      const queries = await generateQueryVariations(query);

      // Step 2: Embed all query variations
      const vectors = await embedBatch(queries);
      const validVectors = vectors.filter(Boolean);
      if (validVectors.length === 0) return 'Could not generate embeddings for search';

      // Step 3: Search with each vector
      const allResults = [];
      for (const vec of validVectors) {
        const { data } = await supabase.rpc('match_session_embeddings', {
          query_embedding: JSON.stringify(vec),
          match_user_id: userId,
          match_threshold: 0.72,
          match_count: 3,
        });
        if (data?.length > 0) allResults.push(data);
      }

      if (allResults.length === 0) return 'No relevant past conversations found';

      // Step 4: RRF — merge and rank results from all queries
      const ranked = reciprocalRankFusion(allResults);
      const top = ranked.slice(0, 3);

      return JSON.stringify(top.map(r => ({
        summary: r.session_summary,
        relevance: Math.round((r.rrf_score || r.similarity) * 100) / 100,
        date: formatDateMYT(r.created_at),
      })));
    } catch (err) {
      return `Could not search past conversations: ${err.message}`;
    }
  },
  {
    name: 'search_past_conversations',
    description: 'Search through past conversation sessions with the user using semantic similarity. Use when the user references something discussed before, asks "remember when...", or when you need historical context about their financial decisions, goals, or past advice given.',
    schema: z.object({
      query: z.string().describe('What to search for in past conversations, e.g. "Japan trip savings goal" or "spending on food last month"'),
    }),
  }
);

// ─────────────────────────────────────────────
// TOOL: update_debt_payment
// Updates a debt's monthly payment after Aion
// and the user agree on a payment plan.
// ─────────────────────────────────────────────
const updateDebtPayment = tool(
  async ({ debt_name, new_monthly_payment }, config) => {
    try {
      const userId = config.configurable?.userId;
      if (!userId) return 'Error: no user context';

      const { data: debts } = await supabase
        .from('debts')
        .select('id, name, current_monthly_payment, minimum_payment')
        .eq('user_id', userId)
        .eq('is_active', true);

      const match = (debts || []).find(
        (d) => d.name.toLowerCase().includes(debt_name.toLowerCase())
      );
      if (!match) return `No debt found matching "${debt_name}". Available: ${(debts || []).map(d => d.name).join(', ')}`;

      if (match.debt_type !== 'credit_card') {
        return `${match.name} is a fixed loan — the monthly payment of RM ${parseFloat(match.current_monthly_payment || 0).toFixed(2)} is set by the bank and cannot be changed. Only credit card payments can be adjusted.`;
      }

      const minPay = parseFloat(match.minimum_payment || 0);
      if (new_monthly_payment < minPay) {
        return `Cannot set payment below minimum of RM ${minPay.toFixed(2)}`;
      }

      // Calculate new remaining months
      const { data: fullDebt } = await supabase
        .from('debts')
        .select('current_balance, interest_rate')
        .eq('id', match.id)
        .single();

      let newRemainingMonths = null;
      if (fullDebt) {
        const balance = parseFloat(fullDebt.current_balance);
        const rate = parseFloat(fullDebt.interest_rate || 0);
        if (rate > 0) {
          const r = rate / 100 / 12;
          const monthlyInterest = balance * r;
          if (new_monthly_payment > monthlyInterest) {
            const n = Math.log(new_monthly_payment / (new_monthly_payment - monthlyInterest)) / Math.log(1 + r);
            newRemainingMonths = Math.ceil(n);
          }
        } else if (new_monthly_payment > 0) {
          newRemainingMonths = Math.ceil(balance / new_monthly_payment);
        }
      }

      await supabase
        .from('debts')
        .update({
          current_monthly_payment: new_monthly_payment,
          remaining_months: newRemainingMonths,
        })
        .eq('id', match.id);

      return JSON.stringify({
        updated: match.name,
        old_payment: parseFloat(match.current_monthly_payment || 0),
        new_payment: new_monthly_payment,
        remaining_months: newRemainingMonths,
      });
    } catch (err) {
      return `Could not update debt payment: ${err.message}`;
    }
  },
  {
    name: 'update_debt_payment',
    description: 'Update the monthly payment amount for a CREDIT CARD debt only. Fixed loans (car, home, personal, student, BNPL) have bank-set payments that cannot be changed. Use only when the user agrees to pay more than the minimum on their credit card.',
    schema: z.object({
      debt_name: z.string().describe('Name or partial name of the debt to update'),
      new_monthly_payment: z.number().describe('The new agreed monthly payment in RM'),
    }),
  }
);

// ─────────────────────────────────────────────
// TOOL: get_user_bills
// Returns all active recurring bills
// ─────────────────────────────────────────────
const getUserBills = tool(
  async (_, config) => {
    try {
      const userId = config.configurable?.userId;
      if (!userId) return 'Error: no user context';

      const { data: bills } = await supabase
        .from('bills')
        .select('name, amount, due_date, frequency, category, is_paid, vault_id')
        .eq('user_id', userId)
        .eq('is_active', true)
        .order('due_date', { ascending: true });

      if (!bills?.length) return 'No active bills';

      const { formatDateMYT } = require('../utils/dateUtils');
      const now = new Date();

      const totalMonthly = bills.reduce((s, b) => {
        const amt = parseFloat(b.amount || 0);
        switch (b.frequency) {
          case 'quarterly': return s + amt / 3;
          case 'annually': return s + amt / 12;
          default: return s + amt;
        }
      }, 0);

      return JSON.stringify({
        summary: {
          total_bills: bills.length,
          total_monthly: Math.round(totalMonthly * 100) / 100,
          unpaid: bills.filter(b => !b.is_paid).length,
        },
        bills: bills.map(b => {
          const dueDate = new Date(b.due_date);
          const daysUntilDue = Math.ceil((dueDate.getTime() - now.getTime()) / 86400000);
          return {
            name: b.name,
            amount: parseFloat(b.amount),
            due_date: formatDateMYT(b.due_date),
            days_until_due: daysUntilDue,
            frequency: b.frequency,
            category: b.category,
            is_paid: b.is_paid,
            overdue: daysUntilDue < 0 && !b.is_paid,
          };
        }),
      });
    } catch (err) {
      return `Could not fetch bills: ${err.message}`;
    }
  },
  {
    name: 'get_user_bills',
    description: 'Get all active recurring bills — utilities, subscriptions, insurance, phone. Shows due dates, amounts, paid status, and days until due. Use when user asks about bills, upcoming payments, or when you need to factor recurring costs into budget advice.',
    schema: z.object({}),
  }
);

// ─────────────────────────────────────────────
// TOOL: get_investment_portfolio
// Returns holdings + risk score + allocation
// ─────────────────────────────────────────────
const getInvestmentPortfolio = tool(
  async (_, config) => {
    try {
      const userId = config.configurable?.userId;
      if (!userId) return 'Error: no user context';

      const { data: investments } = await supabase
        .from('investments')
        .select('asset_name, category, units, purchase_price, current_price')
        .eq('user_id', userId)
        .eq('is_active', true);

      if (!investments?.length) return 'No investment holdings';

      // Get USD→MYR rate: Redis → MongoDB
      const { cacheGet: cg } = require('./cacheService');
      let usdToMyr = null;
      const fxCached = await cg('market:MYRUSD');
      if (fxCached?.price) {
        usdToMyr = 1 / fxCached.price;
      } else {
        try {
          const { connectMongo: cm } = require('../config/mongodb');
          const MDC = require('../models/MarketDataCache');
          await cm();
          const doc = await MDC.findOne({ symbol: 'MYRUSD' }).lean();
          if (doc?.price) usdToMyr = 1 / doc.price;
        } catch (_) {}
      }

      const totalValue = investments.reduce((s, i) =>
        s + parseFloat(i.units) * parseFloat(i.current_price || i.purchase_price), 0);

      const holdings = investments.map(i => {
        const value = parseFloat(i.units) * parseFloat(i.current_price || i.purchase_price);
        const cost = parseFloat(i.units) * parseFloat(i.purchase_price);
        return {
          name: i.asset_name,
          category: i.category,
          value_usd: Math.round(value * 100) / 100,
          value_rm: usdToMyr ? Math.round(value * usdToMyr * 100) / 100 : null,
          weight: totalValue > 0 ? Math.round(value / totalValue * 100) : 0,
          pnl_usd: Math.round((value - cost) * 100) / 100,
          pnl_rm: usdToMyr ? Math.round((value - cost) * usdToMyr * 100) / 100 : null,
          pnl_pct: cost > 0 ? Math.round((value - cost) / cost * 10000) / 100 : 0,
        };
      });

      const allocation = {};
      holdings.forEach(h => {
        allocation[h.category] = (allocation[h.category] || 0) + h.weight;
      });

      return JSON.stringify({
        note: 'Investment values in USD. RM equivalents provided for comparison with user income/debts (in RM). Use USD primary with (RM xxx) when discussing.',
        total_value_usd: Math.round(totalValue * 100) / 100,
        total_value_rm: usdToMyr ? Math.round(totalValue * usdToMyr * 100) / 100 : null,
        allocation,
        holdings,
      });
    } catch (err) {
      return `Could not fetch investment portfolio: ${err.message}`;
    }
  },
  {
    name: 'get_investment_portfolio',
    description: 'Get user investment holdings — stocks, crypto, ETFs. Shows total value in USD and RM, allocation percentages, P&L per holding. Use when user asks about investments, portfolio, or when comparing with their RM-denominated finances.',
    schema: z.object({}),
  }
);

// ─────────────────────────────────────────────
// TOOL: get_health_score
// ─────────────────────────────────────────────
const getHealthScore = tool(
  async ({ user_id }) => {
    try {
      const { calculateHealthScore } = require('./healthScoreService');
      const result = await calculateHealthScore(user_id);
      return JSON.stringify({
        score: result.score,
        tier: result.tier,
        dimensions: {
          spend: result.dimensions.spend.score,
          save: result.dimensions.save.score,
          borrow: result.dimensions.borrow.score,
          plan: result.dimensions.plan.score,
        },
        weakest: Object.entries(result.dimensions)
          .sort((a, b) => a[1].score - b[1].score)[0],
      });
    } catch (err) {
      return `Health score unavailable: ${err.message}`;
    }
  },
  {
    name: 'get_health_score',
    description: 'Get user\'s Financial Health Score (FHN methodology, 0-100) with 4 dimension breakdown: Spend, Save, Borrow, Plan. Use to assess overall financial wellness.',
    schema: z.object({
      user_id: z.string().describe('The user UUID'),
    }),
  }
);

const aionTools = [
  getVaultTransactions,
  getRecentTransactions,
  getSpendingVelocity,
  getUserDebts,
  getDebtStrategy,
  getUserBills,
  getInvestmentPortfolio,
  getMarketData,
  getNews,
  getFDRates,
  getDeals,
  calculateLoan,
  calculateGoalTimeline,
  searchPastConversations,
  updateDebtPayment,
  getHealthScore,
];

module.exports = { aionTools };
