'use strict';

// Generates MEDIA_ROOT/manifest.json by walking MEDIA_ROOT/assets.
// Run after uploading/syncing the media:  npm run manifest
//
// The manifest is what the Godot client's ContentManager reads to know which
// files exist, their sizes, their content hashes, and (when derivable) which
// book/lesson they belong to so per-lesson downloads can be batched.

require('dotenv').config();
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const MEDIA_ROOT = path.resolve(process.env.MEDIA_ROOT || './media');
const ASSETS_DIR = path.join(MEDIA_ROOT, 'assets');

function sha256File(file) {
  const hash = crypto.createHash('sha256');
  hash.update(fs.readFileSync(file));
  return hash.digest('hex');
}

/** Derive { book, lesson } from an assets-relative path, or null. */
function lessonOf(rel) {
  // assets/audio/v1/l2/conversation.mp3
  let m = rel.match(/^assets\/audio\/v(\d+)\/l(\d+)\//);
  if (m) return { book: parseInt(m[1], 10), lesson: parseInt(m[2], 10) };
  // assets/images/v1_l2_reading.png
  m = rel.match(/^assets\/images\/v(\d+)_l(\d+)_/);
  if (m) return { book: parseInt(m[1], 10), lesson: parseInt(m[2], 10) };
  return { book: null, lesson: null };
}

function walk(dir, out) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      walk(full, out);
    } else if (entry.isFile() && !entry.name.endsWith('.import')) {
      out.push(full);
    }
  }
  return out;
}

function main() {
  if (!fs.existsSync(ASSETS_DIR)) {
    console.error(`No assets directory at ${ASSETS_DIR}`);
    process.exit(1);
  }

  const files = walk(ASSETS_DIR, []).sort();
  const entries = [];
  const versionHash = crypto.createHash('sha256');

  for (const full of files) {
    const rel = path.relative(MEDIA_ROOT, full).split(path.sep).join('/');
    const sha = sha256File(full);
    const size = fs.statSync(full).size;
    const { book, lesson } = lessonOf(rel);
    entries.push({
      path: rel,
      size,
      sha256: sha,
      book,
      lesson,
      url: `/content/${rel}`,
    });
    versionHash.update(`${rel}:${sha}\n`);
  }

  const manifest = {
    version: versionHash.digest('hex').slice(0, 16),
    generated_at: new Date().toISOString(),
    count: entries.length,
    total_bytes: entries.reduce((sum, e) => sum + e.size, 0),
    files: entries,
  };

  const outPath = path.join(MEDIA_ROOT, 'manifest.json');
  fs.writeFileSync(outPath, JSON.stringify(manifest));
  console.log(
    `Wrote ${outPath}: ${entries.length} files, ${(manifest.total_bytes / 1048576).toFixed(1)} MB`
  );
}

main();
