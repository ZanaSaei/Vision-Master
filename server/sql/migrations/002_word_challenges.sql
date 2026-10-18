-- ============================================================================
-- Migration 002 — Daily word-game challenges, scoring, attempts, leaderboards.
--
-- NON-DESTRUCTIVE: every statement is CREATE ... IF NOT EXISTS. Nothing here
-- drops, truncates, or rewrites an existing table, so the auth / progress /
-- content tables from schema.sql are untouched and this file is safe to run
-- repeatedly (it is idempotent).
--
-- Rollback: because nothing existing is modified, rollback is simply
--   DROP TABLE IF EXISTS game_attempts, challenge_games, challenge_days CASCADE;
--   DROP VIEW  IF EXISTS daily_scores;
-- (Only run that if you really intend to discard all challenge history.)
-- ============================================================================

-- ── A. Daily challenge calendar ─────────────────────────────────────────────
-- One row per canonical Gregorian challenge date. Guarantees every user plays
-- the same challenge set for a date and that the three games roll over
-- together (the row is created atomically per date).
CREATE TABLE IF NOT EXISTS challenge_days (
    challenge_date   DATE PRIMARY KEY,
    -- Bumped if the day's content or the rules behind it ever change.
    content_version  INTEGER NOT NULL DEFAULT 1,
    scoring_version  INTEGER NOT NULL DEFAULT 1,
    -- Frozen Jalali date of this challenge date, so the UI never has to guess.
    jalali_year      INTEGER,
    jalali_month     INTEGER,
    jalali_day       INTEGER,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── B. Per-day, per-game challenge content ──────────────────────────────────
-- `public_content` is what a client may see while playing; `secret_content`
-- holds answer keys and is NEVER serialised to a client before settlement.
CREATE TABLE IF NOT EXISTS challenge_games (
    challenge_date   DATE NOT NULL REFERENCES challenge_days(challenge_date) ON DELETE CASCADE,
    game_type        TEXT NOT NULL CHECK (game_type IN ('wordle', 'wordef', 'unscramble')),
    public_content   JSONB NOT NULL DEFAULT '{}'::jsonb,
    secret_content   JSONB NOT NULL DEFAULT '{}'::jsonb,
    scoring_version  INTEGER NOT NULL DEFAULT 1,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (challenge_date, game_type)
);

-- ── C. Game attempts ────────────────────────────────────────────────────────
-- One COUNTED attempt per (user, challenge date, game type) — enforced by the
-- unique constraint below, not by the client. Practice replays are recorded
-- with counted = false and are excluded from every aggregate.
CREATE TABLE IF NOT EXISTS game_attempts (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    challenge_date   DATE NOT NULL,
    game_type        TEXT NOT NULL CHECK (game_type IN ('wordle', 'wordef', 'unscramble')),
    -- A counted leaderboard attempt (true) or an unranked practice replay.
    counted          BOOLEAN NOT NULL DEFAULT true,
    status           TEXT NOT NULL DEFAULT 'in_progress'
                     CHECK (status IN ('in_progress', 'completed', 'abandoned')),
    -- Server-owned timing. elapsed_seconds is what scoring uses.
    started_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at     TIMESTAMPTZ,
    elapsed_seconds  INTEGER,
    -- True when the challenge date was already in the past when this attempt
    -- began; frozen at start so crossing midnight cannot change the rules.
    historical       BOOLEAN NOT NULL DEFAULT false,
    penalty_rate     NUMERIC(5,4) NOT NULL DEFAULT 0,
    -- Full gameplay state needed to reproduce / verify the score:
    -- Wordle guesses + feedback, Wordef answers + server timings, hints used.
    state            JSONB NOT NULL DEFAULT '{}'::jsonb,
    raw_score        INTEGER,
    adjusted_score   INTEGER,
    scoring_version  INTEGER NOT NULL DEFAULT 1,
    -- Client-supplied key so a retried "start"/"submit" is idempotent.
    idempotency_key  TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Exactly one counted attempt per user / date / game. A partial unique index
-- lets an unlimited number of practice (counted = false) attempts coexist.
CREATE UNIQUE INDEX IF NOT EXISTS game_attempts_counted_unique
    ON game_attempts (user_id, challenge_date, game_type)
    WHERE counted;

-- Idempotency: a repeated POST with the same key cannot create a second row.
CREATE UNIQUE INDEX IF NOT EXISTS game_attempts_idempotency_unique
    ON game_attempts (user_id, idempotency_key)
    WHERE idempotency_key IS NOT NULL;

-- Lookup indexes: a user's history, and leaderboard aggregation per date.
CREATE INDEX IF NOT EXISTS game_attempts_user_date_idx
    ON game_attempts (user_id, challenge_date);

CREATE INDEX IF NOT EXISTS game_attempts_leaderboard_idx
    ON game_attempts (challenge_date, game_type, adjusted_score)
    WHERE counted AND status = 'completed';

CREATE INDEX IF NOT EXISTS game_attempts_completed_lifetime_idx
    ON game_attempts (user_id)
    WHERE counted AND status = 'completed';

-- ── D. Aggregates ───────────────────────────────────────────────────────────
-- One row per user per data (their official score total + completed count).
-- Kept as a VIEW (not a redundant table) so it can never drift from the
-- attempts it summarises.
CREATE OR REPLACE VIEW daily_scores AS
SELECT
    user_id,
    challenge_date,
    SUM(adjusted_score) FILTER (WHERE status = 'completed') AS total_score,
    COUNT(*) FILTER (WHERE status = 'completed')           AS completed_games,
    SUM(elapsed_seconds) FILTER (WHERE status = 'completed') AS total_elapsed
FROM game_attempts
WHERE counted AND status = 'completed'
GROUP BY user_id, challenge_date;