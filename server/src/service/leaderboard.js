'use strict';

/**
 * Global leaderboards — computed entirely server-side from counted, completed
 * attempts. The Godot client never ranks cached or fabricated users.
 *
 * Ranking (per the spec's tie-breakers, in order):
 *   1. Higher total adjusted score.
 *   2. More completed counted games in the period.
 *   3. Lower aggregate server-recorded completion time.
 *   4. Stable final order by user id.
 */

const db = require('../db');
const { challengeDateKey } = require('../tehran');

const MAX_LIMIT = 100;

/** Privacy-preserving display name from a phone number. */
function displayName(phone) {
  const s = String(phone || '');
  if (s.length < 7) return s;
  return `${s.slice(0, 4)}***${s.slice(-3)}`;
}

function clampPage(limit, offset) {
  const lim = Math.min(MAX_LIMIT, Math.max(1, parseInt(limit, 10) || 50));
  const off = Math.max(0, parseInt(offset, 10) || 0);
  return { lim, off };
}

/** Today's leaderboard (Tehran date): sum of the three games' adjusted scores. */
async function dailyLeaderboard(userId, now = new Date(), limit, offset) {
  const { lim, off } = clampPage(limit, offset);
  const dateKey = challengeDateKey(now);

  const rows = (
    await db.query(
      `SELECT ds.user_id, u.phone, ds.total_score, ds.completed_games, ds.total_elapsed
         FROM daily_scores ds
         JOIN users u ON u.id = ds.user_id
        WHERE ds.challenge_date = $1 AND ds.completed_games > 0
        ORDER BY ds.total_score DESC, ds.completed_games DESC,
                 ds.total_elapsed ASC, ds.user_id ASC
        LIMIT $2 OFFSET $3`,
      [dateKey, lim, off]
    )
  ).rows;

  const entries = rows.map((r, i) => ({
    rank: off + i + 1,
    name: displayName(r.phone),
    score: parseInt(r.total_score, 10) || 0,
    completedGames: parseInt(r.completed_games, 10) || 0,
    isSelf: r.user_id === userId,
  }));

  return { period: 'daily', date: dateKey, entries, self: await selfRow(userId, dateKey) };
}

/** Lifetime leaderboard: sum of adjusted scores over the user's whole history. */
async function lifetimeLeaderboard(userId, limit, offset) {
  const { lim, off } = clampPage(limit, offset);

  const rows = (
    await db.query(
      `SELECT ga.user_id, u.phone,
              SUM(ga.adjusted_score) AS total_score,
              COUNT(*) AS completed_games,
              SUM(ga.elapsed_seconds) AS total_elapsed
         FROM game_attempts ga
         JOIN users u ON u.id = ga.user_id
        WHERE ga.counted AND ga.status = 'completed'
        GROUP BY ga.user_id, u.phone
        ORDER BY total_score DESC, completed_games DESC,
                 total_elapsed ASC, ga.user_id ASC
        LIMIT $1 OFFSET $2`,
      [lim, off]
    )
  ).rows;

  const entries = rows.map((r, i) => ({
    rank: off + i + 1,
    name: displayName(r.phone),
    score: parseInt(r.total_score, 10) || 0,
    completedGames: parseInt(r.completed_games, 10) || 0,
    isSelf: r.user_id === userId,
  }));

  return { period: 'lifetime', entries, self: await selfLifetime(userId) };
}

/** The caller's own daily rank, even when outside the visible page. */
async function selfRow(userId, dateKey) {
  const row = (
    await db.query(
      `WITH ranked AS (
         SELECT ds.user_id, ds.total_score, ds.completed_games, ds.total_elapsed,
                u.phone,
                RANK() OVER (
                  ORDER BY ds.total_score DESC, ds.completed_games DESC,
                           ds.total_elapsed ASC, ds.user_id ASC
                ) AS rank
           FROM daily_scores ds JOIN users u ON u.id = ds.user_id
          WHERE ds.challenge_date = $1 AND ds.completed_games > 0
       )
       SELECT * FROM ranked WHERE user_id = $2`,
      [dateKey, userId]
    )
  ).rows[0];
  if (!row) return null;
  return {
    rank: parseInt(row.rank, 10),
    name: displayName(row.phone),
    score: parseInt(row.total_score, 10) || 0,
    completedGames: parseInt(row.completed_games, 10) || 0,
    isSelf: true,
  };
}

/** The caller's own lifetime rank, even when outside the visible page. */
async function selfLifetime(userId) {
  const row = (
    await db.query(
      `WITH totals AS (
         SELECT ga.user_id, u.phone,
                SUM(ga.adjusted_score) AS total_score,
                COUNT(*) AS completed_games,
                SUM(ga.elapsed_seconds) AS total_elapsed
           FROM game_attempts ga JOIN users u ON u.id = ga.user_id
          WHERE ga.counted AND ga.status = 'completed'
          GROUP BY ga.user_id, u.phone
       ),
       ranked AS (
         SELECT *, RANK() OVER (
                  ORDER BY total_score DESC, completed_games DESC,
                           total_elapsed ASC, user_id ASC
                ) AS rank
           FROM totals
       )
       SELECT * FROM ranked WHERE user_id = $1`,
      [userId]
    )
  ).rows[0];
  if (!row) return null;
  return {
    rank: parseInt(row.rank, 10),
    name: displayName(row.phone),
    score: parseInt(row.total_score, 10) || 0,
    completedGames: parseInt(row.completed_games, 10) || 0,
    isSelf: true,
  };
}

module.exports = { dailyLeaderboard, lifetimeLeaderboard, displayName };