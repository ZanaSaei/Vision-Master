'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  toJalaali,
  toGregorian,
  isLeapJalaaliYear,
  jalaaliMonthLength,
  jalaaliToIsoKey,
  isoKeyToJalaali,
} = require('../src/jalali');

test('jalali: Nowruz 1405 is 2026-03-21', () => {
  assert.deepEqual(toJalaali(2026, 3, 21), { jy: 1405, jm: 1, jd: 1 });
});

test('jalali: round-trips Gregorian <-> Jalali', () => {
  for (const [gy, gm, gd] of [[2026, 3, 21], [2024, 3, 20], [1990, 1, 1], [2030, 12, 31], [2026, 9, 15]]) {
    const j = toJalaali(gy, gm, gd);
    const g = toGregorian(j.jy, j.jm, j.jd);
    assert.deepEqual([g.gy, g.gm, g.gd], [gy, gm, gd]);
  }
});

test('jalali: toGregorian(1405,1,1) is 2026-03-21', () => {
  assert.deepEqual(toGregorian(1405, 1, 1), { gy: 2026, gm: 3, gd: 21 });
});

test('jalali: 1403 is a leap year (Esfand has 30 days), 1404 is not', () => {
  assert.equal(isLeapJalaaliYear(1403), true);
  assert.equal(jalaaliMonthLength(1403, 12), 30);
  assert.equal(isLeapJalaaliYear(1404), false);
  assert.equal(jalaaliMonthLength(1404, 12), 29);
});

test('jalali: month lengths follow the 6x31 / 5x30 pattern', () => {
  assert.equal(jalaaliMonthLength(1405, 1), 31);
  assert.equal(jalaaliMonthLength(1405, 6), 31);
  assert.equal(jalaaliMonthLength(1405, 7), 30);
  assert.equal(jalaaliMonthLength(1405, 11), 30);
});

test('jalali: ISO key <-> Jalali conversions', () => {
  assert.equal(jalaaliToIsoKey(1405, 1, 1), '2026-03-21');
  assert.deepEqual(isoKeyToJalaali('2026-03-21'), { jy: 1405, jm: 1, jd: 1 });
});

test('jalali: every day of a month maps to a distinct ISO key (round-trip)', () => {
  const seen = new Set();
  for (let d = 1; d <= jalaaliMonthLength(1405, 12); d += 1) {
    const key = jalaaliToIsoKey(1405, 12, d);
    assert.equal(seen.has(key), false, 'duplicate day key ' + key);
    seen.add(key);
    assert.deepEqual(isoKeyToJalaali(key), { jy: 1405, jm: 12, jd: d });
  }
});