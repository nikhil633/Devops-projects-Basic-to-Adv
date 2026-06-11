const { createClient } = require("redis");
const { v4: uuidv4 } = require("uuid");
const logger = require("../logger");

let client;

async function getRedis() {
  if (!client) {
    client = createClient({ url: process.env.REDIS_URL || "redis://localhost:6379" });
    client.on("error", (err) => logger.error({ err }, "Redis error"));
    await client.connect();
  }
  return client;
}

async function enqueue(payload) {
  const id = uuidv4();
  const r = await getRedis();
  const record = { id, ...payload, status: "queued", createdAt: new Date().toISOString() };
  await r.set(`notif:${id}`, JSON.stringify(record), { EX: 86400 });
  // In production this would push to BullMQ / SQS; for now we mark sent
  await r.set(`notif:${id}`, JSON.stringify({ ...record, status: "sent" }), { EX: 86400 });
  logger.info({ id, type: payload.type }, "Notification queued");
  return id;
}

async function getStatus(id) {
  const r = await getRedis();
  const raw = await r.get(`notif:${id}`);
  return raw ? JSON.parse(raw) : null;
}

module.exports = { enqueue, getStatus };
