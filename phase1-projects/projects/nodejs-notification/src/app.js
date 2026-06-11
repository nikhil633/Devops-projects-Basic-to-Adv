const express = require("express");
const { register } = require("prom-client");
const notifyRouter = require("./routes/notify");
const { collectDefaultMetrics } = require("prom-client");

collectDefaultMetrics();

const app = express();
app.use(express.json());

app.get("/health", (req, res) => {
  res.json({ status: "ok", timestamp: Date.now() });
});

app.get("/metrics", async (req, res) => {
  res.set("Content-Type", register.contentType);
  res.end(await register.metrics());
});

app.use("/", notifyRouter);

module.exports = app;
