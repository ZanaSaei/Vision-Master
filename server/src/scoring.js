'use strict';

/**
 * Authoritative scoring formulas for the three daily word games.
 *
 * Every official score is an INTEGER and is computed HERE, on the server.
 * A client-submitted score is never trusted. All tunables live in the
 * CONSTANTS block below so the numbers can be adjusted without touching any
 * gameplay code, and every result is stamped with SCORING_VERSION so a future
 * change to a formula never silently rewrites historical scores.
 */

const SCORING_VERSION = 1;

// ── Wordle ──────────────────────────────────────────────────────────────────
const WORDLE_MAX = 1000;
const WORDLE_TIME_LIMIT = 180; // seconds
const WORDLE_MAX_GUESSES = 6;
const WORDLE_SOLVE_BASE = 500;
const WORDLE_GUESS_BONUS = 50; // per unused guess
const WORDLE_TIME_BONUS = 250; // bonus at full remaining time
const WORDLE_FAIL_CAP = 250;
const WORDLE_PARTIAL_GUESS = 15; // per distinct valid guess
const WORDLE_PARTIAL_GREEN = 15; // per newly confirmed correct position
const WORDLE_PARTIAL_YELLOW = 10; // per newly confirmed present letter

// ── Unscramble ──────────────────────────────────────────────────────────────
const UNSCRAMBLE_WORDS = 5;
const UNSCRAMBLE_TIME_LIMIT = 180; // seconds, overall
const UNSCRAMBLE_MAX = 1000;
const UNSCRAMBLE_WORD_BASE = 160;
const UNSCRAMBLE_WORD_TIME_BONUS = 40; // up to, at full remaining time
const UNSCRAMBLE_HINT_MULTIPLIER = 0.75; // -25% when the clue was used

// ── Wordef ──────────────────────────────────────────────────────────────────
const WORDEF_QUESTIONS = 10;
const WORDEF_TIME_LIMIT = 90; // seconds, overall
const WORDEF_MAX = 1000;
const WORDEF_QUESTION_BASE = 80;
const WORDEF_QUESTION_SPEED_BONUS = 20; // up to, at zero elapsed
const WORDEF_SPEED_BENCHMARK = 9; // seconds; speed bonus reaches 0 here

// ── Historical (previous-day) penalty ───────────────────────────────────────
const HISTORICAL_PENALTY_RATE = 0.1;

function clamp(value, lo, hi) {
  return Math.min(hi, Math.max(lo, value));
}

function clamp01(v) {
  return clamp(v, 0, 1);
}

function toInt(v, fallback = 0) {
  const n = Number(v);
  return Number.isFinite(n) ? Math.trunc(n) : fallback;
}

