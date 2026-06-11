// src/server.js
//
// BFF (Backend For Frontend) API Gateway
//
// What a BFF does:
//   Instead of the frontend calling 5 different microservices directly,
//   it calls ONE endpoint (this gateway). The gateway:
//     1. Accepts a GraphQL query
//     2. Fans out to the relevant microservices in parallel
//     3. Stitches the results together
//     4. Returns a single response shaped exactly for the frontend's needs
//
// Why GraphQL?
//   The frontend asks for exactly the fields it needs — no over-fetching.
//   One query can span multiple services — no N+1 round trips.
//   The schema is self-documenting.
//
// Services this gateway aggregates:
//   - go-auth          (authentication / token validation)
//   - java-inventory   (products and stock)
//   - nodejs-notification (notifications)
//   - python-url-shortener (URL operations)
//   - rust-ratelimiter  (rate limiting, applied as middleware)

const { ApolloServer } = require("@apollo/server");
const { startStandaloneServer } = require("@apollo/server/standalone");
const { makeExecutableSchema } = require("@graphql-tools/schema");
const { register, collectDefaultMetrics } = require("prom-client");
const express = require("express");
const typeDefs = require("./graphql/schema");
const resolvers = require("./resolvers");
const { AuthDataSource } = require("./datasources/authDataSource");
const { InventoryDataSource } = require("./datasources/inventoryDataSource");
const { NotificationDataSource } = require("./datasources/notificationDataSource");
const { UrlDataSource } = require("./datasources/urlDataSource");
const { RedisCache } = require("./cache/redisCache");
const { rateLimitMiddleware } = require("./middleware/rateLimit");
const { authMiddleware } = require("./middleware/auth");
const logger = require("./logger");

collectDefaultMetrics();

async function start() {
  const cache = new RedisCache(process.env.REDIS_URL || "redis://localhost:6379");
  await cache.connect();

  const schema = makeExecutableSchema({ typeDefs, resolvers });

  const server = new ApolloServer({
    schema,
    // Plugins for logging and metrics
    plugins: [
      {
        async requestDidStart({ request }) {
          const start = Date.now();
          return {
            async willSendResponse({ response }) {
              const duration = Date.now() - start;
              logger.info({
                query: request.operationName,
                duration_ms: duration,
                status: response.body.kind,
              });
            },
          };
        },
      },
    ],
    formatError: (formattedError) => {
      logger.error({ error: formattedError.message });
      // Don't expose internal error details in production
      if (process.env.NODE_ENV === "production") {
        return { message: formattedError.message };
      }
      return formattedError;
    },
  });

  const { url } = await startStandaloneServer(server, {
    listen: { port: parseInt(process.env.PORT || "4000") },
    context: async ({ req }) => {
      // Apply rate limiting before every request
      await rateLimitMiddleware(req);

      // Extract and validate auth token
      const user = await authMiddleware(req);

      return {
        user,
        dataSources: {
          auth:         new AuthDataSource(cache),
          inventory:    new InventoryDataSource(cache),
          notification: new NotificationDataSource(cache),
          url:          new UrlDataSource(cache),
        },
      };
    },
  });

  // Expose /health and /metrics via a separate Express app on a different port
  // so they are not accessible through the GraphQL endpoint
  const metricsApp = express();
  metricsApp.get("/health", (_, res) => res.json({ status: "ok" }));
  metricsApp.get("/metrics", async (_, res) => {
    res.set("Content-Type", register.contentType);
    res.end(await register.metrics());
  });
  metricsApp.listen(9090, () => logger.info("Metrics listening on :9090"));

  logger.info({ url }, "BFF Gateway started");
}

start().catch((err) => {
  logger.error({ err }, "Failed to start BFF Gateway");
  process.exit(1);
});
