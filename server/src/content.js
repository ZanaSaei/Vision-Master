'use strict';

/**
 * Challenge content generation.
 *
 * The server is the authority for each day's challenge set. It reads the SAME
 * vocabulary files the app ships (single source of truth, no duplicated
 * dataset) and derives, deterministically and identically for every user:
 *
 *   * Wordle      — one answer word + the valid-guess set.
 *   * Unscramble  — five words (with their English/Persian meanings as clues).
 *   * Wordef      — ten questions (definition / synonym / antonym multiple
 *                   choice) WITH the correct answers kept server-side.
 *
 * Selection is fully deterministic from the Gregorian challenge date key
 * ("YYYY-MM-DD"), so the same day always yields the same set and consecutive
 * days do not repeat a word until the pool is exhausted.
 *
 * Data directory defaults to the Godot project's `data/` folder (two levels
 * up from server/src); override with VM_DATA_DIR.
 */

const fs = require('fs');
const path = require('path');

const DATA_DIR = path.resolve(
  process.env.VM_DATA_DIR || path.join(__dirname, '..', '..', 'data')
);

const WORDLE_MIN_LEN = 5;
const WORDLE_MAX_LEN = 7;
const SCRAMBLE_WORDS_PER_DAY = 5;
const WORDEF_QUESTIONS_PER_DAY = 10;
const WORDEF_OPTION_COUNT = 4;
const SECONDS_PER_DAY = 86400;

// ── small deterministic helpers ─────────────────────────────────────────────

/** FNV-1a style 32-bit hash of a string — stable across restarts. */
function hashString(str) {
  let h = 0x811c9dc5;
  for (let i = 0; i < str.length; i += 1) {
    h ^= str.charCodeAt(i);
    h = Math.imul(h, 0x01000193);
  }
  return h >>> 0;
}

