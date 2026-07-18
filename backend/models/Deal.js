// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : Deal.js
// Description   : Mongoose schema for merchant deals scraped
//                 from ShopBack/LoopMe via Jina AI Reader.
// First Written : 20-06-2026
// Edited on     : 20-06-2026
// ============================================

const mongoose = require('mongoose');

const DealSchema = new mongoose.Schema({
  merchant:     { type: String, required: true },
  deal_title:   { type: String, required: true },
  category:     { type: String },
  discount_pct: { type: Number },
  max_cashback: { type: Number },
  valid_until:  { type: Date },
  is_need:      { type: Boolean, default: false },
  is_want:      { type: Boolean, default: false },
  aion_note:    { type: String },
  apply_url:    { type: String },
  source:       { type: String },
  source_url:   { type: String },
  scraped_at:   { type: Date, default: Date.now },
});

DealSchema.index({ merchant: 1, deal_title: 1 }, { unique: true });

module.exports = mongoose.model('Deal', DealSchema);
