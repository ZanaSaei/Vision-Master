-- Vision Master schema. Safe to run repeatedly.

CREATE TABLE IF NOT EXISTS users (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone                   TEXT UNIQUE NOT NULL,
    subscription_tier       TEXT NOT NULL DEFAULT 'free',
    subscription_expires_at TIMESTAMPTZ,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- One active OTP row per phone. Codes are stored hashed.
CREATE TABLE IF NOT EXISTS otp_codes (
    phone       TEXT PRIMARY KEY,
    code_hash   TEXT NOT NULL,
    expires_at  TIMESTAMPTZ NOT NULL,
    attempts    INTEGER NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Refresh tokens are stored hashed and rotated on every refresh.
CREATE TABLE IF NOT EXISTS sessions (
    refresh_hash  TEXT PRIMARY KEY,
    user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    expires_at    TIMESTAMPTZ NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- One opaque progress blob per user. jsonb means the app can evolve its
-- progress shape without any server-side migration.
CREATE TABLE IF NOT EXISTS progress (
    user_id     UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    data        JSONB NOT NULL DEFAULT '{}'::jsonb,
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS sessions_user_idx ON sessions (user_id);
