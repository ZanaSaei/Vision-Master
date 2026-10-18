'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const content = require('../src/content');

const DATE = '2026-03-21';

test('content: wordle pools are non-empty and answers are valid guesses', () => {
  const { answers } = content.wordlePools();
  assert.ok(answers.length > 50, 'expected a large wordle answer pool');
  assert.equal(content.isWordleGuess(answers[0]), true);
});

test('content: the daily Wordle answer is deterministic and in the pool', () => {
  const a = content.wordleAnswerForDate(DATE);
  const b = content.wordleAnswerForDate(DATE);
  assert.equal(a, b);
  assert.equal(content.isWordleGuess(a), true);
  assert.ok(a.length >= 5 && a.length <= 7);
});

test('content: the Wordle answer rotates without repeating until exhausted', () => {
  const seen = new Set();
  for (let i = 0; i < 15; i += 1) {
    const day = `2026-04-${String(i + 1).padStart(2, '0')}`;
    seen.add(content.wordleAnswerForDate(day));
  }
  assert.equal(seen.size, 15); // no repeat across 15 consecutive days
});

test('content: unscramble deals five distinct words per day', () => {
  const words = content.unscrambleWordsForDate(DATE);
  assert.equal(words.length, 5);
  const unique = new Set(words.map((w) => w.word));
  assert.equal(unique.size, 5);
});

test('content: unscramble is deterministic per date', () => {
  assert.deepEqual(
    content.unscrambleWordsForDate(DATE),
    content.unscrambleWordsForDate(DATE)
  );
});

test('content: wordef builds ten questions with four options each', () => {
  const qs = content.wordefQuestionsForDate(DATE);
  assert.equal(qs.length, 10);
  for (const q of qs) {
    assert.equal(q.options.length, 4);
    assert.ok(q.options.includes(q.answer), 'correct answer must be among options');
    assert.equal(new Set(q.options).size, 4, 'options must be distinct');
  }
});

test('content: public challenge never leaks secret answers', () => {
  const pub = content.publicChallengeForDate(DATE);
  assert.equal(pub.wordle.answer, undefined);
  assert.equal(typeof pub.wordle.wordLength, 'number');
  assert.equal(pub.unscramble.words.length, 5);
  for (const w of pub.unscramble.words) {
    assert.equal(w.word, undefined, 'the unscramble target word must stay server-side');
  }
  for (const q of pub.wordef.questions) {
    assert.equal(q.answer, undefined, 'the wordef answer key must stay server-side');
    assert.equal(q.options.length, 4);
  }
});

test('content: server really knows the answer that the public view hides', () => {
  const date = '2026-06-01';
  const secret = content.wordefQuestionsForDate(date);
  const pub = content.publicChallengeForDate(date);
  // Same questions, but the public projection dropped the answer field.
  assert.equal(secret.length, pub.wordef.questions.length);
  for (let i = 0; i < secret.length; i += 1) {
    assert.equal(secret[i].prompt, pub.wordef.questions[i].prompt);
    assert.ok(secret[i].answer);
  }
});