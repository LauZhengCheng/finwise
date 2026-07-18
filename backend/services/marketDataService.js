// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : marketDataService.js
// Description   : Fetches live market data from Alpha Vantage (stocks),
//                 CoinGecko (crypto), and ExchangeRate-API (FX).
//                 Writes results to Redis (15-min TTL) and MongoDB Atlas.
// First Written : 17-06-2026
// Edited on     : 17-06-2026
// ============================================

const axios = require('axios');
const { connectMongo } = require('../config/mongodb');
const { cacheGet, cacheSet } = require('./cacheService');
const MarketDataCache = require('../models/MarketDataCache');

const STOCK_TTL  = 24 * 60 * 60; // 24 hours
const CRYPTO_TTL = 60;            // 1 minute
const FX_TTL     = 6 * 60 * 60;  // 6 hours
const VOLATILITY_STOCK_TTL  = 24 * 60 * 60; // 24 hours
const VOLATILITY_CRYPTO_TTL = 6 * 60 * 60;  // 6 hours

// ── Crypto (CoinGecko) ───────────────────────────────────────────────
// Fetches top 100 crypto by market cap. Stores:
//   crypto:market_list → full list (for holdings page)
//   market:BTCUSD etc. → individual coins (for Aion analysis + LangGraph)
async function fetchCrypto() {
  try {
  const cached = await cacheGet('crypto:market_list');
  if (cached) { console.log('[MarketData] Crypto cache hit — skipping'); return; }

  const url = 'https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=100&page=1&price_change_percentage=24h';

  const { data } = await axios.get(url, {
    headers: { 'x-cg-demo-api-key': process.env.COINGECKO_API_KEY },
    timeout: 15000,
  });

  const symbolMap = { bitcoin: 'BTCUSD', ethereum: 'ETHUSD', binancecoin: 'BNBUSD' };

  // Store full list for holdings page
  const coinList = data.map(c => ({
    id: c.id,
    ticker: c.symbol.toUpperCase(),
    name: c.name,
    price: c.current_price,
    change_24h: c.price_change_percentage_24h,
  }));
  await cacheSet('crypto:market_list', coinList, CRYPTO_TTL);

  // Store individual Redis keys for Aion analysis + LangGraph + MongoDB backup
  for (const coin of data) {
    const symbol = symbolMap[coin.id] || `${coin.symbol.toUpperCase()}USD`;
    const record = {
      symbol,
      type:           'crypto',
      price:          coin.current_price,
      change_pct_24h: coin.price_change_percentage_24h,
      high_24h:       coin.high_24h,
      low_24h:        coin.low_24h,
      volume:         coin.total_volume,
      updated_at:     new Date(),
    };

    // Redis: only key coins for Aion (BTC, ETH, BNB)
    if (symbolMap[coin.id]) {
      await cacheSet(`market:${symbol}`, record, CRYPTO_TTL);
    }

    // MongoDB: top 20 for fallback
    if (data.indexOf(coin) < 20) {
      connectMongo()
        .then(() => MarketDataCache.findOneAndUpdate({ symbol }, record, { upsert: true, returnDocument: 'after' }))
        .catch(() => {});
    }
  }

  console.log(`[MarketData] Crypto updated — ${coinList.length} coins cached`);
  } catch (err) {
    console.error('[MarketData] fetchCrypto failed:', err.message);
  }
}

