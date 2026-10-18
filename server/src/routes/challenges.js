'use strict';

const express = require('express');
const { requireAuth } = require('../auth');
const { challengeDateKey, isFutureDate, isValidIsoDate } = require('../tehran');
const { toJalaali } = require('../jalali');
const store = require('../service/challenge_store');
const attempts = require('../service/attempts');
const leaderboard = require('../service/leaderboard');

const router = express.Router();
const GAME_TYPES = new Set(store.GAME_TYPES);

function badRequest(res, error) {
  return res.status(400).json({ error });
}

function currentMonthKey(now = new Date()) {
  const key = challengeDateKey(now);
  const [year, month, day] = key.split('-').map((v) => parseInt(v, 10));
  const j = toJalaali(year, month, day);
  return `${j.jy}-${String(j.jm).padStart(2, '0')}`;
}

function isEligibleDate(dateKey, now = new Date()) {
  if (!isValidIsoDate(dateKey) || isFutureDate(dateKey, now)) return false;
  const [year, month, day] = dateKey.split('-').map((v) => parseInt(v, 10));
  const j = toJalaali(year, month, day);
  return `${j.jy}-${String(j.jm).padStart(2, '0')}` === currentMonthKey(now);
}

function sendServiceError(res, err) {
  if (err && err.code === 'future_date') return res.status(400).json({ error: 'future_date' });
  if (err && (err.message === 'bad_date' || err.code === 'bad_date')) return res.status(400).json({ error: 'bad_date' });
  console.error('[challenges] request failed:', err && err.message ? err.message : err);
  return res.status(500).json({ error: 'internal_error' });
}

/** GET /challenge/date — backend-owned current Tehran date and Jalali date. */
router.get('/challenge/date', requireAuth, async (_req, res) => {
  const date = challengeDateKey(new Date());
  const [year, month, day] = date.split('-').map((v) => parseInt(v, 10));
  return res.json({
    date,
    timezone: 'Asia/Tehran',
    serverTime: new Date().toISOString(),
    jalali: toJalaali(year, month, day),
  });
});

/** GET /challenge/calendar — current Jalali month only, with user scores. */
router.get('/challenge/calendar', requireAuth, async (req, res) => {
  try {
    return res.json(await store.calendarForUser(req.userId));
  } catch (err) {
    return sendServiceError(res, err);
  }
});

/** GET /challenge/summary?date=YYYY-MM-DD — selected eligible date summary. */
router.get('/challenge/summary', requireAuth, async (req, res) => {
  const date = String(req.query.date || '');
  if (!isEligibleDate(date)) return badRequest(res, 'date_unavailable');
  try {
    return res.json(await store.summaryForUser(req.userId, date));
  } catch (err) {
    return sendServiceError(res, err);
  }
});

/**
 * POST /challenge/attempts — create or resume the counted attempt.
 * Body: { date, gameType, idempotencyKey, practice? }. User ID always comes from JWT.
 */
router.post('/challenge/attempts', requireAuth, async (req, res) => {
  const date = String((req.body && req.body.date) || '');
  const gameType = String((req.body && req.body.gameType) || '');
  const idempotencyKey = String((req.body && req.body.idempotencyKey) || '').slice(0, 128);
  if (!GAME_TYPES.has(gameType)) return badRequest(res, 'invalid_game_type');
  if (!isEligibleDate(date)) return badRequest(res, 'date_unavailable');

  try {
    const result = await attempts.startAttempt(req.userId, date, gameType, {
      counted: !(req.body && req.body.practice === true),
      idempotencyKey: idempotencyKey || null,
    });
    return res.status(result.resumed ? 200 : 201).json(result);
  } catch (err) {
    if (err && err.code === 'idempotency_key_conflict') return res.status(409).json({ error: 'idempotency_key_conflict' });
    if (err && err.code === 'attempt_closed') return res.status(409).json({ error: 'attempt_closed' });
    if (err && err.code === 'invalid_game_type') return res.status(400).json({ error: 'invalid_game_type' });
    // PostgreSQL unique_violation: attempt was created in a competing request.
    // Return the existing attempt by retrying start once (idempotent recovery).
    if (err && err.code === '23505') {
      try {
        const result = await attempts.startAttempt(req.userId, date, gameType, {
          counted: !(req.body && req.body.practice === true),
          idempotencyKey: idempotencyKey || null,
        });
        return res.status(200).json({ ...result, resumed: true });
      } catch (retryErr) {
        return sendServiceError(res, retryErr);
      }
    }
    return sendServiceError(res, err);
  }
});

router.get('/challenge/attempts/:id', requireAuth, async (req, res) => {
  try {
    const result = await attempts.getAttempt(req.userId, req.params.id);
    if (result.error === 'not_found') return res.status(404).json({ error: result.error });
    return res.json(result);
  } catch (err) {
    return sendServiceError(res, err);
  }
});

