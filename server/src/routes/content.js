'use strict';

const express = require('express');
const fs = require('fs');
const path = require('path');
const { requireAuth } = require('../auth');

const router = express.Router();

const MEDIA_ROOT = path.resolve(process.env.MEDIA_ROOT || './media');

const CONTENT_TYPES = {
  '.mp3': 'audio/mpeg',
  '.wav': 'audio/wav',
  '.ogg': 'audio/ogg',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.webp': 'image/webp',
  '.json': 'application/json',
  '.ttf': 'font/ttf',
};

/** GET /content/manifest — the list of downloadable media files. */
router.get('/content/manifest', requireAuth, (req, res) => {
  const manifestPath = path.join(MEDIA_ROOT, 'manifest.json');
  if (!fs.existsSync(manifestPath)) {
    return res.status(503).json({ error: 'manifest_missing' });
  }
  try {
    const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
    return res.json(manifest);
  } catch (err) {
    console.error('Bad manifest:', err.message);
    return res.status(500).json({ error: 'manifest_invalid' });
  }
});

/**
 * GET /content/<path> — serve one media file.
 * `<path>` is relative to MEDIA_ROOT, e.g. assets/audio/v1/l1/conversation.mp3.
 */
router.get('/content/*', requireAuth, (req, res) => {
  const rel = decodeURIComponent(req.params[0] || '');
  const resolved = path.resolve(MEDIA_ROOT, rel);
  // Prevent path traversal: the resolved path must stay under MEDIA_ROOT.
  if (!resolved.startsWith(MEDIA_ROOT + path.sep)) {
    return res.status(400).json({ error: 'bad_path' });
  }
  if (!fs.existsSync(resolved) || !fs.statSync(resolved).isFile()) {
    return res.status(404).json({ error: 'not_found' });
  }
  const ext = path.extname(resolved).toLowerCase();
  res.setHeader('Content-Type', CONTENT_TYPES[ext] || 'application/octet-stream');
  res.setHeader('Cache-Control', 'public, max-age=31536000, immutable');
  return res.sendFile(resolved);
});

module.exports = router;
