// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : scrapeService.js
// Description   : Jina AI Reader scraping + Gemini extraction
//                 for FD rates and merchant deals.
//                 Flow: Jina scrapes URL → raw markdown → Gemini extracts
//                 structured JSON → MongoDB stores → Redis caches.
// First Written : 20-06-2026
// Edited on     : 20-06-2026
// ============================================

const axios = require('axios');
const mongoose = require('mongoose');
const { connectMongo } = require('../config/mongodb');
const { cacheSet } = require('./cacheService');
const { safeGeminiCall, buildFDExtractionPrompt, buildDealExtractionPrompt } = require('./geminiService');
const FDRate = require('../models/FDRate');
const Deal = require('../models/Deal');

const FD_TTL   = 6 * 60 * 60; // 6 hours
const DEAL_TTL = 6 * 60 * 60; // 6 hours

// ─────────────────────────────────────────────
// JINA AI READER
// Fetches a URL as clean markdown via r.jina.ai
// ─────────────────────────────────────────────
async function jinaFetch(targetUrl, waitForSelector) {
  const headers = { 'Accept': 'text/markdown' };
  if (waitForSelector) headers['X-Wait-For-Selector'] = waitForSelector;
  const response = await axios.get(`https://r.jina.ai/${targetUrl}`, {
    headers,
    timeout: 45000,
  });
  return response.data;
}

// ─────────────────────────────────────────────
// SCRAPE FD RATES
// Jina → raw markdown → Gemini extracts → MongoDB + Redis
// ─────────────────────────────────────────────
async function scrapeFDRates() {
  try {
  const sourceUrl = 'https://www.imoney.my/fixed-deposit';
  console.log('[FD Scraper] Fetching from Jina...');

  const rawMarkdown = await jinaFetch(sourceUrl);
  if (!rawMarkdown || rawMarkdown.length < 100) {
    console.warn('[FD Scraper] Jina returned insufficient content');
    return [];
  }

  console.log(`[FD Scraper] Got ${rawMarkdown.length} chars, extracting with Gemini...`);
  const result = await safeGeminiCall(buildFDExtractionPrompt(rawMarkdown));

  if (!result.success) {
    console.error('[FD Scraper] Gemini extraction failed');
    return [];
  }

  // Handle both array and {rates: [...]} response formats
  let rates = result.data;
  if (!Array.isArray(rates)) {
    rates = rates?.rates || rates?.fd_rates || rates?.results || [];
  }
  if (!Array.isArray(rates) || rates.length === 0) {
    console.warn('[FD Scraper] No rates extracted:', JSON.stringify(result.data).substring(0, 200));
    return [];
  }
  console.log(`[FD Scraper] Extracted ${rates.length} FD products`);

  // Extract bank logo images from the raw markdown
  const logoMap = {};
  const imgRegex = /\[([^\]]*)\]\((https?:\/\/www\.imoney\.my\/img\/[^\)]+)\)/gi;
  let match;
  while ((match = imgRegex.exec(rawMarkdown)) !== null) {
    const text = match[1].toLowerCase();
    const url = match[2];
    for (const r of rates) {
      if (!r.bank) continue;
      const bankLower = r.bank.toLowerCase();
      // Full name match first, then first word (skip generic words like "bank", "standard")
      const genericWords = ['bank', 'standard', 'public', 'hong'];
      const firstWord = bankLower.split(' ')[0];
      const useFirstWord = !genericWords.includes(firstWord);
      if (text.includes(bankLower) || (useFirstWord && text.includes(firstWord))) {
        if (!logoMap[bankLower]) logoMap[bankLower] = url;
      }
    }
  }

  let mongoReady = false;
  try {
    await connectMongo();
    mongoReady = mongoose.connection.readyState === 1;
  } catch { /* non-fatal */ }

  const cleaned = [];
  for (const r of rates) {
    if (!r.bank || !r.interest_rate) continue;
    const doc = {
      bank: r.bank,
      product: r.product || `${r.bank} Fixed Deposit`,
      min_amount: r.min_amount || null,
      tenure_months: r.tenure_months || null,
      interest_rate: r.interest_rate,
      apply_url: r.apply_url || sourceUrl,
      logo_url: logoMap[r.bank.toLowerCase()] || null,
      source_url: sourceUrl,
      is_islamic: r.is_islamic || false,
      scraped_at: new Date(),
    };

    if (mongoReady) {
      try {
        await FDRate.findOneAndUpdate(
          { bank: doc.bank, product: doc.product, tenure_months: doc.tenure_months },
          doc,
          { upsert: true }
        );
      } catch { /* duplicate — skip */ }
    }

    cleaned.push(doc);
  }

  await cacheSet('fd_rates', cleaned, FD_TTL);
  console.log(`[FD Scraper] ${cleaned.length} rates cached`);
  return cleaned;
  } catch (err) {
    console.error('[FD Scraper] scrapeFDRates failed:', err.message);
    return [];
  }
}