// ── Stocks (Alpha Vantage) ────────────────────────────────────────────
async function fetchStock(symbol) {
  const cached = await cacheGet(`market:${symbol}`);
  if (cached) { console.log(`[MarketData] Stock ${symbol} cache hit — skipping`); return; }

  // MongoDB fallback before calling Alpha (saves API calls when Redis is down)
  try {
    await connectMongo();
    const doc = await MarketDataCache.findOne({ symbol }).lean();
    if (doc && doc.updated_at && (Date.now() - new Date(doc.updated_at).getTime()) < STOCK_TTL * 1000) {
      console.log(`[MarketData] Stock ${symbol} MongoDB hit — skipping Alpha call`);
      await cacheSet(`market:${symbol}`, doc, STOCK_TTL);
      return;
    }
  } catch (_) {}

  // Tier 3: Call Alpha Vantage
  try {
    const url = `https://www.alphavantage.co/query?function=GLOBAL_QUOTE&symbol=${symbol}&apikey=${process.env.ALPHA_VANTAGE_API_KEY}`;
    const { data } = await axios.get(url, { timeout: 10000 });
    const quote = data['Global Quote'];
    if (quote && quote['05. price']) {
      const record = {
        symbol,
        type:           'stock',
        price:          parseFloat(quote['05. price']),
        change_pct_24h: parseFloat(quote['10. change percent'].replace('%', '')),
        high_24h:       parseFloat(quote['03. high']),
        low_24h:        parseFloat(quote['04. low']),
        volume:         parseFloat(quote['06. volume']),
        updated_at:     new Date(),
      };
      await cacheSet(`market:${symbol}`, record, STOCK_TTL);
      connectMongo()
        .then(() => MarketDataCache.findOneAndUpdate({ symbol }, record, { upsert: true, returnDocument: 'after' }))
        .catch(() => {});
      console.log(`[MarketData] Stock ${symbol} updated`);
      return;
    }
  } catch (err) {
    console.error(`[MarketData] Stock ${symbol} API failed:`, err.message);
  }

  // Tier 4: MongoDB stale (last resort)
  try {
    await connectMongo();
    const staleDoc = await MarketDataCache.findOne({ symbol }).lean();
    if (staleDoc) {
      console.log(`[MarketData] Stock ${symbol} using stale MongoDB data`);
      await cacheSet(`market:${symbol}`, staleDoc, STOCK_TTL);
    }
  } catch (_) {}
}

// ── FX Rates (ExchangeRate-API) ───────────────────────────────────────
async function fetchFX() {
  try {
  const cached = await cacheGet('market:MYRUSD');
  if (cached) { console.log('[MarketData] FX cache hit — skipping'); return; }

  const url = `https://v6.exchangerate-api.com/v6/${process.env.EXCHANGERATE_API_KEY}/latest/MYR`;

  const { data } = await axios.get(url, { timeout: 10000 });
  if (data.result !== 'success') return;

  const allRates = data.conversion_rates || {};
  const NEEDED_CURRENCIES = [
    'USD', 'SGD', 'JPY', 'GBP', 'EUR', 'AUD', 'CNY', 'THB', 'KRW', 'IDR',
    'HKD', 'TWD', 'INR', 'PHP', 'VND', 'CAD', 'CHF', 'NZD', 'SAR', 'AED',
  ];
  let count = 0;

  for (const [currency, rate] of Object.entries(allRates)) {
    if (!NEEDED_CURRENCIES.includes(currency) || !rate) continue;

    const symbol = `MYR${currency}`;
    const record = { symbol, type: 'fx', price: rate, updated_at: new Date() };

    await cacheSet(`market:${symbol}`, record, FX_TTL);
    connectMongo()
      .then(() => MarketDataCache.findOneAndUpdate({ symbol }, record, { upsert: true, returnDocument: 'after' }))
      .catch(() => {});
    count++;
  }

  console.log(`[MarketData] FX rates updated — ${count} pairs`);
  } catch (err) {
    console.error('[MarketData] fetchFX failed:', err.message);
  }
}

// ── Historical Volatility (for investment risk score) ─────────────────
const CRYPTO_ID_MAP = {
  BTC: 'bitcoin', ETH: 'ethereum', BNB: 'binancecoin', SOL: 'solana',
  XRP: 'ripple', ADA: 'cardano', DOGE: 'dogecoin', DOT: 'polkadot',
  MATIC: 'matic-network', AVAX: 'avalanche-2', LINK: 'chainlink',
};

const CATEGORY_VOLATILITY_FALLBACK = {
  crypto: 65, stocks: 20, etf: 15, unit_trust: 10, bonds: 5, property: 12, other: 15,
};

function _calcAnnualisedVolatility(prices, tradingDays) {
  if (prices.length < 10) return null;
  const returns = [];
  for (let i = 1; i < prices.length; i++) {
    if (prices[i - 1] > 0) returns.push((prices[i] - prices[i - 1]) / prices[i - 1]);
  }
  if (returns.length < 5) return null;
  const mean = returns.reduce((s, r) => s + r, 0) / returns.length;
  const variance = returns.reduce((s, r) => s + (r - mean) ** 2, 0) / (returns.length - 1);
  return Math.sqrt(variance) * Math.sqrt(tradingDays) * 100;
}

