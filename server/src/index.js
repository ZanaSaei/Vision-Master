'use strict';

require('dotenv').config();
const express = require('express');
const authRoutes = require('./routes/auth');
const progressRoutes = require('./routes/progress');
const contentRoutes = require('./routes/content');

const app = express();

// The progress blob and auth bodies are tiny; a small limit keeps abuse cheap.
app.use(express.json({ limit: '256kb' }));

app.get('/health', (_req, res) => res.json({ ok: true, service: 'vision-master' }));

app.use('/auth', authRoutes);
app.use('/', progressRoutes);
app.use('/', contentRoutes);

// Central error handler — never leak stack traces to clients.
// eslint-disable-next-line no-unused-vars
app.use((err, _req, res, _next) => {
  console.error('Unhandled error:', err);
  res.status(500).json({ error: 'internal_error' });
});

const port = parseInt(process.env.PORT || '3000', 10);
app.listen(port, () => {
  console.log(`Vision Master server listening on :${port}`);
});
