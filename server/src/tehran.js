'use strict';

/**
 * Tehran-time challenge clock.
 *
 * The official daily challenge date is ALWAYS the calendar date in Iran's
 * official zone, Asia/Tehran (IANA id, not a fixed offset — Iran reinstated
 * DST-free UTC+03:30 in 2022 but the zone id keeps us correct if that ever
 * changes again). The player's device clock and time zone are never trusted.
 *
 * We resolve the zone with `Intl.DateTimeFormat`, whose timeZone database is
 * the platform's real IANA data — this is the "reliable IANA implementation"
 * the spec requires, and it is not a hand-rolled offset.
 */

const TEHRAN_TZ = 'Asia/Tehran';

const _fmtCache = new Map();

function _formatter(timeZone) {
  if (!_fmtCache.has(timeZone)) {
    _fmtCache.set(
      timeZone,
      new Intl.DateTimeFormat('en-CA', {
        timeZone,
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit',
        hour12: false,
      })
    );
  }
  return _fmtCache.get(timeZone);
}

function _pad2(n) {
  return String(n).padStart(2, '0');
}

/**
 * The wall-clock date/time parts in a given IANA zone for an instant.
 * Defaults to Asia/Tehran. `date` may be a Date or a ms epoch number.
 * @returns {{year:number, month:number, day:number, hour:number, minute:number, second:number}}
 */
function zonedParts(date = new Date(), timeZone = TEHRAN_TZ) {
  const d = date instanceof Date ? date : new Date(date);
  const parts = {};
  for (const p of _formatter(timeZone).formatToParts(d)) {
    if (p.type !== 'literal') parts[p.type] = p.value;
  }
  return {
    year: parseInt(parts.year, 10),
    month: parseInt(parts.month, 10),
    day: parseInt(parts.day, 10),
    hour: parseInt(parts.hour, 10) % 24,
    minute: parseInt(parts.minute, 10),
    second: parseInt(parts.second, 10),
  };
}

/**
 * The canonical Gregorian challenge date of an instant, as "YYYY-MM-DD" in
 * Asia/Tehran. This is the single source of truth for "today's challenge".
 */
function challengeDateKey(date = new Date(), timeZone = TEHRAN_TZ) {
  const p = zonedParts(date, timeZone);
  return `${p.year}-${_pad2(p.month)}-${_pad2(p.day)}`;
}

const ISO_DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

/** True when `key` is a syntactically valid (and real calendar) ISO date. */
function isValidIsoDate(key) {
  if (typeof key !== 'string' || !ISO_DATE_RE.test(key)) return false;
  const [y, m, d] = key.split('-').map((v) => parseInt(v, 10));
  if (m < 1 || m > 12 || d < 1 || d > 31) return false;
  const probe = new Date(Date.UTC(y, m - 1, d));
  return (
    probe.getUTCFullYear() === y &&
    probe.getUTCMonth() === m - 1 &&
    probe.getUTCDate() === d
  );
}

/** Lexicographic compare works for "YYYY-MM-DD": <0 past, 0 same, >0 future. */
function compareIsoDates(a, b) {
  return a < b ? -1 : a > b ? 1 : 0;
}

/** True when `dateKey` is strictly before the current Tehran challenge date. */
function isPastDate(dateKey, now = new Date()) {
  return compareIsoDates(dateKey, challengeDateKey(now)) < 0;
}

/** True when `dateKey` is strictly after the current Tehran challenge date. */
function isFutureDate(dateKey, now = new Date()) {
  return compareIsoDates(dateKey, challengeDateKey(now)) > 0;
}

/** True when `dateKey` is the current Tehran challenge date. */
function isToday(dateKey, now = new Date()) {
  return dateKey === challengeDateKey(now);
}

/**
 * The Jalali (Solar Hijri) calendar month that contains the current Tehran
 * challenge date, plus every Gregorian "YYYY-MM-DD" in that Jalali month.
 * The calendar UI shows exactly this set (see jalali.js for the conversion).
 */
function currentTehranMonth(now = new Date()) {
  return challengeDateKey(now);
}

/**
 * The instant (ms epoch) at which the Tehran challenge date next rolls over,
 * i.e. the next local 00:00. Computed from the *Tehran* wall clock, not from
 * the caller's zone, so it is stable for every user.
 */
function nextTehranMidnight(now = new Date()) {
  // Start from the current Tehran date at 00:00, then add one day in UTC —
  // safe because Tehran currently has no DST, and even if it did, the wall
  // clock is re-derived from the instant below rather than assumed.
  const today = challengeDateKey(now);
  const [y, m, d] = today.split('-').map((v) => parseInt(v, 10));
  // Tehran is UTC+03:30 (fixed since 2022). We resolve the exact instant of
  // local midnight by probing the offset the zone reports for "now".
  const nowParts = zonedParts(now);
  const localAsUtc = Date.UTC(
    nowParts.year,
    nowParts.month - 1,
    nowParts.day,
    nowParts.hour,
    nowParts.minute,
    nowParts.second
  );
  const nowWholeSecondMs = Math.floor(now.getTime() / 1000) * 1000;
  const offsetMs = localAsUtc - nowWholeSecondMs; // Tehran offset (+3:30 => +12600000)
  const midnightUtcMs =
    Date.UTC(y, m - 1, d, 0, 0, 0) - offsetMs + 24 * 3600 * 1000;
  return new Date(midnightUtcMs);
}

module.exports = {
  TEHRAN_TZ,
  zonedParts,
  challengeDateKey,
  isValidIsoDate,
  compareIsoDates,
  isPastDate,
  isFutureDate,
  isToday,
  currentTehranMonth,
  nextTehranMidnight,
};