async function fetchHistoricalVolatility(ticker, category) {
  if (!ticker || ['unit_trust', 'bonds', 'property', 'other'].includes(category)) {
    return CATEGORY_VOLATILITY_FALLBACK[category] || 15;
  }

  const upperTicker = ticker.toUpperCase();
  const cacheKey = `volatility:${upperTicker}`;
  const ttl = category === 'crypto' ? VOLATILITY_CRYPTO_TTL : VOLATILITY_STOCK_TTL;
  const VolatilityCache = require('../models/VolatilityCache');

  // Tier 1: Redis
  const cached = await cacheGet(cacheKey);
  if (cached) return cached.volatility;

  // Tier 2: MongoDB fresh (within TTL)
  try {
    await connectMongo();
    const mongoDoc = await VolatilityCache.findOne({ ticker: upperTicker }).lean();
    if (mongoDoc && mongoDoc.updated_at && (Date.now() - new Date(mongoDoc.updated_at).getTime()) < ttl * 1000) {
      console.log(`[Volatility] ${ticker} MongoDB hit (fresh) — skipping API`);
      await cacheSet(cacheKey, { volatility: mongoDoc.volatility }, ttl);
      return mongoDoc.volatility;
    }
  } catch (_) {}

  // Tier 3: Call API → write to Redis + MongoDB
  try {
    let vol = null;
    if (category === 'crypto') {
      const coinId = CRYPTO_ID_MAP[upperTicker];
      if (!coinId) return CATEGORY_VOLATILITY_FALLBACK.crypto;

      const url = `https://api.coingecko.com/api/v3/coins/${coinId}/market_chart?vs_currency=usd&days=90`;
      const { data } = await axios.get(url, {
        headers: { 'x-cg-demo-api-key': process.env.COINGECKO_API_KEY },
        timeout: 10000,
      });
      const prices = (data.prices || []).map(p => p[1]);
      vol = _calcAnnualisedVolatility(prices, 365);
    } else {
      const url = `https://www.alphavantage.co/query?function=TIME_SERIES_DAILY&symbol=${ticker}&outputsize=compact&apikey=${process.env.ALPHA_VANTAGE_API_KEY}`;
      const { data } = await axios.get(url, { timeout: 10000 });
      const series = data['Time Series (Daily)'];
      if (!series) return CATEGORY_VOLATILITY_FALLBACK[category] || 15;

      const sortedDates = Object.keys(series).sort();
      const prices = sortedDates.map(d => parseFloat(series[d]['4. close']));
      vol = _calcAnnualisedVolatility(prices, 252);

      // Also store latest price — saves a separate GLOBAL_QUOTE call
      if (sortedDates.length > 0) {
        const latestDate = sortedDates[sortedDates.length - 1];
        const latestClose = parseFloat(series[latestDate]['4. close']);
        const prevDate = sortedDates.length > 1 ? sortedDates[sortedDates.length - 2] : null;
        const prevClose = prevDate ? parseFloat(series[prevDate]['4. close']) : latestClose;
        const changePct = prevClose > 0 ? ((latestClose - prevClose) / prevClose) * 100 : 0;
        await cacheSet(`market:${upperTicker}`, { price: latestClose, change_pct_24h: Math.round(changePct * 100) / 100 }, STOCK_TTL);
        connectMongo().then(() =>
          MarketDataCache.findOneAndUpdate({ symbol: upperTicker }, {
            symbol: upperTicker, type: 'stock', price: latestClose, change_pct_24h: Math.round(changePct * 100) / 100, updated_at: new Date(),
          }, { upsert: true })
        ).catch(() => {});
      }
    }

    if (vol != null) {
      const rounded = Math.round(vol * 100) / 100;
      await cacheSet(cacheKey, { volatility: rounded }, ttl);
      connectMongo().then(() =>
        VolatilityCache.findOneAndUpdate({ ticker: upperTicker }, {
          ticker: upperTicker, category, volatility: rounded, updated_at: new Date(),
        }, { upsert: true })
      ).catch(() => {});
      console.log(`[Volatility] ${ticker} (${category}): ${vol.toFixed(1)}%`);
      return rounded;
    }
  } catch (err) {
    console.error(`[Volatility] ${ticker} API failed:`, err.message);
  }

  // Tier 4: MongoDB stale (any data, last resort)
  try {
    await connectMongo();
    const staleDoc = await VolatilityCache.findOne({ ticker: upperTicker }).lean();
    if (staleDoc) {
      console.log(`[Volatility] ${ticker} MongoDB stale fallback — ${staleDoc.volatility}%`);
      return staleDoc.volatility;
    }
  } catch (_) {}

  return CATEGORY_VOLATILITY_FALLBACK[category] || 15;
}

