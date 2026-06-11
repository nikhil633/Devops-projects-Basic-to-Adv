// src/cache/redisCache.js
const { createClient } = require("redis");
const logger = require("../logger");

class RedisCache {
  constructor(url) {
    this.client = createClient({ url });
    this.client.on("error", (err) => logger.error({ err }, "Redis error"));
  }

  async connect() {
    await this.client.connect();
    logger.info("Redis cache connected");
  }

  async get(key) {
    const raw = await this.client.get(key);
    return raw ? JSON.parse(raw) : null;
  }

  async set(key, value, ttlSeconds = 60) {
    await this.client.set(key, JSON.stringify(value), { EX: ttlSeconds });
  }

  async del(key) {
    await this.client.del(key);
  }
}

module.exports = { RedisCache };
