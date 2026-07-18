// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : embeddingService.js
// Description   : Embedding service for RAG — generates vector embeddings
//                 using Vertex AI text-embedding-004 (ADC auth).
//                 Used for session summaries and query embedding.
//                 Multi-query support: generates query variations for
//                 better retrieval recall.
// First Written : 20-06-2026
// Edited on     : 20-06-2026
// ============================================

const { ai } = require('../config/gemini');

const EMBEDDING_MODEL = 'text-embedding-004';

// ─────────────────────────────────────────────
// EMBED TEXT
// Converts a text string into a 768-dimension vector.
// Used for both session summaries and search queries.
// ─────────────────────────────────────────────
async function embedText(text) {
  try {
    const response = await ai.models.embedContent({
      model: EMBEDDING_MODEL,
      contents: text,
    });
    return response.embedding?.values || null;
  } catch (err) {
    console.error('[Embedding] Failed:', err.message);
    return null;
  }
}

// ─────────────────────────────────────────────
// EMBED MULTIPLE TEXTS
// Batch embed for multi-query RAG.
// Returns array of vectors (same order as input).
// ─────────────────────────────────────────────
async function embedBatch(texts) {
  const results = [];
  for (const text of texts) {
    const vec = await embedText(text);
    results.push(vec);
  }
  return results;
}

// ─────────────────────────────────────────────
// GENERATE MULTI-QUERY VARIATIONS
// Uses Gemini to generate 2 alternative phrasings of the
// user's query for better RAG recall.
// Returns [original, variation1, variation2]
// ─────────────────────────────────────────────
async function generateQueryVariations(originalQuery) {
  try {
    const { safeGeminiCall } = require('./geminiService');
    const prompt = `
You are a search query optimizer. Given a user's question about their financial history,
generate 2 alternative phrasings that might match how a financial advisor's session notes
would describe the same topic. Use different words but same meaning.

Original query: "${originalQuery}"

Return JSON only:
{
  "variations": ["alternative phrasing 1", "alternative phrasing 2"]
}`;

    const result = await safeGeminiCall(prompt);
    if (result.success && result.data?.variations) {
      return [originalQuery, ...result.data.variations.slice(0, 2)];
    }
    return [originalQuery];
  } catch {
    return [originalQuery];
  }
}

// ─────────────────────────────────────────────
// RRF — RECIPROCAL RANK FUSION
// Merges results from multiple queries into one
// ranked list. Deduplicates by ID.
// k=60 is the standard RRF constant.
// ─────────────────────────────────────────────
function reciprocalRankFusion(resultSets, k = 60) {
  const scores = new Map();
  const docs = new Map();

  for (const results of resultSets) {
    results.forEach((doc, rank) => {
      const id = doc.id;
      const rrfScore = 1 / (k + rank + 1);
      scores.set(id, (scores.get(id) || 0) + rrfScore);
      if (!docs.has(id)) docs.set(id, doc);
    });
  }

  return [...scores.entries()]
    .sort((a, b) => b[1] - a[1])
    .map(([id, score]) => ({ ...docs.get(id), rrf_score: score }));
}

module.exports = {
  embedText,
  embedBatch,
  generateQueryVariations,
  reciprocalRankFusion,
};
