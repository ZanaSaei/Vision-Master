'use strict';

/**
 * Attempt lifecycle + gameplay validation + scoring.
 *
 * One COUNTED attempt per (user, challenge_date, game_type) is enforced by the
 * database unique index; practice attempts (counted = false) may be unlimited
 * and never touch any aggregate. All timing used for scoring is server-owned
 * (started_at / question_started_at), so a tampered client cannot fake speed.
 */

const db = require('../db');
const scoring = require('../scoring');
const { isPastDate, isFutureDate, isValidIsoDate } = require('../tehran');
const { ensureChallengeDay } = require('./challenge_store');
const { publicContentFor } = require('../public_content');

const CORRECT = 2;

const TIME_LIMITS = {
  wordle: scoring.WORDLE_TIME_LIMIT,
  wordef: scoring.WORDEF_TIME_LIMIT,
  unscramble: scoring.UNSCRAMBLE_TIME_LIMIT,
};

// ── Wordle feedback (port of the client's two-pass evaluator) ────────────────
function evaluateGuess(answer, guess) {
  const a = String(answer).toUpperCase();
  const g = String(guess).toUpperCase();
  const length = g.length;
  const result = new Array(length).fill(0);
  if (length === 0 || a.length !== length) return result;
  const remaining = {};
  for (let i = 0; i < length; i += 1) {
    if (g[i] === a[i]) result[i] = CORRECT;
    else remaining[a[i]] = (remaining[a[i]] || 0) + 1;
  }
  for (let i = 0; i < length; i += 1) {
    if (result[i] === CORRECT) continue;
    if ((remaining[g[i]] || 0) > 0) {
      result[i] = 1;
      remaining[g[i]] -= 1;
    }
  }
  return result;
}

function secondsSince(dateLike) {
  return Math.max(0, (Date.now() - new Date(dateLike).getTime()) / 1000);
}

function clampRemaining(gameType, elapsed) {
  return Math.max(0, TIME_LIMITS[gameType] - elapsed);
}

function attemptElapsed(attempt) {
  return attempt.elapsed_seconds != null
    ? Number(attempt.elapsed_seconds)
    : secondsSince(attempt.started_at);
}

// ── Attempt creation / resume ───────────────────────────────────────────────

/**
 * Start (or resume) an attempt. Validates the date (no future dates) and
 * freezes the historical flag at creation so crossing midnight cannot change
 * the rules of an active session.
 *
 * Returns { attempt, publicContent, resumed }.
 */
async function getAttempt(userId, attemptId) {
  const { rows } = await db.query(
    `SELECT id, game_type, challenge_date, counted, status, historical, started_at,
            elapsed_seconds, state, raw_score, adjusted_score, scoring_version
       FROM game_attempts
      WHERE id = $1 AND user_id = $2`,
    [attemptId, userId]
  );
  if (!rows[0]) return { error: 'not_found' };
  return { attempt: toAttemptView(rows[0]) };
}