/** mulberry32 PRNG — tiny, deterministic, seeded. */
function makeRng(seed) {
  let a = seed >>> 0;
  return function next() {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/** Deterministic Fisher–Yates shuffle (out of place). */
function seededShuffle(array, seed) {
  const out = array.slice();
  const rng = makeRng(seed);
  for (let i = out.length - 1; i > 0; i -= 1) {
    const j = Math.floor(rng() * (i + 1));
    const tmp = out[i];
    out[i] = out[j];
    out[j] = tmp;
  }
  return out;
}

/** Days since the Unix epoch for a "YYYY-MM-DD" key, at UTC midnight. */
function dayNumberFromKey(dateKey) {
  const [y, m, d] = dateKey.split('-').map((v) => parseInt(v, 10));
  return Math.floor(Date.UTC(y, m - 1, d) / (SECONDS_PER_DAY * 1000));
}

function readJson(relPath, fallback) {
  const full = path.join(DATA_DIR, relPath);
  try {
    return JSON.parse(fs.readFileSync(full, 'utf8'));
  } catch (err) {
    console.error(`[content] cannot read ${full}: ${err.message}`);
    return fallback;
  }
}

// ── file loaders (cached) ───────────────────────────────────────────────────

let _dictionary = null;
let _wordlePools = null;
let _scrambled = null;
let _extracted = null;

function dictionary() {
  if (_dictionary === null) {
    const raw = readJson('v_dictionary.json', []);
    _dictionary = Array.isArray(raw) ? raw : [];
  }
  return _dictionary;
}

const _WORD_RE = new RegExp(`^[a-z]{${WORDLE_MIN_LEN},${WORDLE_MAX_LEN}}$`);

function isUsableWord(w) {
  return typeof w === 'string' && w.length >= WORDLE_MIN_LEN && w === w.toLowerCase() && _WORD_RE.test(w);
}

function isExcludedType(entry) {
  const t = String(entry.word_type || '').toLowerCase();
  return ['abbreviation', 'proper', 'symbol', 'prefix', 'suffix'].some((bad) => t.includes(bad));
}

function synonymsOf(entry, key) {
  const g = entry && entry[key];
  return g && Array.isArray(g.en) ? g.en : [];
}

/**
 * Wordle pools, built EXACTLY like the client's WordleVocab:
 *   answers = dictionary head-words that pass the filter (sorted),
 *   valid   = every filtered head-word + synonym/antonym word (guesses).
 */
function wordlePools() {
  if (_wordlePools !== null) return _wordlePools;
  const valid = new Set();
  const answerSet = new Set();
  for (const entry of dictionary()) {
    if (!entry || typeof entry !== 'object') continue;
    const head = String(entry.word || '').toLowerCase();
    const entryUsable = isUsableWord(head) && !isExcludedType(entry);
    if (entryUsable) {
      valid.add(head);
      answerSet.add(head);
    }
    for (const key of ['synonyms', 'antonyms']) {
      for (const cand of synonymsOf(entry, key)) {
        if (isUsableWord(cand)) valid.add(cand);
      }
    }
  }
  const answers = Array.from(answerSet).sort();
  _wordlePools = { answers, valid };
  return _wordlePools;
}

function scrambledWords() {
  if (_scrambled !== null) return _scrambled;
  const raw = readJson('scrambled_words.json', { books: [] });
  const flat = [];
  for (const book of (raw.books || [])) {
    if (!book || typeof book !== 'object') continue;
    const bookNumber = parseInt(book.book, 10) || 0;
    for (const lesson of (book.lessons || [])) {
      const lessonNumber = parseInt(lesson.lesson, 10) || 0;
      for (const w of (lesson.words || [])) {
        const spelling = String(w.word || '').trim();
        if (!spelling) continue;
        flat.push({
          word: spelling,
          meaning: String(w.meaning || '').trim(),
          meaning_fa: String(w.meaning_fa || '').trim(),
          book: bookNumber,
          lesson: lessonNumber,
        });
      }
    }
  }
  _scrambled = flat;
  return _scrambled;
}

function extractedWords() {
  if (_extracted === null) {
    const raw = readJson('extracted_words.json', []);
    _extracted = Array.isArray(raw) ? raw : [];
  }
  return _extracted;
}

// ── Wordle ──────────────────────────────────────────────────────────────────

const WORDLE_SEED = 2917334520;

/** The Wordle answer for a date (deterministic, no repeats until exhausted). */
function wordleAnswerForDate(dateKey) {
  const { answers } = wordlePools();
  if (answers.length === 0) return '';
  const sequence = seededShuffle(answers, WORDLE_SEED);
  return sequence[dayNumberFromKey(dateKey) % sequence.length];
}

function isWordleGuess(word) {
  const { valid } = wordlePools();
  return valid.has(String(word || '').toLowerCase());
}

// ── Unscramble ──────────────────────────────────────────────────────────────

const SCRAMBLE_SEED = 20260214;

/** Five words for a date (windowed over a frozen shuffle of the bank). */
function unscrambleWordsForDate(dateKey) {
  const bank = scrambledWords();
  if (bank.length === 0) return [];
  const shuffled = seededShuffle(bank, SCRAMBLE_SEED);
  const count = Math.min(SCRAMBLE_WORDS_PER_DAY, shuffled.length);
  const start = (dayNumberFromKey(dateKey) * SCRAMBLE_WORDS_PER_DAY) % shuffled.length;
  const picked = [];
  for (let i = 0; i < count; i += 1) {
    picked.push(shuffled[(start + i) % shuffled.length]);
  }
  return picked;
}

// ── Wordef ──────────────────────────────────────────────────────────────────

/** Port of the client's MeaningQuizQuestionBuilder (definition/syn/ant). */
function buildMeaningPool() {
  const words = extractedWords();
  const definitionByWord = {};
  const synonymsByWord = {};
  const antonymsByWord = {};
  const synonymTerms = new Set();
  const antonymTerms = new Set();
  const definitions = new Set();

  for (const entry of words) {
    const word = String(entry.word || '').trim();
    const def = cleanText(String(entry.meaning_en || ''));
    if (!word || !def) continue;
    const key = word.toLowerCase();
    const syn = dedupe(synonymsOf(entry, 'synonyms'));
    const ant = dedupe(synonymsOf(entry, 'antonyms'));
    definitionByWord[key] = def;
    synonymsByWord[key] = syn;
    antonymsByWord[key] = ant;
    definitions.add(def);
    for (const t of syn) synonymTerms.add(t);
    for (const t of ant) antonymTerms.add(t);
  }

  const pool = [];
  const optionSources = {
    meaning: () => Array.from(definitions),
    synonym: () => Array.from(synonymTerms),
    antonym: () => Array.from(antonymTerms),
  };

  for (const entry of words) {
    const word = String(entry.word || '').trim();
    const meaning = cleanText(String(entry.meaning_en || ''));
    if (!word || !meaning) continue;
    const key = word.toLowerCase();
    const syn = (synonymsByWord[key] || []).filter((t) => t.toLowerCase() !== key);
    const ant = (antonymsByWord[key] || []).filter((t) => t.toLowerCase() !== key);
    const candidates = [];
    if (syn.length > 0) candidates.push({ kind: 'synonym', answer: syn[0] });
    if (ant.length > 0) candidates.push({ kind: 'antonym', answer: ant[0] });
    candidates.push({ kind: 'meaning', answer: meaning });

    for (const cand of candidates) {
      let source = optionSources[cand.kind]().filter(
        (t) => t.toLowerCase() !== cand.answer.toLowerCase() && t.toLowerCase() !== key
      );
      if (cand.kind === 'meaning' && source.length < WORDEF_OPTION_COUNT - 1) {
        source = Array.from(definitions).filter(
          (t) => t.toLowerCase() !== cand.answer.toLowerCase()
        );
      }
      const options = dedupe([cand.answer, ...source]).slice(0, WORDEF_OPTION_COUNT);
      if (options.length < WORDEF_OPTION_COUNT) continue;
      pool.push({
        kind: cand.kind,
        word,
        prompt: cand.answer,
        answer: cand.answer,
        options,
        meaning_fa: String(entry.meaning_fa || ''),
      });
    }
  }
  return pool;
}

let _meaningPool = null;

function meaningPool() {
  if (_meaningPool === null) _meaningPool = buildMeaningPool();
  return _meaningPool;
}

/**
 * Ten Wordef questions for a date, each with its options shuffled
 * deterministically and crucially its `answer` retained server-side.
 */
function wordefQuestionsForDate(dateKey) {
  const pool = meaningPool();
  if (pool.length === 0) return [];
  const rng = makeRng(hashString('wordef:' + dateKey));
  // Deterministic pick of distinct questions.
  const indices = pool.map((_, i) => i);
  for (let i = indices.length - 1; i > 0; i -= 1) {
    const j = Math.floor(rng() * (i + 1));
    const tmp = indices[i];
    indices[i] = indices[j];
    indices[j] = tmp;
  }
  const count = Math.min(WORDEF_QUESTIONS_PER_DAY, indices.length);
  const chosen = [];
  for (let i = 0; i < count; i += 1) {
    const q = pool[indices[i]];
    const options = seededShuffle(q.options, hashString(dateKey + ':' + i + ':' + q.word));
    chosen.push({
      kind: q.kind,
      word: q.word,
      prompt: q.prompt,
      answer: q.answer,
      options,
      meaning_fa: q.meaning_fa,
    });
  }
  return chosen;
}

// ── shared helpers ──────────────────────────────────────────────────────────

function cleanText(value) {
  let s = String(value || '').trim();
  while (s.length > 0 && ['.', '!', '?'].includes(s[s.length - 1])) {
    s = s.slice(0, -1).trim();
  }
  return s;
}

function dedupe(list) {
  const seen = new Set();
  const out = [];
  for (const item of list) {
    const key = String(item).trim().toLowerCase();
    if (!key || seen.has(key)) continue;
    seen.add(key);
    out.push(String(item).trim());
  }
  return out;
}

/**
 * The public (client-safe) view of a day's challenge: everything the client
 * needs to PLAY, with every secret removed.
 *   * Wordle: wordLength only (never the answer).
 *   * Wordef: questions with options, but NO `answer`.
 */
function publicChallengeForDate(dateKey) {
  const answer = wordleAnswerForDate(dateKey);
  const words = unscrambleWordsForDate(dateKey).map((w) => ({
    // Only meaning shown to the player; the word itself is scrambled in-game.
    meaning: w.meaning,
    meaning_fa: w.meaning_fa,
  }));
  const wordef = wordefQuestionsForDate(dateKey).map((q, index) => ({
    index,
    kind: q.kind,
    word: q.word,
    prompt: q.prompt,
    options: q.options,
  }));
  return {
    date: dateKey,
    wordle: { wordLength: answer.length },
    unscramble: { words },
    wordef: { questions: wordef },
  };
}

module.exports = {
  DATA_DIR,
  hashString,
  makeRng,
  seededShuffle,
  dayNumberFromKey,
  wordlePools,
  wordleAnswerForDate,
  isWordleGuess,
  scrambledWords,
  unscrambleWordsForDate,
  meaningPool,
  wordefQuestionsForDate,
  publicChallengeForDate,
  SCRAMBLE_WORDS_PER_DAY,
  WORDEF_QUESTIONS_PER_DAY,
};