'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  wordleScore,
  unscrambleWordScore,
  unscrambleScore,
  wordefQuestionScore,
  wordefScore,
  applyHistoricalPenalty,
  settle,
  WORDLE_MAX,
  WORDLE_FAIL_CAP,
  UNSCRAMBLE_MAX,
  WORDEF_MAX,
  SCORING_VERSION,
} = require('../src/scoring');

// ── Wordle ──────────────────────────────────────────────────────────────────
test('wordle: solved in one guess with full time is 1000', () => {
  assert.equal(wordleScore({ solved: true, validGuesses: 1, remainingSeconds: 180 }), 1000);
});

test('wordle: solved in three guesses with full time is 900', () => {
  assert.equal(wordleScore({ solved: true, validGuesses: 3, remainingSeconds: 180 }), 900);
});

test('wordle: solved in six guesses with full time is 750', () => {
  assert.equal(wordleScore({ solved: true, validGuesses: 6, remainingSeconds: 180 }), 750);
});

test('wordle: solved on the sixth guess near timeout is ~500', () => {
  assert.equal(wordleScore({ solved: true, validGuesses: 6, remainingSeconds: 0 }), 500);
});

test('wordle: solved never exceeds 1000 even with over-full time', () => {
  assert.equal(wordleScore({ solved: true, validGuesses: 0, remainingSeconds: 9999 }), 1000);
  assert.equal(wordleScore({ solved: true, validGuesses: 1, remainingSeconds: 180 }), WORDLE_MAX);
});

test('wordle: unsuccessful with valid feedback awards partial points', () => {
  // 3 distinct valid guesses = 45, 2 green = 30, 3 yellow = 30 -> 105
  assert.equal(
    wordleScore({ solved: false, validGuesses: 3, greenNew: 2, yellowNew: 3 }),
    105
  );
});

test('wordle: unsuccessful is capped at 250', () => {
  assert.equal(
    wordleScore({ solved: false, validGuesses: 6, greenNew: 100, yellowNew: 100 }),
    WORDLE_FAIL_CAP
  );
});

test('wordle: timeout partial score keeps point for valid guesses', () => {
  // A timeout with no new information still credits the guesses made.
  assert.equal(wordleScore({ solved: false, validGuesses: 6 }), 90);
});

test('wordle: partial score is a non-negative integer', () => {
  const s = wordleScore({ solved: false, validGuesses: 0, greenNew: 0, yellowNew: 0 });
  assert.equal(s, 0);
  assert.equal(Number.isInteger(s), true);
});

// ── Unscramble ──────────────────────────────────────────────────────────────
test('unscramble: five correct words at full time is 1000', () => {
  const words = Array.from({ length: 5 }, () => ({ remainingSeconds: 180, hintUsed: false }));
  assert.equal(unscrambleScore(words), 1000);
  assert.equal(unscrambleScore(words), UNSCRAMBLE_MAX);
});

test('unscramble: one correct word at full time is 200', () => {
  assert.equal(unscrambleWordScore(180, false), 200);
});

test('unscramble: hint penalty floors the word score to 75%', () => {
  assert.equal(unscrambleWordScore(180, true), 150); // floor(200 * 0.75)
});

test('unscramble: a hinted word reduces the total, applied once', () => {
  const words = [
    { remainingSeconds: 180, hintUsed: true },
    { remainingSeconds: 180, hintUsed: false },
    { remainingSeconds: 180, hintUsed: false },
    { remainingSeconds: 180, hintUsed: false },
    { remainingSeconds: 180, hintUsed: false },
  ];
  assert.equal(unscrambleScore(words), 150 + 200 * 4); // 950
});

test('unscramble: some correct words followed by timeout keep their scores', () => {
  const words = [
    { remainingSeconds: 90, hintUsed: false },
    { remainingSeconds: 90, hintUsed: false },
  ];
  assert.equal(unscrambleScore(words), (160 + 20) * 2); // 360
});

test('unscramble: no words solved is zero', () => {
  assert.equal(unscrambleScore([]), 0);
});

test('unscramble: never exceeds 1000', () => {
  const words = Array.from({ length: 9 }, () => ({ remainingSeconds: 180, hintUsed: false }));
  assert.equal(unscrambleScore(words), UNSCRAMBLE_MAX);
});

// ── Wordef ──────────────────────────────────────────────────────────────────
test('wordef: ten fast correct answers is 1000', () => {
  const answers = Array.from({ length: 10 }, () => ({ correct: true, elapsedSeconds: 0 }));
  assert.equal(wordefScore(answers), 1000);
  assert.equal(wordefScore(answers), WORDEF_MAX);
});

test('wordef: ten slow correct answers is ~800', () => {
  const answers = Array.from({ length: 10 }, () => ({ correct: true, elapsedSeconds: 9 }));
  assert.equal(wordefScore(answers), 800);
});

test('wordef: single fast correct question is 100', () => {
  assert.equal(wordefQuestionScore(true, 0), 100);
});

test('wordef: speed factor is clamped at zero and one', () => {
  assert.equal(wordefQuestionScore(true, 0), 100); // factor 1
  assert.equal(wordefQuestionScore(true, 1000), 80); // factor 0
  assert.equal(wordefQuestionScore(true, -5), 100); // negative elapsed clamps to 1
});

test('wordef: incorrect or unanswered questions earn zero', () => {
  assert.equal(wordefQuestionScore(false, 0), 0);
  assert.equal(wordefScore([{ correct: true, elapsedSeconds: 0 }, { correct: false, elapsedSeconds: 1 }]), 100);
});

test('wordef: timeout halfway through keeps answered points only', () => {
  const answers = [
    { correct: true, elapsedSeconds: 0 },
    { correct: true, elapsedSeconds: 0 },
    { correct: true, elapsedSeconds: 0 },
    { correct: true, elapsedSeconds: 0 },
    { correct: true, elapsedSeconds: 0 },
    // five unanswered (never presented / not answered) -> zero
  ];
  assert.equal(wordefScore(answers), 500);
});

// ── Historical penalty ──────────────────────────────────────────────────────
test('historical: 800 raw becomes 720 adjusted', () => {
  assert.equal(applyHistoricalPenalty(800, true), 720);
});

test('historical: same-day score is unchanged', () => {
  assert.equal(applyHistoricalPenalty(800, false), 800);
});

test('historical: zero stays zero and result is integer', () => {
  const v = applyHistoricalPenalty(0, true);
  assert.equal(v, 0);
  assert.equal(Number.isInteger(v), true);
});

test('historical: rounding floors rather than rounds', () => {
  // 5 * 0.9 = 4.5 -> 4
  assert.equal(applyHistoricalPenalty(5, true), 4);
});

// ── Settlement ──────────────────────────────────────────────────────────────
test('settle: returns raw, adjusted, penalty rate and scoring version', () => {
  const result = settle('wordle', { solved: true, validGuesses: 3, remainingSeconds: 180 }, true);
  assert.deepEqual(result, {
    rawScore: 900,
    adjustedScore: 810,
    penaltyRate: 0.1,
    historical: true,
    scoringVersion: SCORING_VERSION,
  });
});

test('settle: today has no penalty', () => {
  const result = settle('wordef', { answers: [{ correct: true, elapsedSeconds: 0 }] }, false);
  assert.equal(result.rawScore, 100);
  assert.equal(result.adjustedScore, 100);
  assert.equal(result.penaltyRate, 0);
  assert.equal(result.historical, false);
});