async function startAttempt(userId, dateKey, gameType, opts = {}) {
  const counted = opts.counted !== false;
  const now = new Date();
  if (!['wordle', 'wordef', 'unscramble'].includes(gameType)) {
    const err = new Error('invalid_game_type');
    err.code = 'invalid_game_type';
    throw err;
  }
  if (!isValidIsoDate(dateKey)) {
    const err = new Error('bad_date');
    err.code = 'bad_date';
    throw err;
  }
  if (isFutureDate(dateKey, now)) {
    const err = new Error('future_date');
    err.code = 'future_date';
    throw err;
  }
  const historical = isPastDate(dateKey, now);

  return db.withTransaction(async (client) => {
    await ensureChallengeDay(client, dateKey);
    const gameRow = (
      await client.query(
        `SELECT public_content, secret_content FROM challenge_games WHERE challenge_date = $1 AND game_type = $2`,
        [dateKey, gameType]
      )
    ).rows[0];

    // An idempotent retry must return its original attempt. This also avoids a
    // second practice attempt if the same client request was retried.
    if (opts.idempotencyKey) {
      const prior = (
        await client.query(
          `SELECT * FROM game_attempts WHERE user_id = $1 AND idempotency_key = $2 LIMIT 1`,
          [userId, opts.idempotencyKey]
        )
      ).rows[0];
      if (prior) {
        const priorDate = prior.challenge_date instanceof Date
          ? prior.challenge_date.toISOString().slice(0, 10)
          : String(prior.challenge_date).slice(0, 10);
        if (priorDate !== dateKey || prior.game_type !== gameType || Boolean(prior.counted) !== counted) {
          const err = new Error('idempotency_key_conflict');
          err.code = 'idempotency_key_conflict';
          throw err;
        }
      }
      if (prior) {
        if (prior.status === 'completed' || prior.status === 'abandoned') {
          return { attempt: toAttemptView(prior), publicContent: publicContentFor(dateKey, gameType, gameRow), resumed: false, settled: true };
        }
        return {
          attempt: toAttemptView(prior),
          publicContent: publicContentFor(dateKey, gameType, gameRow),
          resumed: true,
        };
      }
    }

    // Reuse the single counted slot; it cannot be reopened or replayed for points.
    if (counted) {
      const existing = (
        await client.query(
          `SELECT * FROM game_attempts
            WHERE user_id = $1 AND challenge_date = $2 AND game_type = $3 AND counted
            LIMIT 1`,
          [userId, dateKey, gameType]
        )
      ).rows[0];
      if (existing) {
        if (existing.status !== 'in_progress') {
          const err = new Error('attempt_closed');
          err.code = 'attempt_closed';
          throw err;
        }
        return {
          attempt: toAttemptView(existing),
          publicContent: publicContentFor(dateKey, gameType, gameRow),
          resumed: true,
        };
      }
    }

    const inserted = (
      await client.query(
        `INSERT INTO game_attempts
           (user_id, challenge_date, game_type, counted, status, historical,
            penalty_rate, scoring_version, state, idempotency_key)
         VALUES ($1, $2, $3, $4, 'in_progress', $5, $6, $7, $8, $9)
         RETURNING *`,
        [
          userId, dateKey, gameType, counted, historical,
          historical ? scoring.HISTORICAL_PENALTY_RATE : 0,
          scoring.SCORING_VERSION, JSON.stringify(initialState(gameType)),
          opts.idempotencyKey || null,
        ]
      )
    ).rows[0];

    return {
      attempt: toAttemptView(inserted),
      publicContent: publicContentFor(dateKey, gameType, gameRow),
      resumed: false,
    };
  });
}

function initialState(gameType) {
  if (gameType === 'wordle') return { guesses: [] };
  if (gameType === 'wordef') return { answers: [], currentIndex: 0, questionStartedAt: null };
  return { solved: [], hinted: [] };
}

function toAttemptView(row) {
  return {
    id: row.id,
    gameType: row.game_type,
    date: String(row.challenge_date).slice(0, 10),
    counted: row.counted,
    status: row.status,
    historical: row.historical,
    startedAt: row.started_at,
    elapsedSeconds: row.elapsed_seconds,
    state: row.state || {},
    rawScore: row.raw_score,
    adjustedScore: row.adjusted_score,
    scoringVersion: row.scoring_version,
  };
}

// ── Shared helpers ──────────────────────────────────────────────────────────

async function loadOwnedAttempt(client, userId, attemptId) {
  // Serialize concurrent gameplay posts for this attempt so parallel retries
  // cannot overwrite each other's JSONB state.
  const row = (
    await client.query(`SELECT * FROM game_attempts WHERE id = $1 AND user_id = $2 FOR UPDATE`, [attemptId, userId])
  ).rows[0];
  return row || null;
}

