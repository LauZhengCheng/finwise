// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : bullmq.js
// Description   : BullMQ queue factory backed by Upstash Redis.
//                 Exports getQueue() — creates queues on demand.
// First Written : 17-06-2026
// Edited on     : 17-06-2026
// ============================================

const { Queue } = require('bullmq');

const redisUrl = new URL(process.env.UPSTASH_REDIS_URL);
const connection = {
  host: redisUrl.hostname,
  port: parseInt(redisUrl.port, 10) || 6379,
  password: process.env.UPSTASH_REDIS_TOKEN,
  tls: {},
};

const queues = {};

function getQueue(name) {
  if (!queues[name]) {
    queues[name] = new Queue(name, { connection });
  }
  return queues[name];
}

module.exports = { getQueue, connection };
