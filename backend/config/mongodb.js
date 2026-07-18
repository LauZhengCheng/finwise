// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : mongodb.js
// Description   : Mongoose connection to MongoDB Atlas.
//                 Lazy-connects on first use — safe to import anywhere.
// First Written : 17-06-2026
// Edited on     : 17-06-2026
// ============================================

const dns = require('dns');
const mongoose = require('mongoose');

// Local router DNS doesn't support SRV record lookups (required by mongodb+srv://)
// Force Node.js to use Google DNS which resolves SRV records correctly
dns.setServers(['8.8.8.8', '8.8.4.4']);

let connectionPromise = null;
let lastErrorTime = 0;

async function connectMongo() {
  if (connectionPromise) return connectionPromise;

  connectionPromise = mongoose.connect(process.env.MONGODB_URI, {
    serverSelectionTimeoutMS: 8000,
    connectTimeoutMS: 8000,
  }).then(() => {
    console.log('[MongoDB] Connected to Atlas');
  }).catch((err) => {
    connectionPromise = null;
    const now = Date.now();
    // Only log once per 30 seconds to avoid spamming
    if (now - lastErrorTime > 30000) {
      console.warn('[MongoDB] Unavailable — market data cached to Redis only');
      lastErrorTime = now;
    }
    throw err;
  });

  return connectionPromise;
}

module.exports = { connectMongo };
