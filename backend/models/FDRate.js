// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : FDRate.js
// Description   : Mongoose schema for fixed deposit rates
//                 scraped from iMoney via Jina AI Reader.
// First Written : 20-06-2026
// Edited on     : 20-06-2026
// ============================================

const mongoose = require('mongoose');

const FDRateSchema = new mongoose.Schema({
  bank:           { type: String, required: true },
  product:        { type: String, required: true },
  min_amount:     { type: Number },
  tenure_months:  { type: Number },
  interest_rate:  { type: Number, required: true },
  apply_url:      { type: String },
  logo_url:       { type: String },
  source_url:     { type: String },
  is_islamic:     { type: Boolean, default: false },
  scraped_at:     { type: Date, default: Date.now },
});

FDRateSchema.index({ bank: 1, product: 1, tenure_months: 1 }, { unique: true });

module.exports = mongoose.model('FDRate', FDRateSchema);
