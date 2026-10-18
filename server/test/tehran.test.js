'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  challengeDateKey,
  isValidIsoDate,
  isPastDate,
  isFutureDate,
  isToday,
  nextTehranMidnight,
} = require('../src/tehran');

test('tehran: instant maps to the Tehran calendar date, not UTC', () => {
  // 20:00 UTC is 23:30 Tehran the same day.
  assert.equal(challengeDateKey(new Date('2026-03-21T20:00:00Z')), '2026-03-21');
});

test('tehran: challenge date rolls over at local midnight (20:30 UTC)', () => {
  assert.equal(challengeDateKey(new Date('2026-03-21T20:29:00Z')), '2026-03-21');
  assert.equal(challengeDateKey(new Date('2026-03-21T20:30:00Z')), '2026-03-22');
});

test('tehran: rollover is independent of the caller time zone', () => {
  const instant = new Date('2026-03-21T21:00:00Z'); // 00:30 Tehran on the 22nd
  // Two different "local" representations of the same instant agree, because
  // the zone is fixed to Asia/Tehran.
  assert.equal(challengeDateKey(instant, 'Asia/Tehran'), '2026-03-22');
  assert.equal(challengeDateKey(instant), '2026-03-22');
});

test('tehran: next midnight is 20:30 UTC for a spring day', () => {
  const next = nextTehranMidnight(new Date('2026-03-21T10:00:00Z'));
  assert.equal(next.toISOString(), '2026-03-21T20:30:00.000Z');
});

test('tehran: next midnight ignores formatter-millisecond truncation', () => {
  const next = nextTehranMidnight(new Date('2026-03-21T10:00:00.750Z'));
  assert.equal(next.toISOString(), '2026-03-21T20:30:00.000Z');
});

test('tehran: validates ISO date keys', () => {
  assert.equal(isValidIsoDate('2026-03-21'), true);
  assert.equal(isValidIsoDate('2026-02-30'), false); // no such day
  assert.equal(isValidIsoDate('2026-13-01'), false);
  assert.equal(isValidIsoDate('21-03-2026'), false);
  assert.equal(isValidIsoDate('hello'), false);
});

test('tehran: past/future/today relative to a fixed now', () => {
  const now = new Date('2026-03-21T10:00:00Z'); // 2026-03-21 in Tehran
  assert.equal(isPastDate('2026-03-20', now), true);
  assert.equal(isPastDate('2026-03-21', now), false);
  assert.equal(isFutureDate('2026-03-22', now), true);
  assert.equal(isFutureDate('2026-03-21', now), false);
  assert.equal(isToday('2026-03-21', now), true);
  assert.equal(isToday('2026-03-20', now), false);
});