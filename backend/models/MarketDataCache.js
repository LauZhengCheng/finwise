// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : MarketDataCache.js
// Description   : Mongoose schema for market data cache —
//                 stocks, crypto, and FX rates.
// First Written : 17-06-2026
// Edited on     : 17-06-2026
// ============================================

const mongoose = require('mongoose');

const MarketDataCacheSchema = new mongoose.Schema({
  symbol:         { type: String, required: true, unique: true },
  type:           { type: String, enum: ['stock', 'crypto', 'fx', 'index_list'], required: true },
  price:          { type: Number },
  change_pct_24h: { type: Number },
  high_24h:       { type: Number },
  low_24h:        { type: Number },
  volume:         { type: Number },
  constituents:   [String],
  updated_at:     { type: Date, default: Date.now },
});

module.exports = mongoose.model('MarketDataCache', MarketDataCacheSchema);
