// src/middleware/auth.js
// Extracts the Bearer token from the Authorization header.
// Does NOT validate it here — validation happens lazily in the
// validateToken resolver if needed. Some queries are public (products list).

async function authMiddleware(req) {
  const authHeader = req.headers.authorization || "";
  if (!authHeader.startsWith("Bearer ")) return null;
  const token = authHeader.slice(7);
  return { token };
}

module.exports = { authMiddleware };