async function secretFor(client, dateKey, gameType) {
  return (
    await client.query(
      `SELECT secret_content FROM challenge_games WHERE challenge_date = $1 AND game_type = $2`,
      [dateKey, gameType]
    )
  ).rows[0].secret_content;
}

// ── Wordle ──────────────────────────────────────────────────────────────────

/** Validate a Wordle guess against the real answer; record it; return feedback. */
async function wordleGuess(userId, attemptId, guess) {
  const content = require('../content');
  return db.withTransaction(async (client) => {
    const attempt = await loadOwnedAttempt(client, userId, attemptId);
    if (!attempt) return { error: 'not_found' };
    if (attempt.status !== 'in_progress') return { error: 'closed' };
    const state = attempt.state || { guesses: [] };
    if ((state.guesses || []).length >= scoring.WORDLE_MAX_GUESSES) return { error: 'no_attempts_left' };
    if (state.guesses.some((entry) => entry.feedback.every((cell) => cell === CORRECT))) return { error: 'already_solved' };

    const word = String(guess || '').toLowerCase();
    const elapsed = secondsSince(attempt.started_at);
    if (elapsed >= TIME_LIMITS.wordle) return { error: 'timeout' };
    const secret = await secretFor(client, String(attempt.challenge_date).slice(0, 10), 'wordle');
    if (word.length !== secret.answer.length) return { valid: false, error: 'invalid_word' };
    if (state.guesses.some((entry) => entry.guess === word)) return { error: 'duplicate_guess' };
    if (!content.isWordleGuess(word)) return { valid: false, error: 'invalid_word' };
    const feedback = evaluateGuess(secret.answer, word);
    const solved = feedback.every((c) => c === CORRECT);

    state.guesses.push({ guess: word, feedback });
    await client.query(
      `UPDATE game_attempts SET state = $2, updated_at = now() WHERE id = $1`,
      [attemptId, JSON.stringify(state)]
    );
    return { valid: true, feedback, solved };
  });
}

// ── Wordef ──────────────────────────────────────────────────────────────────

/** Begin/resume a Wordef question and account for unanswered timed-out questions. */
async function nextWordefQuestion(userId, attemptId) {
  return db.withTransaction(async (client) => {
    const attempt = await loadOwnedAttempt(client, userId, attemptId);
    if (!attempt) return { error: 'not_found' };
    if (attempt.status !== 'in_progress') return { error: 'closed' };
    const challengeRow = (
      await client.query(
        `SELECT public_content, secret_content FROM challenge_games WHERE challenge_date = $1 AND game_type = $2`,
        [String(attempt.challenge_date).slice(0, 10), 'wordef']
      )
    ).rows[0];
    const publicContent = challengeRow.public_content;
    const safeQuestions = publicContentFor(String(attempt.challenge_date).slice(0, 10), 'wordef', challengeRow).questions;
    const state = attempt.state || { answers: [], currentIndex: 0, questionStartedAt: null };
    const attemptElapsedSeconds = secondsSince(attempt.started_at);
    const questions = publicContent.questions || [];
    if (attemptElapsedSeconds >= TIME_LIMITS.wordef) {
      if (state.questionStartedAt && secondsSince(state.questionStartedAt) >= 30) {
        state.answers.push({ index: state.currentIndex, correct: false, elapsedSeconds: 30 });
        state.questionStartedAt = null;
        await client.query(`UPDATE game_attempts SET state = $2 WHERE id = $1`, [attemptId, JSON.stringify(state)]);
      }
      return { error: 'timeout' };
    }
    if (state.questionStartedAt) {
      const questionAge = secondsSince(state.questionStartedAt);
      if (questionAge < 30) {
        const currentIndex = state.currentIndex;
        return { question: safeQuestions[currentIndex], index: currentIndex, total: questions.length, resumed: true };
      }
      state.answers.push({ index: state.currentIndex, correct: false, elapsedSeconds: 30 });
      state.questionStartedAt = null;
    }
    const index = state.answers.length;
    if (index >= questions.length) {
      await client.query(`UPDATE game_attempts SET state = $2 WHERE id = $1`, [attemptId, JSON.stringify(state)]);
      return { done: true };
    }
    state.currentIndex = index;
    state.questionStartedAt = new Date().toISOString();
    await client.query(`UPDATE game_attempts SET state = $2 WHERE id = $1`, [attemptId, JSON.stringify(state)]);
    return { question: safeQuestions[index], index, total: questions.length };
  });
}

