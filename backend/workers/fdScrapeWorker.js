// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : fdScrapeWorker.js
// Description   : BullMQ worker — scrapes FD rates daily via Jina + Gemini.
//                 Triggered by Cloud Scheduler via POST /api/jobs/trigger.
// First Written : 20-06-2026
// Edited on     : 20-06-2026
// ============================================

const { Worker } = require('bullmq');
const { connection } = require('../config/bullmq');
const { scrapeFDRates } = require('../services/scrapeService');

const worker = new Worker('fd-scrape', async (job) => {
  console.log(`[FDScrapeWorker] Processing job ${job.id}`);
  await scrapeFDRates();
  console.log('[FDScrapeWorker] Done');
}, { connection, drainDelay: 300000 });

worker.on('failed', (job, err) => {
  console.error(`[FDScrapeWorker] Job ${job?.id} failed:`, err.message);
});

module.exports = worker;
