'use strict';

const express = require('express');
const db = require('../db');
const kavenegar = require('../kavenegar');
const {
  sha256,
  randomOtp,
  normalizePhone,
  issueTokens,
  requireAuth,
} = require('../auth');

const router = express.Router();

const OTP_TTL = parseInt(process.env.OTP_TTL || '120', 10);
const OTP_MAX_ATTEMPTS = parseInt(process.env.OTP_MAX_ATTEMPTS || '5', 10);
const OTP_RATE_WINDOW = parseInt(process.env.OTP_RATE_WINDOW || '60', 10);

/**
 * POST /auth/request-otp
 * Body: { phone }
 * Rate-limited per phone; stores a hashed code and sends it via Kavenegar.
 */
router.post('/request-otp', async (req, res) => {
  const phone = normalizePhone(req.body && req.body.phone);
  if (!phone) return res.status(400).json({ error: 'invalid_phone' });

  // Rate limit: at most one code per phone per OTP_RATE_WINDOW seconds.
  const recent = await db.query(
    'SELECT created_at FROM otp_codes WHERE phone = $1',
    [phone]
  );
  if (recent.rows.length > 0) {
    const ageMs = Date.now() - new Date(recent.rows[0].created_at).getTime();
    if (ageMs < OTP_RATE_WINDOW * 1000) {
      const retry = Math.ceil((OTP_RATE_WINDOW * 1000 - ageMs) / 1000);
      return res.status(429).json({ error: 'too_many_requests', retry_after: retry });
    }
  }

  const code = randomOtp(5);
  const expiresAt = new Date(Date.now() + OTP_TTL * 1000);
  await db.query(
    `INSERT INTO otp_codes (phone, code_hash, expires_at, attempts, created_at)
     VALUES ($1, $2, $3, 0, now())
     ON CONFLICT (phone) DO UPDATE
        SET code_hash = EXCLUDED.code_hash,
            expires_at = EXCLUDED.expires_at,
            attempts = 0,
            created_at = now()`,
    [phone, sha256(code), expiresAt]
  );

  try {
    await kavenegar.sendOtp(phone, code);
  } catch (err) {
    console.error('Failed to send OTP:', err.message);
    // Do not leak whether the number exists / provider failed in detail.
    return res.status(502).json({ error: 'sms_failed' });
  }

  return res.json({ ok: true, expires_in: OTP_TTL });
});

/**
 * POST /auth/verify-otp
 * Body: { phone, code }
 * On success: creates the user if needed, returns tokens + subscription.
 */
router.post('/verify-otp', async (req, res) => {
  const phone = normalizePhone(req.body && req.body.phone);
  const code = String((req.body && req.body.code) || '').trim();
  if (!phone || !/^\d{4,8}$/.test(code)) {
    return res.status(400).json({ error: 'invalid_input' });
  }

  const row = (await db.query('SELECT * FROM otp_codes WHERE phone = $1', [phone])).rows[0];
  if (!row) return res.status(400).json({ error: 'no_code' });
  if (new Date(row.expires_at).getTime() < Date.now()) {
    await db.query('DELETE FROM otp_codes WHERE phone = $1', [phone]);
    return res.status(400).json({ error: 'expired' });
  }
  if (row.attempts >= OTP_MAX_ATTEMPTS) {
    await db.query('DELETE FROM otp_codes WHERE phone = $1', [phone]);
    return res.status(429).json({ error: 'too_many_attempts' });
  }
  if (row.code_hash !== sha256(code)) {
    await db.query('UPDATE otp_codes SET attempts = attempts + 1 WHERE phone = $1', [phone]);
    return res.status(400).json({ error: 'invalid_code' });
  }

  await db.query('DELETE FROM otp_codes WHERE phone = $1', [phone]);

  let user = (await db.query('SELECT * FROM users WHERE phone = $1', [phone])).rows[0];
  if (!user) {
    user = (await db.query('INSERT INTO users (phone) VALUES ($1) RETURNING *', [phone])).rows[0];
  }

  const tokens = await issueTokens(user.id);
  return res.json({
    ...tokens,
    user_id: user.id,
    phone: user.phone,
    subscription: subscriptionOf(user),
  });
});

/**
 * POST /auth/refresh
 * Body: { refresh_token } — rotates the refresh token.
 */
router.post('/refresh', async (req, res) => {
  const token = String((req.body && req.body.refresh_token) || '');
  if (!token) return res.status(400).json({ error: 'missing_refresh_token' });

  const hash = sha256(token);
  const row = (await db.query('SELECT * FROM sessions WHERE refresh_hash = $1', [hash])).rows[0];
  if (!row || new Date(row.expires_at).getTime() < Date.now()) {
    if (row) await db.query('DELETE FROM sessions WHERE refresh_hash = $1', [hash]);
    return res.status(401).json({ error: 'invalid_refresh_token' });
  }

  // Rotate: delete the old, issue a new pair.
  await db.query('DELETE FROM sessions WHERE refresh_hash = $1', [hash]);
  const tokens = await issueTokens(row.user_id);
  return res.json(tokens);
});

/**
 * POST /auth/logout
 * Body: { refresh_token } — best-effort revoke of that refresh token.
 */
router.post('/logout', async (req, res) => {
  const token = String((req.body && req.body.refresh_token) || '');
  if (token) {
    await db.query('DELETE FROM sessions WHERE refresh_hash = $1', [sha256(token)]);
  }
  return res.json({ ok: true });
});

/** GET /me — current user + subscription. */
router.get('/me', requireAuth, async (req, res) => {
  const user = (await db.query('SELECT * FROM users WHERE id = $1', [req.userId])).rows[0];
  if (!user) return res.status(404).json({ error: 'not_found' });
  return res.json({
    user_id: user.id,
    phone: user.phone,
    subscription: subscriptionOf(user),
  });
});

function subscriptionOf(user) {
  const active =
    user.subscription_tier !== 'free' &&
    (!user.subscription_expires_at ||
      new Date(user.subscription_expires_at).getTime() > Date.now());
  return {
    tier: active ? user.subscription_tier : 'free',
    expires_at: user.subscription_expires_at,
  };
}

module.exports = router;
