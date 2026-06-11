// src/graphql/schema.js
// GraphQL schema — defines WHAT the frontend can query.
// Each type maps to one or more downstream microservices.

const { gql } = require("graphql-tag");

module.exports = gql`
  # ── Auth ────────────────────────────────────────────────────────────────
  type AuthPayload {
    accessToken:  String!
    refreshToken: String!
    tokenType:    String!
  }

  type TokenValidation {
    valid:   Boolean!
    subject: String
  }

  # ── Inventory ────────────────────────────────────────────────────────────
  type Product {
    id:          ID!
    name:        String!
    description: String
    price:       Float!
    stock:       Int!
    createdAt:   String
  }

  type StockUpdate {
    message: String!
  }

  # ── Notification ─────────────────────────────────────────────────────────
  type NotificationResult {
    id:     String!
    status: String!
  }

  type NotificationStatus {
    id:        String!
    type:      String!
    recipient: String!
    message:   String!
    status:    String!
    createdAt: String!
  }

  # ── URL Shortener ─────────────────────────────────────────────────────────
  type ShortUrl {
    shortCode: String!
    shortUrl:  String!
  }

  # ── Aggregated dashboard type (data from multiple services in one query) ──
  type Dashboard {
    totalProducts:  Int!
    lowStockItems:  [Product!]!
    recentNotifications: [NotificationStatus!]!
  }

  # ── Queries ───────────────────────────────────────────────────────────────
  type Query {
    # Inventory queries
    products:         [Product!]!
    product(id: ID!): Product

    # Auth queries
    validateToken(token: String!): TokenValidation!

    # Notification queries
    notificationStatus(id: String!): NotificationStatus

    # Aggregated dashboard — fans out to inventory + notification services
    dashboard: Dashboard!
  }

  # ── Mutations ─────────────────────────────────────────────────────────────
  type Mutation {
    # Auth mutations
    login(username: String!, password: String!): AuthPayload!
    refreshToken(refreshToken: String!): AuthPayload!

    # Inventory mutations
    createProduct(name: String!, description: String, price: Float!, stock: Int!): Product!
    updateStock(id: ID!, delta: Int!): StockUpdate!
    deleteProduct(id: ID!): Boolean!

    # Notification mutations
    sendNotification(type: String!, recipient: String!, message: String!): NotificationResult!

    # URL mutations
    shortenUrl(url: String!, ttl: Int): ShortUrl!
  }
`;
