// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : newsService.js
// Description   : Fetches financial news from NewsAPI and summarises
//                 each article with Gemini into 2 plain-language sentences.
//                 Writes to MongoDB and Redis (2-hour TTL).
// First Written : 17-06-2026
// Edited on     : 17-06-2026
// ============================================

const axios = require('axios');
const mongoose = require('mongoose');
const { connectMongo } = require('../config/mongodb');
const { cacheSet } = require('./cacheService');
const { safeGeminiCall, buildNewsSummaryPrompt } = require('./geminiService');
const NewsArticle = require('../models/NewsArticle');

const NEWS_TTL = 2 * 60 * 60; // 2 hours

async function fetchAndSummariseNews() {
  const { cacheGet } = require('./cacheService');
  const cached = await cacheGet('news');
  if (cached && cached.length > 0) { console.log('[News] Cache hit — skipping fetch'); return cached; }

  const url = `https://newsapi.org/v2/everything?q=(finance OR economy OR stocks OR investment OR banking OR "interest rate" OR inflation OR cryptocurrency)&language=en&sortBy=publishedAt&pageSize=50&apiKey=${process.env.NEWS_API_KEY}`;

  const { data } = await axios.get(url, { timeout: 15000 });
  if (data.status !== 'ok') return;

  const articles = [];
  let mongoReady = false;
  try {
    await connectMongo();
    mongoReady = mongoose.connection.readyState === 1;
  } catch {
    // non-fatal — news still cached to Redis without MongoDB
  }
  if (!mongoReady) console.warn('[News] MongoDB unavailable — skipping persistence');

  for (const article of data.articles) {
    if (!article.url || !article.title) continue;

    // Skip if already stored (only when MongoDB is available)
    if (mongoReady) {
      const exists = await NewsArticle.findOne({ url: article.url });
      if (exists) { articles.push(exists); continue; }
    }

    // Summarise with Gemini (delay to avoid rate limiting)
    await new Promise(r => setTimeout(r, 1500));
    const prompt = buildNewsSummaryPrompt(article);
    const result = await safeGeminiCall(prompt);

    const summary     = result.success ? result.data.summary     : article.description || '';
    const sentiment   = result.success ? result.data.sentiment   : 'neutral';
    const tags        = result.success ? (result.data.tags || []) : [];
    const isBreaking  = result.success ? (result.data.is_breaking || false) : false;

    const doc = {
      title:        article.title,
      summary,
      sentiment,
      source:       article.source?.name || 'Unknown',
      published_at: article.publishedAt ? new Date(article.publishedAt) : new Date(),
      url:          article.url,
      image_url:    article.urlToImage || null,
      tags,
      is_breaking:  isBreaking,
    };

    if (mongoReady) {
      try { await NewsArticle.create(doc); } catch { /* duplicate url — skip */ }
    }

    articles.push(doc);
  }

  // Cache top 10 most recent for Aion context injection
  articles.sort((a, b) => new Date(b.published_at) - new Date(a.published_at));
  const top10 = articles.slice(0, 10).map((a) => ({
    title:     a.title,
    summary:   a.summary,
    sentiment: a.sentiment,
    source:    a.source,
    url:        a.url,
    image_url:  a.image_url || null,
    is_breaking: a.is_breaking || false,
    published_at: a.published_at,
  }));

  await cacheSet('news', top10, NEWS_TTL);
  console.log(`[News] ${articles.length} articles processed`);
  return top10;
}

module.exports = { fetchAndSummariseNews };
