const express = require("express");
const router = express.Router();
const notificationService = require("../services/notificationService");
const { Counter, Histogram } = require("prom-client");

const notifySent = new Counter({
  name: "notifications_sent_total",
  help: "Total notifications enqueued",
  labelNames: ["type"],
});

const notifyDuration = new Histogram({
  name: "notification_processing_seconds",
  help: "Time to process notification",
});

// POST /notify
router.post("/notify", async (req, res) => {
  const { type, recipient, message } = req.body;
  if (!type || !recipient || !message) {
    return res.status(400).json({ error: "type, recipient and message are required" });
  }
  const end = notifyDuration.startTimer();
  const id = await notificationService.enqueue({ type, recipient, message });
  end();
  notifySent.inc({ type });
  res.status(202).json({ id, status: "queued" });
});

// GET /status/:id
router.get("/status/:id", async (req, res) => {
  const result = await notificationService.getStatus(req.params.id);
  if (!result) return res.status(404).json({ error: "Notification not found" });
  res.json(result);
});

module.exports = router;
