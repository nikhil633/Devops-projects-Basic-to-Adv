// src/datasources/inventoryDataSource.js
// Each DataSource wraps HTTP calls to one microservice.
// Results are cached in Redis with a TTL to reduce load on downstream services.
// Cache is invalidated on mutations.

const axios = require("axios");
const logger = require("../logger");

const INVENTORY_URL = process.env.INVENTORY_SERVICE_URL || "http://localhost:8080";
const CACHE_TTL_SECS = 30;

class InventoryDataSource {
  constructor(cache) {
    this.http  = axios.create({ baseURL: INVENTORY_URL, timeout: 5000 });
    this.cache = cache;
  }

  async getProducts() {
    const cacheKey = "inventory:products:all";
    const cached = await this.cache.get(cacheKey);
    if (cached) return cached;

    const { data } = await this.http.get("/api/products");

    // Shape the response to match GraphQL schema field names
    const products = data.map(this._shape);
    await this.cache.set(cacheKey, products, CACHE_TTL_SECS);
    return products;
  }

  async getProduct(id) {
    const cacheKey = `inventory:product:${id}`;
    const cached = await this.cache.get(cacheKey);
    if (cached) return cached;

    const { data } = await this.http.get(`/api/products/${id}`);
    const product = this._shape(data);
    await this.cache.set(cacheKey, product, CACHE_TTL_SECS);
    return product;
  }

  async createProduct({ name, description, price, stock }) {
    const { data } = await this.http.post("/api/products", { name, description, price, stock });
    await this.cache.del("inventory:products:all");  // invalidate list cache
    return this._shape(data);
  }

  async updateStock(id, delta) {
    const { data } = await this.http.patch(`/api/products/${id}/stock`, { delta });
    await this.cache.del(`inventory:product:${id}`);
    await this.cache.del("inventory:products:all");
    return { message: data.message };
  }

  async deleteProduct(id) {
    await this.http.delete(`/api/products/${id}`);
    await this.cache.del(`inventory:product:${id}`);
    await this.cache.del("inventory:products:all");
    return true;
  }

  // Map Java's camelCase/snake_case fields to GraphQL schema names
  _shape(p) {
    return {
      id:          String(p.id),
      name:        p.name,
      description: p.description,
      price:       p.price,
      stock:       p.stock,
      createdAt:   p.createdAt,
    };
  }
}

// src/datasources/authDataSource.js
class AuthDataSource {
  constructor(cache) {
    this.http  = axios.create({
      baseURL: process.env.AUTH_SERVICE_URL || "http://localhost:8080",
      timeout: 3000,
    });
    this.cache = cache;
  }

  async login(username, password) {
    const { data } = await this.http.post("/auth/login", { username, password });
    return {
      accessToken:  data.access_token,
      refreshToken: data.refresh_token,
      tokenType:    data.token_type,
    };
  }

  async refreshToken(refreshToken) {
    const { data } = await this.http.post("/auth/refresh", { refresh_token: refreshToken });
    return {
      accessToken:  data.access_token,
      refreshToken: data.refresh_token,
      tokenType:    "Bearer",
    };
  }

  async validateToken(token) {
    const cacheKey = `auth:token:${token.slice(-16)}`; // cache by last 16 chars
    const cached = await this.cache.get(cacheKey);
    if (cached) return cached;

    const { data } = await this.http.post("/auth/validate", { token });
    const result = { valid: data.valid, subject: data.subject };

    if (data.valid) {
      await this.cache.set(cacheKey, result, 60); // cache valid tokens for 60s
    }
    return result;
  }
}

// src/datasources/notificationDataSource.js
class NotificationDataSource {
  constructor(cache) {
    this.http = axios.create({
      baseURL: process.env.NOTIFICATION_SERVICE_URL || "http://localhost:3000",
      timeout: 5000,
    });
    this.cache = cache;
  }

  async send({ type, recipient, message }) {
    const { data } = await this.http.post("/notify", { type, recipient, message });
    return { id: data.id, status: data.status };
  }

  async getStatus(id) {
    const cacheKey = `notif:status:${id}`;
    const cached = await this.cache.get(cacheKey);
    if (cached) return cached;

    const { data } = await this.http.get(`/status/${id}`);
    const result = {
      id:        data.id,
      type:      data.type,
      recipient: data.recipient,
      message:   data.message,
      status:    data.status,
      createdAt: data.createdAt,
    };
    if (data.status === "sent") {
      await this.cache.set(cacheKey, result, 300); // cache sent notifications for 5m
    }
    return result;
  }

  async getRecentNotifications() {
    // In production this would call a list endpoint
    return [];
  }
}

// src/datasources/urlDataSource.js
class UrlDataSource {
  constructor(cache) {
    this.http = axios.create({
      baseURL: process.env.URL_SERVICE_URL || "http://localhost:8000",
      timeout: 3000,
    });
  }

  async shorten(url, ttl) {
    const body = { url };
    if (ttl) body.ttl = ttl;
    const { data } = await this.http.post("/shorten", body);
    return {
      shortCode: data.short_code,
      shortUrl:  data.short_url,
    };
  }
}

module.exports = {
  InventoryDataSource,
  AuthDataSource,
  NotificationDataSource,
  UrlDataSource,
};
