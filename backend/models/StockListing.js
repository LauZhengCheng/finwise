// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : StockListing.js
// Description   : Mongoose schema for US stock/ETF listings from
//                 Alpha Vantage LISTING_STATUS. MongoDB backup
//                 for when Redis is unavailable.
// First Written : 25-06-2026
// Edited on     : 25-06-2026
// ============================================

const mongoose = require('mongoose');

const StockListingSchema = new mongoose.Schema({
  ticker:     { type: String, required: true, unique: true },
  name:       { type: String, required: true },
  exchange:   { type: String },
  category:   { type: String, enum: ['stocks', 'etf'], required: true },
  fetched_at: { type: Date, default: Date.now },
});

module.exports = mongoose.model('StockListing', StockListingSchema);
