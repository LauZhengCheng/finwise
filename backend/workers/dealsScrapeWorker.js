// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : dealsScrapeWorker.js
// Description   : BullMQ worker — scrapes merchant deals daily via Jina + Gemini.
//                 Triggered by Cloud Scheduler via POST /api/jobs/trigger.
// First Written : 20-06-2026
// Edited on     : 20-06-2026
// ============================================

const { Worker } = require('bullmq');
const { connection } = require('../config/bullmq');
const { scrapeDeals } = require('../services/scrapeService');

const worker = new Worker('deals-scrape', async (job) => {
  console.log(`[DealsScrapeWorker] Processing job ${job.id}`);
  await scrapeDeals();
  console.log('[DealsScrapeWorker] Done');
}, { connection, drainDelay: 300000 });

worker.on('failed', (job, err) => {
  console.error(`[DealsScrapeWorker] Job ${job?.id} failed:`, err.message);
});

module.exports = worker;
