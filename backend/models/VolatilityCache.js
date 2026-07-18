// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : VolatilityCache.js
// Description   : Mongoose schema for cached volatility values.
//                 Stores calculated annualised volatility per ticker.
// First Written : 25-06-2026
// Edited on     : 25-06-2026
// ============================================

const mongoose = require('mongoose');

const VolatilityCacheSchema = new mongoose.Schema({
  ticker:      { type: String, required: true, unique: true },
  category:    { type: String, enum: ['stocks', 'crypto', 'etf'] },
  volatility:  { type: Number, required: true },
  updated_at:  { type: Date, default: Date.now },
});

module.exports = mongoose.model('VolatilityCache', VolatilityCacheSchema);