// ─────────────────────────────────────────────
// SCRAPE DEALS
// Jina → raw markdown → Gemini extracts → MongoDB + Redis
// ─────────────────────────────────────────────
async function scrapeDeals() {
  try {
  const sources = [
    // Layer 1: Bank official promotion pages
    'https://www.cimb.com.my/en/personal/promotions.html',
    'https://www.hsbc.com.my/credit-cards/offers/',
    'https://www.sc.com/my/promotions/',
    'https://www.hlb.com.my/en/personal-banking/promotions.html',
    'https://www.ambank.com.my/eng/promotions',
    'https://www.alliancebank.com.my/promotions.aspx',
    // Layer 2: Financial comparison platforms
    'https://www.imoney.my/personal-loan',
    'https://loanstreet.com.my/credit-card-promotions',
  ];

  console.log('[Deals Scraper] Fetching from Jina...');
  let allDeals = [];

  for (const sourceUrl of sources) {
    try {
      const rawMarkdown = await jinaFetch(sourceUrl);
      if (!rawMarkdown || rawMarkdown.length < 100) continue;

      console.log(`[Deals Scraper] Got ${rawMarkdown.length} chars from ${sourceUrl}`);
      const result = await safeGeminiCall(buildDealExtractionPrompt(rawMarkdown));

      if (!result.success) {
        console.error('[Deals Scraper] Gemini extraction failed');
        continue;
      }

      // Handle both array and {deals: [...]} response formats
      let extractedDeals = result.data;
      if (!Array.isArray(extractedDeals)) {
        extractedDeals = extractedDeals?.deals || extractedDeals?.results || [];
      }
      if (!Array.isArray(extractedDeals) || extractedDeals.length === 0) {
        console.warn('[Deals Scraper] No deals extracted from Gemini response:', JSON.stringify(result.data).substring(0, 200));
        continue;
      }

      const deals = extractedDeals.map(d => ({
        ...d,
        source: new URL(sourceUrl).hostname,
        source_url: sourceUrl,
        scraped_at: new Date(),
      }));
      allDeals.push(...deals);
    } catch (err) {
      console.error(`[Deals Scraper] Error scraping ${sourceUrl}:`, err.message);
    }
    // Rate-limit: 2s between sources to avoid hitting Jina/Gemini limits
    if (sources.indexOf(sourceUrl) < sources.length - 1) {
      await new Promise(r => setTimeout(r, 2000));
    }
  }

  let mongoReady = false;
  try {
    await connectMongo();
    mongoReady = mongoose.connection.readyState === 1;
  } catch { /* non-fatal */ }

  const cleaned = [];
  for (const d of allDeals) {
    if (!d.merchant || !d.deal_title) continue;
    const doc = {
      merchant: d.merchant,
      deal_title: d.deal_title,
      category: d.category || 'other',
      discount_pct: d.discount_pct || null,
      max_cashback: d.max_cashback || null,
      valid_until: d.valid_until ? new Date(d.valid_until) : null,
      is_need: d.is_need || false,
      is_want: d.is_want || false,
      aion_note: d.aion_note || null,
      apply_url: d.apply_url || null,
      source: d.source || 'unknown',
      source_url: d.source_url,
      scraped_at: new Date(),
    };
    if (!doc.source_url) {
      console.warn(`[Deals] Missing source_url for: ${doc.merchant} — ${doc.deal_title}`);
    }

    cleaned.push(doc);
  }

  if (mongoReady) {
    for (const doc of cleaned) {
      try {
        await Deal.findOneAndUpdate(
          { merchant: doc.merchant, deal_title: doc.deal_title },
          doc,
          { upsert: true }
        );
      } catch { /* duplicate — skip */ }
    }
  }

  await cacheSet('deals', cleaned, DEAL_TTL);
  console.log(`[Deals Scraper] ${cleaned.length} deals cached`);
  return cleaned;
  } catch (err) {
    console.error('[Deals Scraper] scrapeDeals failed:', err.message);
    return [];
  }
}

module.exports = { scrapeFDRates, scrapeDeals };
