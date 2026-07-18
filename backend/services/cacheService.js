// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : cacheService.js
// Description   : Redis cache helpers — get, set with TTL, invalidate.
//                 All values serialised as JSON strings.
// First Written : 17-06-2026
// Edited on     : 17-06-2026
// ============================================

const { getRedisClient } = require('../config/redis');

async function cacheGet(key) {
  try {
    const redis = getRedisClient();
    const raw = await redis.get(key);
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
}

let _cacheSetErrorLogged = false;
async function cacheSet(key, value, ttlSeconds) {
  try {
    const redis = getRedisClient();
    await redis.set(key, JSON.stringify(value), 'EX', ttlSeconds);
    _cacheSetErrorLogged = false;
  } catch (err) {
    if (!_cacheSetErrorLogged) {
      console.error('[Cache] Set error (suppressing repeats):', err.message);
      _cacheSetErrorLogged = true;
    }
  }
}

async function cacheDelete(key) {
  try {
    const redis = getRedisClient();
    await redis.del(key);
  } catch (err) {
    console.error('[Cache] Delete error:', err.message);
  }
}

module.exports = { cacheGet, cacheSet, cacheDelete };
