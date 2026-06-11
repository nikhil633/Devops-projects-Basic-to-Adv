// src/resolvers/index.js
// Resolvers connect GraphQL fields to downstream microservice calls.
// Each resolver receives (parent, args, context) where context.dataSources
// holds pre-configured HTTP clients for each service.

const { Counter, Histogram } = require("prom-client");

const resolverCalls = new Counter({
  name: "bff_resolver_calls_total",
  help: "Total resolver invocations",
  labelNames: ["resolver", "status"],
});

const resolverDuration = new Histogram({
  name: "bff_resolver_duration_seconds",
  help: "Resolver execution time",
  labelNames: ["resolver"],
  buckets: [0.01, 0.05, 0.1, 0.3, 0.5, 1.0, 2.0],
});

// Wraps a resolver function with metrics instrumentation
function withMetrics(name, fn) {
  return async (parent, args, ctx, info) => {
    const end = resolverDuration.startTimer({ resolver: name });
    try {
      const result = await fn(parent, args, ctx, info);
      resolverCalls.inc({ resolver: name, status: "success" });
      return result;
    } catch (err) {
      resolverCalls.inc({ resolver: name, status: "error" });
      throw err;
    } finally {
      end();
    }
  };
}

module.exports = {
  Query: {
    // ── Inventory ──────────────────────────────────────────────────────
    products: withMetrics("products", async (_, __, { dataSources }) => {
      return dataSources.inventory.getProducts();
    }),

    product: withMetrics("product", async (_, { id }, { dataSources }) => {
      return dataSources.inventory.getProduct(id);
    }),

    // ── Auth ───────────────────────────────────────────────────────────
    validateToken: withMetrics("validateToken", async (_, { token }, { dataSources }) => {
      return dataSources.auth.validateToken(token);
    }),

    // ── Notification ───────────────────────────────────────────────────
    notificationStatus: withMetrics("notificationStatus", async (_, { id }, { dataSources }) => {
      return dataSources.notification.getStatus(id);
    }),

    // ── Dashboard: fans out to inventory + notification in parallel ────
    // This is the key value of a BFF — one query, multiple services,
    // results stitched together before returning to client.
    dashboard: withMetrics("dashboard", async (_, __, { dataSources }) => {
      const [products, recentNotifications] = await Promise.all([
        dataSources.inventory.getProducts(),
        dataSources.notification.getRecentNotifications(),
      ]);

      const lowStockItems = products.filter((p) => p.stock < 10);

      return {
        totalProducts: products.length,
        lowStockItems,
        recentNotifications,
      };
    }),
  },

  Mutation: {
    // ── Auth ───────────────────────────────────────────────────────────
    login: withMetrics("login", async (_, { username, password }, { dataSources }) => {
      return dataSources.auth.login(username, password);
    }),

    refreshToken: withMetrics("refreshToken", async (_, { refreshToken }, { dataSources }) => {
      return dataSources.auth.refreshToken(refreshToken);
    }),

    // ── Inventory ──────────────────────────────────────────────────────
    createProduct: withMetrics("createProduct", async (_, args, { dataSources }) => {
      return dataSources.inventory.createProduct(args);
    }),

    updateStock: withMetrics("updateStock", async (_, { id, delta }, { dataSources }) => {
      return dataSources.inventory.updateStock(id, delta);
    }),

    deleteProduct: withMetrics("deleteProduct", async (_, { id }, { dataSources }) => {
      return dataSources.inventory.deleteProduct(id);
    }),

    // ── Notification ───────────────────────────────────────────────────
    sendNotification: withMetrics("sendNotification", async (_, args, { dataSources }) => {
      return dataSources.notification.send(args);
    }),

    // ── URL Shortener ──────────────────────────────────────────────────
    shortenUrl: withMetrics("shortenUrl", async (_, { url, ttl }, { dataSources }) => {
      return dataSources.url.shorten(url, ttl);
    }),
  },
};
