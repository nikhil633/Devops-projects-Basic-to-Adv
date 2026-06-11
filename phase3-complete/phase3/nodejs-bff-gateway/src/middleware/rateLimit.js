// src/middleware/rateLimit.js
// Calls the Rust rate limiter service before every GraphQL request.
// Uses the client IP as the key. Throws if rate limit exceeded.

const axios = require("axios");
const logger = require("../logger");

const RATE_LIMITER_URL = process.env.RATE_LIMITER_URL || "http://localhost:9000";
const RATE_LIMIT       = parseInt(process.env.RATE_LIMIT_PER_MINUTE || "60");

const rateLimiterClient = axios.create({
  baseURL: RATE_LIMITER_URL,
  timeout: 100,  // fast timeout — don't block if rate limiter is slow
});

async function rateLimitMiddleware(req) {
  const ip = req.headers["x-forwarded-for"] || req.socket.remoteAddress || "unknown";
  const key = `bff:${ip}`;

  try {
    const { data, status } = await rateLimiterClient.post(
      "/check",
      { key, limit: RATE_LIMIT, window_secs: 60 },
      { validateStatus: () => true }  // don't throw on 429
    );

    if (status === 429) {
      const error = new Error("Rate limit exceeded. Try again later.");
      error.extensions = { code: "RATE_LIMITED", remaining: 0 };
      throw error;
    }

    logger.debug({ key, remaining: data.remaining }, "Rate limit check passed");
  } catch (err) {
    if (err.extensions?.code === "RATE_LIMITED") throw err;
    // If rate limiter is down, fail open (don't block users)
    logger.warn({ err: err.message }, "Rate limiter unavailable — failing open");
  }
}

module.exports = { rateLimitMiddleware };
