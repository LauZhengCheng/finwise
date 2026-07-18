// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : NewsArticle.js
// Description   : Mongoose schema for AI-summarised financial news articles.
// First Written : 17-06-2026
// Edited on     : 17-06-2026
// ============================================

const mongoose = require('mongoose');

const NewsArticleSchema = new mongoose.Schema({
  title:        { type: String, required: true },
  summary:      { type: String },
  sentiment:    { type: String, enum: ['positive', 'negative', 'neutral'], default: 'neutral' },
  source:       { type: String },
  published_at: { type: Date },
  url:          { type: String, unique: true, required: true },
  image_url:    { type: String },
  is_breaking:  { type: Boolean, default: false },
  tags:         [{ type: String }],
  fetched_at:   { type: Date, default: Date.now },
});

module.exports = mongoose.model('NewsArticle', NewsArticleSchema);
