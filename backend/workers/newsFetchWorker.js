// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : newsFetchWorker.js
// Description   : BullMQ worker — fetches and summarises financial news every 2 hours.
//                 Triggered by Cloud Scheduler via POST /api/jobs/trigger.
// First Written : 17-06-2026
// Edited on     : 17-06-2026
// ============================================

const { Worker } = require('bullmq');
const { connection } = require('../config/bullmq');
const { fetchAndSummariseNews } = require('../services/newsService');

const worker = new Worker('news-fetch', async (job) => {
  console.log(`[NewsFetchWorker] Processing job ${job.id}`);
  await fetchAndSummariseNews();
  console.log('[NewsFetchWorker] Done');
}, { connection, drainDelay: 300000 });

worker.on('failed', (job, err) => {
  console.error(`[NewsFetchWorker] Job ${job?.id} failed:`, err.message);
});

module.exports = worker;
