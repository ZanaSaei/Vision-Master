'use strict';

const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const db = require('./db');

const ACCESS_TTL = parseInt(process.env.ACCESS_TTL || '3600', 10);
const REFRESH_TTL = parseInt(process.env.REFRESH_TTL || String(30 * 24 * 3600), 10);

/** sha256 hex of a string — used for OTP codes and refresh tokens at rest. */
function sha256(value) {
  return crypto.createHash('sha256').update(String(value)).digest('hex');
}

/** Random numeric OTP code. */
function randomOtp(digits = 5) {
  const max = 10 ** digits;
  const n = crypto.randomInt(0, max);
  return String(n).padStart(digits, '0');
}

/** Random opaque refresh token (256 bits, hex). */
function randomRefreshToken() {
  return crypto.randomBytes(32).toString('hex');
}

/**
 * Normalize an Iranian phone number to the canonical `09xxxxxxxxx` form.
 * Accepts `0912...`, `+98912...`, `0098912...`, `98912...`, and spaced/dashed
 * variants. Returns '' when it does not look like a phone number.
 */
function normalizePhone(raw) {
  if (!raw) return '';
  let digits = String(raw).replace(/[^\d+]/g, '');
  digits = digits.replace(/^\+/, '');
  if (digits.startsWith('0098')) digits = digits.slice(4);
  else if (digits.startsWith('98') && digits.length >= 12) digits = digits.slice(2);
  if (digits.startsWith('9') && digits.length === 10) digits = '0' + digits;
  if (!/^09\d{9}$/.test(digits)) return '';
  return digits;
}

function signAccessToken(userId) {
  return jwt.sign({ sub: userId }, process.env.JWT_SECRET, { expiresIn: ACCESS_TTL });
}

/** Create an access + refresh token pair and persist the (hashed) refresh row. */
async function issueTokens(userId) {
  const access = signAccessToken(userId);
  const refresh = randomRefreshToken();
  const expiresAt = new Date(Date.now() + REFRESH_TTL * 1000);
  await db.query(
    'INSERT INTO sessions (refresh_hash, user_id, expires_at) VALUES ($1, $2, $3)',
    [sha256(refresh), userId, expiresAt]
  );
  return { access_token: access, refresh_token: refresh, expires_in: ACCESS_TTL };
}

/** Express middleware: require a valid Bearer access token, set req.userId. */
function requireAuth(req, res, next) {
  const header = req.headers.authorization || '';
  const match = header.match(/^Bearer\s+(.+)$/i);
  if (!match) return res.status(401).json({ error: 'missing_token' });
  try {
    const payload = jwt.verify(match[1], process.env.JWT_SECRET);
    req.userId = payload.sub;
    next();
  } catch (err) {
    return res.status(401).json({ error: 'invalid_token' });
  }
}

module.exports = {
  ACCESS_TTL,
  REFRESH_TTL,
  sha256,
  randomOtp,
  randomRefreshToken,
  normalizePhone,
  signAccessToken,
  issueTokens,
  requireAuth,
};