router.post('/challenge/attempts/:id/wordle-guess', requireAuth, async (req, res) => {
  const guess = String((req.body && req.body.guess) || '').trim();
  if (!/^[a-zA-Z]{5,7}$/.test(guess)) return badRequest(res, 'invalid_guess');
  try {
    const result = await attempts.wordleGuess(req.userId, req.params.id, guess);
    if (result.error === 'not_found') return res.status(404).json({ error: result.error });
    if (result.error === 'closed') return res.status(409).json({ error: result.error });
    if (result.error === 'already_solved') return res.status(409).json({ error: result.error });
    if (result.error) return badRequest(res, result.error);
    return res.json(result);
  } catch (err) {
    return sendServiceError(res, err);
  }
});

/** GET next question: server timestamps each presentation for speed scoring. */
router.post('/challenge/attempts/:id/wordef-next', requireAuth, async (req, res) => {
  try {
    const result = await attempts.nextWordefQuestion(req.userId, req.params.id);
    if (result.error === 'not_found') return res.status(404).json({ error: result.error });
    if (result.error === 'closed') return res.status(409).json({ error: result.error });
    if (result.error) return badRequest(res, result.error);
    return res.json(result);
  } catch (err) {
    return sendServiceError(res, err);
  }
});

router.post('/challenge/attempts/:id/wordef-answer', requireAuth, async (req, res) => {
  const index = Number(req.body && req.body.index);
  const option = String((req.body && req.body.option) || '');
  if (!Number.isInteger(index) || index < 0 || !option || option.length > 500) {
    return badRequest(res, 'invalid_answer');
  }
  try {
    const result = await attempts.answerWordef(req.userId, req.params.id, index, option);
    if (result.error === 'not_found') return res.status(404).json({ error: result.error });
    if (result.error === 'closed') return res.status(409).json({ error: result.error });
    if (result.error) return badRequest(res, result.error);
    return res.json(result);
  } catch (err) {
    return sendServiceError(res, err);
  }
});

router.post('/challenge/attempts/:id/clue', requireAuth, async (req, res) => {
  const index = Number(req.body && req.body.index);
  if (!Number.isInteger(index) || index < 0 || index >= 5) return badRequest(res, 'invalid_index');
  try {
    const result = await attempts.revealUnscrambleClue(req.userId, req.params.id, index);
    if (result.error === 'not_found') return res.status(404).json({ error: result.error });
    if (result.error === 'closed') return res.status(409).json({ error: result.error });
    return res.json(result);
  } catch (err) {
    return sendServiceError(res, err);
  }
});

router.post('/challenge/attempts/:id/unscramble-solve', requireAuth, async (req, res) => {
  const index = Number(req.body && req.body.index);
  const word = String((req.body && req.body.word) || '').trim();
  if (!Number.isInteger(index) || index < 0 || index >= 5 || !word || word.length > 64) {
    return badRequest(res, 'invalid_answer');
  }
  try {
    const result = await attempts.solveUnscrambleWord(req.userId, req.params.id, index, word);
    if (result.error === 'not_found') return res.status(404).json({ error: result.error });
    if (result.error === 'closed') return res.status(409).json({ error: result.error });
    if (result.error) return badRequest(res, result.error);
    return res.json(result);
  } catch (err) {
    return sendServiceError(res, err);
  }
});

router.post('/challenge/attempts/:id/abandon', requireAuth, async (req, res) => {
  try {
    const result = await attempts.abandonAttempt(req.userId, req.params.id);
    if (result.error === 'not_found') return res.status(404).json({ error: result.error });
    if (result.error) return res.status(409).json({ error: result.error });
    return res.json(result);
  } catch (err) {
    return sendServiceError(res, err);
  }
});

router.post('/challenge/attempts/:id/submit', requireAuth, async (req, res) => {
  try {
    const result = await attempts.submitAttempt(req.userId, req.params.id);
    if (result.error === 'not_found') return res.status(404).json({ error: result.error });
    if (result.error === 'closed') return res.status(409).json({ error: result.error });
    if (result.error) return badRequest(res, result.error);
    return res.json(result);
  } catch (err) {
    return sendServiceError(res, err);
  }
});

/** Global daily leaderboard (includes the current user's rank separately). */
router.get('/challenge/leaderboard/daily', requireAuth, async (req, res) => {
  try {
    return res.json(await leaderboard.dailyLeaderboard(req.userId, new Date(), req.query.limit, req.query.offset));
  } catch (err) {
    return sendServiceError(res, err);
  }
});

/** Global lifetime leaderboard (includes the current user's rank separately). */
router.get('/challenge/leaderboard/lifetime', requireAuth, async (req, res) => {
  try {
    return res.json(await leaderboard.lifetimeLeaderboard(req.userId, req.query.limit, req.query.offset));
  } catch (err) {
    return sendServiceError(res, err);
  }
});

module.exports = router;