// ── Refresh all ───────────────────────────────────────────────────────
async function refreshAllMarketData() {
  await Promise.allSettled([
    fetchCrypto(),
    fetchStock('SPY'),   // S&P 500 ETF as proxy
    fetchStock('QQQ'),   // NASDAQ ETF
    fetchFX(),
  ]);
}

// ── Finnhub Stock Quotes (for ticker row) ────────────────────────────
const FINNHUB_TTL = 5 * 60; // 5 minutes

async function fetchTickerQuotes(symbols) {
  if (!symbols || symbols.length === 0) return [];

  // Tier 1: Redis
  const cacheKey = `ticker:stocks:${[...symbols].sort().join(',')}`;
  const cached = await cacheGet(cacheKey);
  if (cached) return cached;

  // Tier 2: MongoDB fresh (within TTL)
  try {
    await connectMongo();
    const freshDoc = await MarketDataCache.findOne({ type: 'stock', symbol: { $in: symbols } })
      .sort({ updated_at: -1 }).lean();
    if (freshDoc?.updated_at && (Date.now() - new Date(freshDoc.updated_at).getTime()) < FINNHUB_TTL * 1000) {
      const docs = await MarketDataCache.find({ type: 'stock', symbol: { $in: symbols } }).lean();
      const result = docs.map(d => ({ symbol: d.symbol, price: d.price, change_pct: d.change_pct_24h }));
      console.log(`[Ticker] ${result.length} stocks from MongoDB fresh — skipping Finnhub`);
      await cacheSet(cacheKey, result, FINNHUB_TTL);
      return result;
    }
  } catch (_) {}

  // Tier 3: Finnhub API → write to Redis + MongoDB
  const apiKey = process.env.FINNHUB_API_KEY;
  if (apiKey) {
    try {
      const results = await Promise.allSettled(symbols.map(async symbol => {
        const url = `https://finnhub.io/api/v1/quote?symbol=${symbol}&token=${apiKey}`;
        const { data } = await axios.get(url, { timeout: 5000 });
        if (data?.c) return { symbol, price: data.c, change: data.d, change_pct: data.dp };
        return null;
      }));
      const quotes = results
        .filter(r => r.status === 'fulfilled' && r.value)
        .map(r => r.value);
      if (quotes.length > 0) {
        await cacheSet(cacheKey, quotes, FINNHUB_TTL);
        connectMongo().then(() => {
          for (const q of quotes) {
            MarketDataCache.findOneAndUpdate({ symbol: q.symbol }, {
              symbol: q.symbol, type: 'stock', price: q.price,
              change_pct_24h: q.change_pct, updated_at: new Date(),
            }, { upsert: true }).catch(() => {});
          }
        }).catch(() => {});
        console.log(`[Ticker] ${quotes.length} stock quotes from Finnhub`);
        return quotes;
      }
    } catch (err) {
      console.error('[Ticker] Finnhub API error:', err.message);
    }
  }

  // Tier 4: MongoDB stale (any data)
  try {
    await connectMongo();
    const docs = await MarketDataCache.find({ type: 'stock', symbol: { $in: symbols } }).lean();
    if (docs.length > 0) {
      console.log(`[Ticker] ${docs.length} stocks from MongoDB stale fallback`);
      return docs.map(d => ({ symbol: d.symbol, price: d.price, change_pct: d.change_pct_24h }));
    }
  } catch (_) {}

  return [];
}

module.exports = { refreshAllMarketData, fetchCrypto, fetchStock, fetchFX, fetchHistoricalVolatility, fetchTickerQuotes };
