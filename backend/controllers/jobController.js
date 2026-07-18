// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : jobController.js
// Description   : Receives job trigger requests from Cloud Scheduler.
//                 Pushes jobs into BullMQ queues for workers to process.
//                 Bearer token protected — only Cloud Scheduler can call this.
// First Written : 18-06-2026
// Edited on     : 18-06-2026
// ============================================

const { getQueue } = require('../config/bullmq');

const JOB_QUEUE_MAP = {
  market_data:  'market-data',
  news_fetch:   'news-fetch',
  fd_scrape:    'fd-scrape',
  deals_scrape: 'deals-scrape',
};

const triggerJob = async (req, res) => {
  try {
    const auth = req.headers.authorization || '';
    const token = auth.replace('Bearer ', '');
    if (token !== process.env.JOB_TRIGGER_SECRET) {
      return res.status(401).json({ success: false, message: 'Unauthorised' });
    }

    const { jobType } = req.body;
    const queueName = JOB_QUEUE_MAP[jobType];

    if (!queueName) {
      return res.status(400).json({
        success: false,
        message: `Unknown jobType "${jobType}". Valid types: ${Object.keys(JOB_QUEUE_MAP).join(', ')}`,
      });
    }

    const queue = getQueue(queueName);
    const job = await queue.add(jobType, {}, {
      attempts: 3,
      backoff: { type: 'exponential', delay: 5000 },
      removeOnComplete: 50,
      removeOnFail: 20,
    });

    console.log(`[Jobs] Queued "${jobType}" → job ID ${job.id}`);

    return res.status(202).json({
      success: true,
      message: `Job "${jobType}" queued`,
      jobId: job.id,
    });
  } catch (error) {
    console.error('[Jobs] triggerJob error:', error.message);
    res.status(500).json({ success: false, message: 'Failed to queue job' });
  }
};

module.exports = { triggerJob };