/** Validate one Wordef answer using the server-measured question time. */
async function answerWordef(userId, attemptId, index, option) {
  return db.withTransaction(async (client) => {
    const attempt = await loadOwnedAttempt(client, userId, attemptId);
    if (!attempt) return { error: 'not_found' };
    if (attempt.status !== 'in_progress') return { error: 'closed' };
    const state = attempt.state || { answers: [], currentIndex: 0, questionStartedAt: null };
    const attemptElapsed = secondsSince(attempt.started_at);
    if (attemptElapsed >= TIME_LIMITS.wordef) {
      if (state.questionStartedAt && secondsSince(state.questionStartedAt) >= 30) {
        state.answers.push({ index: state.currentIndex, correct: false, elapsedSeconds: 30 });
        state.questionStartedAt = null;
        await client.query(`UPDATE game_attempts SET state = $2 WHERE id = $1`, [attemptId, JSON.stringify(state)]);
      }
      return { error: 'timeout' };
    }
    if (!Number.isInteger(index) || index < 0 || index >= scoring.WORDEF_QUESTIONS) return { error: 'invalid_index' };
    if (!state.questionStartedAt) return { error: 'question_not_started' };
    if (state.currentIndex !== index) return { error: 'out_of_order' };

    const secret = await secretFor(client, String(attempt.challenge_date).slice(0, 10), 'wordef');
    const correct = secret.answers[index] === option;
    const elapsedSeconds = secondsSince(state.questionStartedAt);
    if (elapsedSeconds >= 30) {
      state.answers.push({ index, correct: false, elapsedSeconds: 30 });
      state.questionStartedAt = null;
      await client.query(`UPDATE game_attempts SET state = $2, updated_at = now() WHERE id = $1`, [attemptId, JSON.stringify(state)]);
      return { correct: false, elapsedSeconds: 30, timedOut: true };
    }
    state.answers.push({ index, correct, elapsedSeconds });
    state.questionStartedAt = null;

    await client.query(`UPDATE game_attempts SET state = $2, updated_at = now() WHERE id = $1`, [
      attemptId, JSON.stringify(state),
    ]);
    return { correct, elapsedSeconds };
  });
}

// ── Unscramble ──────────────────────────────────────────────────────────────

/** Reveal a word's clue: records the hint so the penalty can only apply once. */
async function revealUnscrambleClue(userId, attemptId, index) {
  return db.withTransaction(async (client) => {
    const attempt = await loadOwnedAttempt(client, userId, attemptId);
    if (!attempt) return { error: 'not_found' };
    if (attempt.status !== 'in_progress') return { error: 'closed' };
    if (secondsSince(attempt.started_at) >= TIME_LIMITS.unscramble) return { error: 'timeout' };
    if (!Number.isInteger(index) || index < 0 || index >= 5) return { error: 'invalid_index' };
    const publicContent = (
      await client.query(
        `SELECT public_content FROM challenge_games WHERE challenge_date = $1 AND game_type = $2`,
        [String(attempt.challenge_date).slice(0, 10), 'unscramble']
      )
    ).rows[0].public_content;
    const state = attempt.state || { solved: [], hinted: [] };
    if (!Array.isArray(publicContent.words) || index >= publicContent.words.length || state.solved.some((s) => s.index === index)) {
      return { error: 'invalid_index' };
    }
    const word = (publicContent.words || [])[index] || {};
    if (!state.hinted[index]) {
      state.hinted[index] = true; // idempotent: pressing again changes nothing
      await client.query(`UPDATE game_attempts SET state = $2 WHERE id = $1`, [attemptId, JSON.stringify(state)]);
    }
    return { clue: word.meaning || '', clueFa: word.meaning_fa || '' };
  });
}

