'use strict';

/**
 * Gregorian <-> Jalali (Solar Hijri) conversion.
 *
 * This is a faithful port of the well-established, widely-used algorithm by
 * Kazimierz M. Borkowski (the same one behind the `jalaali-js` package), not a
 * hand-rolled approximation. The spec explicitly requires a tested conversion,
 * so we reuse the proven calendar maths rather than inventing our own.
 *
 * Years are valid for the full range the algorithm supports (roughly
 * 1178..3178 Jalali), which comfortably covers the app's lifetime.
 */

function div(a, b) {
  return Math.trunc(a / b);
}

function mod(a, b) {
  return a - Math.trunc(a / b) * b;
}

// Jalali year boundaries where the leap-year pattern changes.
const BREAKS = [
  -61, 9, 38, 199, 426, 686, 756, 818, 1111, 1181, 1210, 1635, 2060, 2097,
  2192, 2262, 2324, 2394, 2456, 3178,
];

/**
 * Core Jalali-year calculation. Returns { leap, gy, march } where `leap` is
 * the year's position in the 33-year cycle (0 means a leap year) and `march`
 * is the day-of-March on which Farvardin 1 falls.
 */
function jalCal(jy) {
  const bl = BREAKS.length;
  const gy = jy + 621;
  let leapJ = -14;
  let jp = BREAKS[0];
  let jm;
  let jump = 0;
  let n;

  if (jy < jp || jy >= BREAKS[bl - 1]) {
    throw new Error('Invalid Jalali year ' + jy);
  }

  for (let i = 1; i < bl; i += 1) {
    jm = BREAKS[i];
    jump = jm - jp;
    if (jy < jm) break;
    leapJ = leapJ + div(jump, 33) * 8 + div(mod(jump, 33), 4);
    jp = jm;
  }
  n = jy - jp;

  leapJ = leapJ + div(n, 33) * 8 + div(mod(n, 33) + 3, 4);
  if (mod(jump, 33) === 4 && jump - n === 4) leapJ += 1;

  const leapG = div(gy, 4) - div((div(gy, 100) + 1) * 3, 4) - 150;
  const march = 20 + leapJ - leapG;

  if (jump - n < 6) n = n - jump + div(jump + 4, 33) * 33;
  let leap = mod(mod(n + 1, 33) - 1, 4);
  if (leap === -1) leap = 4;

  return { leap, gy, march };
}

/** Julian Day Number from a Gregorian date. */
function g2d(gy, gm, gd) {
  let d =
    div((gy + div(gm - 8, 6) + 100100) * 1461, 4) +
    div(153 * mod(gm + 9, 12) + 2, 5) +
    gd -
    34840408;
  d = d - div(div(gy + 100100 + div(gm - 8, 6), 100) * 3, 4) + 752;
  return d;
}

/** Gregorian date from a Julian Day Number. */
function d2g(jdn) {
  let j = 4 * jdn + 139361631;
  j = j + div(div(4 * jdn + 183187720, 146097) * 3, 4) * 4 - 3908;
  const i = div(mod(j, 1461), 4) * 5 + 308;
  const gd = div(mod(i, 153), 5) + 1;
  const gm = mod(div(i, 153), 12) + 1;
  const gy = div(j, 1461) - 100100 + div(8 - gm, 6);
  return { gy, gm, gd };
}

/** Julian Day Number from a Jalali date. */
function j2d(jy, jm, jd) {
  const r = jalCal(jy);
  return g2d(r.gy, 3, r.march) + (jm - 1) * 31 - div(jm, 7) * (jm - 7) + jd - 1;
}

/** Jalali date from a Julian Day Number. */
function d2j(jdn) {
  const gy = d2g(jdn).gy;
  let jy = gy - 621;
  const r = jalCal(jy);
  const jdn1f = g2d(gy, 3, r.march);
  let k = jdn - jdn1f;
  if (k >= 0) {
    if (k <= 185) {
      return { jy, jm: 1 + div(k, 31), jd: mod(k, 31) + 1 };
    }
    k -= 186;
  } else {
    jy -= 1;
    k += 179;
    if (r.leap === 1) k += 1;
  }
  return { jy, jm: 7 + div(k, 30), jd: mod(k, 30) + 1 };
}

/** Gregorian (gy, gm, gd) -> Jalali { jy, jm, jd }. */
function toJalaali(gy, gm, gd) {
  return d2j(g2d(gy, gm, gd));
}

/** Jalali (jy, jm, jd) -> Gregorian { gy, gm, gd }. */
function toGregorian(jy, jm, jd) {
  return d2g(j2d(jy, jm, jd));
}

/** True when the given Jalali year is a leap year (Esfand has 30 days). */
function isLeapJalaaliYear(jy) {
  return jalCal(jy).leap === 0;
}

/** Number of days in a Jalali month (1..12). */
function jalaaliMonthLength(jy, jm) {
  if (jm <= 6) return 31;
  if (jm <= 11) return 30;
  return isLeapJalaaliYear(jy) ? 30 : 29;
}

/**
 * The Gregorian ISO string "YYYY-MM-DD" of a Jalali date. Useful for turning
 * a day cell of the Persian calendar back into the canonical date key.
 */
function jalaaliToIsoKey(jy, jm, jd) {
  const g = toGregorian(jy, jm, jd);
  const p2 = (n) => String(n).padStart(2, '0');
  return `${g.gy}-${p2(g.gm)}-${p2(g.gd)}`;
}

/** Jalali { jy, jm, jd } of a Gregorian ISO "YYYY-MM-DD" date key. */
function isoKeyToJalaali(isoKey) {
  const [y, m, d] = isoKey.split('-').map((v) => parseInt(v, 10));
  return toJalaali(y, m, d);
}

module.exports = {
  toJalaali,
  toGregorian,
  isLeapJalaaliYear,
  jalaaliMonthLength,
  jalaaliToIsoKey,
  isoKeyToJalaali,
};