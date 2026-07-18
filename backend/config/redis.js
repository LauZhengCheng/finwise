// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : redis.js
// Description   : ioredis client singleton for Upstash Redis.
//                 Used by cacheService and BullMQ.
// First Written : 17-06-2026
// Edited on     : 17-06-2026
// ============================================

const Redis = require('ioredis');

let client = null;

function getRedisClient() {
  if (client) return client;

  client = new Redis(process.env.UPSTASH_REDIS_URL, {
    tls: {},
    maxRetriesPerRequest: 3,
    lazyConnect: true,
  });

  client.on('connect', () => console.log('[Redis] Connected to Upstash'));
  client.on('error', (err) => console.error('[Redis] Error:', err.message));

  return client;
}

module.exports = { getRedisClient };