/** Validate a solved Unscramble word; record its server-time remaining seconds. */
async function solveUnscrambleWord(userId, attemptId, index, word) {
  return db.withTransaction(async (client) => {
    const attempt = await loadOwnedAttempt(client, userId, attemptId);
    if (!attempt) return { error: 'not_found' };
    if (attempt.status !== 'in_progress') return { error: 'closed' };
    if (secondsSince(attempt.started_at) >= TIME_LIMITS.unscramble) return { error: 'timeout' };
    if (!Number.isInteger(index) || index < 0 || index >= scoring.UNSCRAMBLE_WORDS) return { error: 'invalid_index' };
    const secret = await secretFor(client, String(attempt.challenge_date).slice(0, 10), 'unscramble');
    const state = attempt.state || { solved: [], hinted: [] };
    if (!Array.isArray(secret.words) || index >= secret.words.length) return { error: 'invalid_index' };
    if (state.solved.some((s) => s.index === index)) return { error: 'already_solved' };
    if (state.solved.length >= secret.words.length) return { error: 'all_solved' };

    const correct = String(word).toLowerCase() === String(secret.words[index]).toLowerCase();
    if (!correct) return { correct: false };

    const elapsed = secondsSince(attempt.started_at);
    const remainingSeconds = clampRemaining('unscramble', elapsed);
    state.solved.push({ index, remainingSeconds, hintUsed: !!state.hinted[index] });
    await client.query(`UPDATE game_attempts SET state = $2, updated_at = now() WHERE id = $1`, [
      attemptId, JSON.stringify(state),
    ]);
    return { correct: true, remainingSeconds, hintUsed: !!state.hinted[index] };
  });
}

// ── Settlement ──────────────────────────────────────────────────────────────

function wordleInput(state, elapsed, secret) {
  const guesses = state.guesses || [];
  const validGuesses = new Set(guesses.map((g) => g.guess)).size;
  const solved = guesses.some((g) => (g.feedback || []).every((c) => c === CORRECT));
  if (solved) {
    return { solved: true, validGuesses, remainingSeconds: clampRemaining('wordle', elapsed) };
  }
  // Partial credit: distinct confirmed positions (green) and distinct present
  // letters that were never confirmed green (yellow).
  const greenPositions = new Set();
  const greenLetters = new Set();
  const yellowLetters = new Set();
  for (const g of guesses) {
    (g.feedback || []).forEach((code, i) => {
      if (code === CORRECT) {
        greenPositions.add(i);
        greenLetters.add(g.guess[i]);
      } else if (code === 1) {
        yellowLetters.add(g.guess[i]);
      }
    });
  }
  for (const l of greenLetters) yellowLetters.delete(l);
  return {
    solved: false,
    validGuesses,
    greenNew: greenPositions.size,
    yellowNew: yellowLetters.size,
  };
}

function unscrambleInput(state) {
  return { solvedWords: state.solved || [] };
}

function wordefInput(state) {
  return { answers: state.answers || [] };
}

/** Close an attempt without a score; it can never enter any ranking. */
async function abandonAttempt(userId, attemptId) {
  return db.withTransaction(async (client) => {
    const attempt = await loadOwnedAttempt(client, userId, attemptId);
    if (!attempt) return { error: 'not_found' };
    if (attempt.status === 'completed') return { error: 'closed' };
    if (attempt.status === 'abandoned') return { result: toAttemptView(attempt), alreadySettled: true };
    const updated = (
      await client.query(
        `UPDATE game_attempts SET status = 'abandoned', completed_at = now(), updated_at = now() WHERE id = $1 RETURNING *`,
        [attemptId]
      )
    ).rows[0];
    return { result: toAttemptView(updated) };
  });
}

