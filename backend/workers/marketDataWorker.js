// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : marketDataWorker.js
// Description   : BullMQ worker — refreshes live market data every 15 min.
//                 Triggered by Cloud Scheduler via POST /api/jobs/trigger.
// First Written : 17-06-2026
// Edited on     : 17-06-2026
// ============================================

const { Worker } = require('bullmq');
const { connection } = require('../config/bullmq');
const { refreshAllMarketData } = require('../services/marketDataService');

const worker = new Worker('market-data', async (job) => {
  console.log(`[MarketDataWorker] Processing job ${job.id}`);
  await refreshAllMarketData();
  console.log('[MarketDataWorker] Done');
}, { connection, drainDelay: 300000 });

worker.on('failed', (job, err) => {
  console.error(`[MarketDataWorker] Job ${job?.id} failed:`, err.message);
});

module.exports = worker;