function toNumber(v, fallback = 0) {
  const n = Number(v);
  return Number.isFinite(n) ? n : fallback;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Wordle
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Raw Wordle score.
 *
 * A solved word:  500 + 50 * (6 - validGuesses) + floor(250 * remaining/180)
 * An unsolved run: 15*validGuesses + 15*greenNew + 10*yellowNew, capped at 250.
 *
 * `input`:
 *   solved: boolean
 *   validGuesses: number of DISTINCT valid guesses made (0..6)
 *   remainingSeconds: server-measured seconds left when the game settled
 *   greenNew / yellowNew: distinct newly-revealed correct/present positions
 *                         (only used when unsolved)
 */
function wordleScore(input = {}) {
  const validGuesses = clamp(toInt(input.validGuesses), 0, WORDLE_MAX_GUESSES);
  if (input.solved) {
    const remainingFrac = clamp01(toNumber(input.remainingSeconds) / WORDLE_TIME_LIMIT);
    const raw =
      WORDLE_SOLVE_BASE +
      WORDLE_GUESS_BONUS * (WORDLE_MAX_GUESSES - validGuesses) +
      Math.floor(WORDLE_TIME_BONUS * remainingFrac);
    return clamp(Math.floor(raw), 0, WORDLE_MAX);
  }
  const raw =
    WORDLE_PARTIAL_GUESS * validGuesses +
    WORDLE_PARTIAL_GREEN * clamp(toInt(input.greenNew), 0, 100) +
    WORDLE_PARTIAL_YELLOW * clamp(toInt(input.yellowNew), 0, 100);
  return clamp(Math.floor(raw), 0, WORDLE_FAIL_CAP);
}

// ─────────────────────────────────────────────────────────────────────────────
//  Unscramble
// ─────────────────────────────────────────────────────────────────────────────

/** Raw score of ONE solved Unscramble word (hint halves the speed benefit). */
function unscrambleWordScore(remainingSeconds, hintUsed = false) {
  const remainingFrac = clamp01(toNumber(remainingSeconds) / UNSCRAMBLE_TIME_LIMIT);
  let score = UNSCRAMBLE_WORD_BASE + Math.floor(UNSCRAMBLE_WORD_TIME_BONUS * remainingFrac);
  if (hintUsed) score = Math.floor(score * UNSCRAMBLE_HINT_MULTIPLIER);
  return score;
}

/**
 * Raw Unscramble score for a full run.
 * `solvedWords`: array of { remainingSeconds, hintUsed } — one entry per word
 * the player actually solved, in the order they were solved.
 */
function unscrambleScore(solvedWords = []) {
  let raw = 0;
  for (const w of solvedWords) {
    raw += unscrambleWordScore(w.remainingSeconds, !!w.hintUsed);
  }
  return clamp(raw, 0, UNSCRAMBLE_MAX);
}

// ─────────────────────────────────────────────────────────────────────────────
//  Wordef
// ─────────────────────────────────────────────────────────────────────────────

/** Raw score of ONE Wordef question: 80 base + up to 20 speed points. */
function wordefQuestionScore(correct, elapsedSeconds) {
  if (!correct) return 0;
  const speed = clamp01(1 - toNumber(elapsedSeconds) / WORDEF_SPEED_BENCHMARK);
  return WORDEF_QUESTION_BASE + Math.floor(WORDEF_QUESTION_SPEED_BONUS * speed);
}

/**
 * Raw Wordef score for a full run.
 * `answers`: array of { correct, elapsedSeconds } — one per presented question.
 * Unanswered questions simply have correct === false.
 */
function wordefScore(answers = []) {
  let raw = 0;
  for (const a of answers) {
    raw += wordefQuestionScore(!!a.correct, a.elapsedSeconds);
  }
  return clamp(raw, 0, WORDEF_MAX);
}

// ─────────────────────────────────────────────────────────────────────────────
//  Historical penalty + settlement
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Apply the 10% historical penalty to a RAW score. The server decides whether
 * an attempt is historical (its challenge date was already past when the
 * attempt began); a client-supplied flag is never trusted.
 */
function applyHistoricalPenalty(rawScore, historical) {
  const raw = toInt(rawScore);
  return historical ? Math.floor(raw * (1 - HISTORICAL_PENALTY_RATE)) : raw;
}

/**
 * Raw score for a game type from a settled input object.
 *   wordle     -> { solved, validGuesses, remainingSeconds, greenNew, yellowNew }
 *   unscramble -> { solvedWords: [{ remainingSeconds, hintUsed }] }
 *   wordef     -> { answers: [{ correct, elapsedSeconds }] }
 */
function rawScoreFor(gameType, input = {}) {
  switch (gameType) {
    case 'wordle':
      return wordleScore(input);
    case 'unscramble':
      return unscrambleScore(input.solvedWords || []);
    case 'wordef':
      return wordefScore(input.answers || []);
    default:
      throw new Error('Unknown game type: ' + gameType);
  }
}

/**
 * Settle an attempt: compute raw + adjusted score and the metadata to persist.
 * Returns { rawScore, adjustedScore, penaltyRate, historical, scoringVersion }.
 */
function settle(gameType, input, historical) {
  const rawScore = rawScoreFor(gameType, input);
  const adjustedScore = applyHistoricalPenalty(rawScore, historical);
  return {
    rawScore,
    adjustedScore,
    penaltyRate: historical ? HISTORICAL_PENALTY_RATE : 0,
    historical: !!historical,
    scoringVersion: SCORING_VERSION,
  };
}

module.exports = {
  SCORING_VERSION,
  WORDLE_MAX,
  WORDLE_TIME_LIMIT,
  WORDLE_MAX_GUESSES,
  WORDLE_FAIL_CAP,
  UNSCRAMBLE_WORDS,
  UNSCRAMBLE_TIME_LIMIT,
  UNSCRAMBLE_MAX,
  WORDEF_QUESTIONS,
  WORDEF_TIME_LIMIT,
  WORDEF_MAX,
  WORDEF_SPEED_BENCHMARK,
  HISTORICAL_PENALTY_RATE,
  wordleScore,
  unscrambleWordScore,
  unscrambleScore,
  wordefQuestionScore,
  wordefScore,
  applyHistoricalPenalty,
  rawScoreFor,
  settle,
};