/** Finalize an attempt: compute the official score and mark it completed. */
async function submitAttempt(userId, attemptId) {
  return db.withTransaction(async (client) => {
    const attempt = await loadOwnedAttempt(client, userId, attemptId);
    if (!attempt) return { error: 'not_found' };
    if (attempt.status === 'abandoned') return { error: 'closed' };
    if (attempt.status === 'in_progress' && attemptElapsed(attempt) < TIME_LIMITS[attempt.game_type]) {
      return { error: 'not_finished' };
    }
    // Idempotent: a settled attempt returns its stored result, never rescored.
    if (attempt.status === 'completed') {
      return { result: toAttemptView(attempt), alreadySettled: true };
    }
    const attemptState = attempt.state || initialState(attempt.game_type);
    const timedOut = attemptElapsed(attempt) >= TIME_LIMITS[attempt.game_type];
    if (attempt.game_type === 'wordle' && !timedOut) {
      const guesses = attemptState.guesses || [];
      const solved = guesses.some((entry) => entry.feedback.every((cell) => cell === CORRECT));
      if (!solved && guesses.length < scoring.WORDLE_MAX_GUESSES) return { error: 'not_finished' };
    }
    if (attempt.game_type === 'wordef' && !timedOut && (attemptState.answers || []).length < scoring.WORDEF_QUESTIONS) {
      return { error: 'not_finished' };
    }
    if (attempt.game_type === 'wordef' && timedOut && attemptState.questionStartedAt && secondsSince(attemptState.questionStartedAt) >= 30) {
      attemptState.answers.push({ index: attemptState.currentIndex, correct: false, elapsedSeconds: 30 });
      attemptState.questionStartedAt = null;
    }
    const unscrambleCount = (attemptState.solved || []).length;
    if (attempt.game_type === 'unscramble' && !timedOut && unscrambleCount < scoring.UNSCRAMBLE_WORDS) {
      return { error: 'not_finished' };
    }
    const state = attemptState;
    const elapsed = Math.min(
      TIME_LIMITS[attempt.game_type],
      attempt.elapsed_seconds != null ? attempt.elapsed_seconds : secondsSince(attempt.started_at)
    );
    if (attempt.game_type === 'wordle') {
      const answer = (await secretFor(client, String(attempt.challenge_date).slice(0, 10), 'wordle')).answer;
      for (const guess of state.guesses) {
        guess.feedback = evaluateGuess(answer, guess.guess);
      }
    }

    let input;
    if (attempt.game_type === 'wordle') {
      input = wordleInput(state, elapsed, null);
    } else if (attempt.game_type === 'wordef') {
      input = wordefInput(state);
    } else {
      input = unscrambleInput(state);
    }

    const settled = scoring.settle(attempt.game_type, input, attempt.historical);
    if (!attempt.counted) {
      settled.rawScore = 0;
      settled.adjustedScore = 0;
      settled.penaltyRate = 0;
      settled.historical = false;
    }
    const updated = (
      await client.query(
        `UPDATE game_attempts
            SET status = 'completed', completed_at = now(), elapsed_seconds = $2, state = $3,
                raw_score = $4, adjusted_score = $5, penalty_rate = $6,
                scoring_version = $7, updated_at = now()
          WHERE id = $1
          RETURNING *`,
        [
          attemptId, Math.round(elapsed), JSON.stringify(state), settled.rawScore, settled.adjustedScore,
          settled.penaltyRate, settled.scoringVersion,
        ]
      )
    ).rows[0];
    return { result: toAttemptView(updated) };
  });
}

module.exports = {
  evaluateGuess,
  getAttempt,
  startAttempt,
  wordleGuess,
  nextWordefQuestion,
  answerWordef,
  revealUnscrambleClue,
  solveUnscrambleWord,
  abandonAttempt,
  submitAttempt,
  toAttemptView,
  loadOwnedAttempt,
};