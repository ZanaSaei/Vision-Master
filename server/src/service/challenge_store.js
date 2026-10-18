'use strict';

/**
 * Challenge provisioning + calendar reads.
 *
 * The store owns the "one frozen challenge set per date for everyone" rule:
 * ensureChallengeDay() generates the day's Wordle/Wordef/Unscramble content
 * from the project vocabulary exactly once and atomically, so no user can ever
 * receive a new Wordle date alongside the previous date's other games.
 */

const db = require('../db');
const content = require('../content');
const scoring = require('../scoring');
const { challengeDateKey, isFutureDate, isValidIsoDate } = require('../tehran');
const { toJalaali, jalaaliToIsoKey, jalaaliMonthLength } = require('../jalali');

const GAME_TYPES = ['wordle', 'wordef', 'unscramble'];

/** ISO date string from a pg DATE (which may arrive as a JS Date). */
function isoKey(value) {
  if (value instanceof Date) {
    const y = value.getUTCFullYear();
    const m = String(value.getUTCMonth() + 1).padStart(2, '0');
    const d = String(value.getUTCDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
  }
  return String(value);
}

/** Insert (if missing) the challenge_days + challenge_games rows for a date. */
async function ensureChallengeDay(client, dateKey) {
  if (!isValidIsoDate(dateKey)) throw new Error('bad_date');
  const [y, m, d] = dateKey.split('-').map((v) => parseInt(v, 10));
  const j = toJalaali(y, m, d);

  await client.query(
    `INSERT INTO challenge_days
       (challenge_date, content_version, scoring_version, jalali_year, jalali_month, jalali_day)
     VALUES ($1, 1, $2, $3, $4, $5)
     ON CONFLICT (challenge_date) DO NOTHING`,
    [dateKey, scoring.SCORING_VERSION, j.jy, j.jm, j.jd]
  );
  const gameRows = (
    await client.query(`SELECT game_type FROM challenge_games WHERE challenge_date = $1`, [dateKey])
  ).rows;
  const existingTypes = new Set(gameRows.map((row) => row.game_type));
  if (GAME_TYPES.every((gameType) => existingTypes.has(gameType))) return;
  const answer = content.wordleAnswerForDate(dateKey);
  const words = content.unscrambleWordsForDate(dateKey);
  const questions = content.wordefQuestionsForDate(dateKey);

  const games = [
    { type: 'wordle', public: { wordLength: answer.length }, secret: { answer } },
    {
      type: 'unscramble',
      public: { words: words.map((w, index) => {
        const letters = Array.from(w.word);
        const shuffled = content.seededShuffle(letters, content.hashString(`${dateKey}:unscramble:${index}:${w.word}`));
        let scrambled = shuffled.join('');
        if (scrambled.toLowerCase() === w.word.toLowerCase() && letters.length > 1) scrambled = shuffled.slice(1).concat(shuffled[0]).join('');
        return { scrambledWord: scrambled, meaning: w.meaning, meaning_fa: w.meaning_fa };
      }) },
      secret: { words: words.map((w) => w.word) },
    },
    {
      type: 'wordef',
      public: {
        questions: questions.map((q, index) => ({
          index, kind: q.kind, word: q.word, prompt: q.prompt, options: q.options,
        })),
      },
      secret: { answers: questions.map((q) => q.answer) },
    },
  ];

  if (!answer || words.length !== scoring.UNSCRAMBLE_WORDS || questions.length !== scoring.WORDEF_QUESTIONS) {
    throw new Error('challenge_content_unavailable');
  }

  for (const g of games) {
    if (existingTypes.has(g.type)) continue;
    await client.query(
      `INSERT INTO challenge_games
         (challenge_date, game_type, public_content, secret_content, scoring_version)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (challenge_date, game_type) DO NOTHING`,
      [dateKey, g.type, JSON.stringify(g.public), JSON.stringify(g.secret), scoring.SCORING_VERSION]
    );
  }
}

/** The public + secret content of one date/game (provisioning it first). */
async function loadChallengeGame(dateKey, gameType) {
  return db.withTransaction(async (client) => {
    await ensureChallengeDay(client, dateKey);
    return (
      await client.query(
        `SELECT public_content, secret_content
           FROM challenge_games WHERE challenge_date = $1 AND game_type = $2`,
        [dateKey, gameType]
      )
    ).rows[0];
  });
}

/** This user's official totals for every day of the current Jalali month. */
async function calendarForUser(userId, now = new Date()) {
  const todayKey = challengeDateKey(now);
  const [y, m] = todayKey.split('-').map((v) => parseInt(v, 10));
  const j = toJalaali(y, m, 1);
  const length = jalaaliMonthLength(j.jy, j.jm);
  const days = [];
  for (let d = 1; d <= length; d += 1) days.push(jalaaliToIsoKey(j.jy, j.jm, d));

  const rows = (
    await db.query(
      `SELECT challenge_date, adjusted_score, status
         FROM game_attempts
        WHERE user_id = $1 AND counted
          AND challenge_date >= $2 AND challenge_date <= $3`,
      [userId, days[0], days[days.length - 1]]
    )
  ).rows;

  const byDate = {};
  for (const r of rows) {
    const key = isoKey(r.challenge_date);
    if (!byDate[key]) byDate[key] = { total: 0, completed: 0 };
    if (r.status === 'completed') {
      byDate[key].total += r.adjusted_score || 0;
      byDate[key].completed += 1;
    }
  }

  const cells = days.map((dateKey, i) => {
    const agg = byDate[dateKey] || { total: 0, completed: 0 };
    return {
      date: dateKey,
      jalali: { year: j.jy, month: j.jm, day: i + 1 },
      totalScore: agg.total,
      completedGames: agg.completed,
      future: isFutureDate(dateKey, now),
      today: dateKey === todayKey,
    };
  });

  return {
    jalali: { year: j.jy, month: j.jm },
    today: todayKey,
    monthLength: length,
    days: cells,
  };
}

/** Per-game scores + completion for one date, plus the lifetime total. */
async function summaryForUser(userId, dateKey) {
  const perGame = {};
  for (const g of GAME_TYPES) {
    perGame[g] = { score: 0, completed: false, inProgress: false, counted: false };
  }
  const rows = (
    await db.query(
      `SELECT game_type, status, counted, adjusted_score
         FROM game_attempts
        WHERE user_id = $1 AND challenge_date = $2`,
      [userId, dateKey]
    )
  ).rows;
  for (const r of rows) {
    if (!r.counted) continue;
    perGame[r.game_type] = {
      score: r.status === 'completed' ? r.adjusted_score || 0 : 0,
      completed: r.status === 'completed',
      inProgress: r.status === 'in_progress',
      counted: true,
    };
  }
  const dayTotal = GAME_TYPES.reduce((sum, g) => sum + perGame[g].score, 0);
  const completedCount = GAME_TYPES.filter((g) => perGame[g].completed).length;

  const lifetimeRow = (
    await db.query(
      `SELECT COALESCE(SUM(adjusted_score), 0) AS total
         FROM game_attempts
        WHERE user_id = $1 AND counted AND status = 'completed'`,
      [userId]
    )
  ).rows[0];

  return {
    date: dateKey,
    games: perGame,
    dayTotal,
    completedCount,
    lifetimeTotal: parseInt(lifetimeRow.total, 10) || 0,
  };
}

module.exports = {
  GAME_TYPES,
  isoKey,
  ensureChallengeDay,
  loadChallengeGame,
  calendarForUser,
  summaryForUser,
};