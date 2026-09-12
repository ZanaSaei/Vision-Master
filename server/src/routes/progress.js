'use strict';

const express = require('express');
const db = require('../db');
const { requireAuth } = require('../auth');

const router = express.Router();

/** GET /progress — the caller's progress blob. */
router.get('/progress', requireAuth, async (req, res) => {
  const row = (
    await db.query('SELECT data, updated_at FROM progress WHERE user_id = $1', [req.userId])
  ).rows[0];
  if (!row) return res.json({ data: {}, updated_at: null });
  return res.json({ data: row.data, updated_at: row.updated_at });
});

/**
 * PUT /progress — upsert the caller's blob.
 * Body: { data: <object> }. The blob is opaque to the server; the app owns its
 * shape, so it can grow (new fields, new stats) with no migration.
 */
router.put('/progress', requireAuth, async (req, res) => {
  const data = req.body && req.body.data;
  if (data === null || typeof data !== 'object' || Array.isArray(data)) {
    return res.status(400).json({ error: 'invalid_data' });
  }
  await db.query(
    `INSERT INTO progress (user_id, data, updated_at)
     VALUES ($1, $2, now())
     ON CONFLICT (user_id) DO UPDATE
        SET data = EXCLUDED.data, updated_at = now()`,
    [req.userId, data]
  );
  return res.json({ ok: true });
});

module.exports = router;
