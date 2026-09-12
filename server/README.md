# Vision Master — Server

Node.js + PostgreSQL backend for the Vision Master Godot app. It provides:

- **Phone OTP auth** (SMS delivered through [Kavenegar](https://kavenegar.com)).
- **Progress sync** — one opaque JSON blob per user (XP, unlocked grammar units,
  saved words, review stats, …).
- **Content delivery** — serves the heavy media (`assets/audio/**`,
  `assets/images/**`) that is *not* shipped inside the APK, plus a manifest the
  app uses to know what exists and how big it is.

Designed to run on [Liara](https://liara.ir) (or any Node 18+ host with a
Postgres database and a writable media directory / S3-compatible bucket).

## Endpoints

| Method | Path              | Auth   | Body / Notes                                             |
| ------ | ----------------- | ------ | -------------------------------------------------------- |
| POST   | `/auth/request-otp` | –   | `{ "phone": "0912..." }` → sends a code via Kavenegar    |
| POST   | `/auth/verify-otp`  | –   | `{ "phone", "code" }` → `{ access_token, refresh_token, user_id, subscription }` |
| POST   | `/auth/refresh`     | –   | `{ "refresh_token" }` → new token pair (rotating)        |
| POST   | `/auth/logout`      | Bearer | invalidates the refresh token                          |
| GET    | `/me`               | Bearer | `{ user_id, phone, subscription }`                       |
| GET    | `/progress`         | Bearer | `{ data: <blob>, updated_at }`                           |
| PUT    | `/progress`         | Bearer | `{ data: <blob> }` → upsert                              |
| GET    | `/content/manifest` | Bearer | `{ version, files: [{ path, size, sha256, book, lesson, url }] }` |
| GET    | `/content/<path>`   | Bearer | raw bytes (or 302 to a signed storage URL)               |
| GET    | `/health`           | –      | liveness probe                                           |

`<path>` is relative to the project root, e.g. `assets/audio/v1/l1/conversation.mp3`.

## Setup

1. `cp .env.example .env` and fill it in.
2. `npm install`
3. `npm run migrate`   (creates the schema)
4. Put the media tree under `MEDIA_ROOT` (mirrors the project layout:
   `MEDIA_ROOT/assets/audio/...`) and run `npm run manifest`
   (writes `MEDIA_ROOT/manifest.json`).
5. `npm start`

### `.env` keys

| Key                 | Meaning                                                        |
| ------------------- | -------------------------------------------------------------- |
| `PORT`              | HTTP port (Liara injects one; default 3000)                    |
| `DATABASE_URL`      | `postgres://user:pass@host:5432/db`                            |
| `JWT_SECRET`        | long random string used to sign access tokens                  |
| `ACCESS_TTL`        | access-token lifetime, seconds (default 3600)                  |
| `REFRESH_TTL`       | refresh-token lifetime, seconds (default 2592000 = 30 days)    |
| `OTP_TTL`           | OTP validity, seconds (default 120)                            |
| `OTP_MAX_ATTEMPTS`  | wrong-code attempts before the OTP is burned (default 5)       |
| `OTP_RATE_WINDOW`   | per-phone request window, seconds (default 60)                 |
| `KAVENEGAR_API_KEY` | Kavenegar API key                                              |
| `KAVENEGAR_TEMPLATE`| Kavenegar "verify lookup" template name                        |
| `KAVENEGAR_SENDER`  | optional sender line for the (non-template) fallback          |
| `MEDIA_ROOT`        | directory that holds the media tree + `manifest.json`          |

## Security notes

- OTP codes are stored **hashed** (sha256), never in plaintext, with an expiry
  and an attempt cap.
- Each phone can request a limited number of codes per window.
- Access tokens are short-lived JWTs; refresh tokens are random 256-bit strings
  stored **hashed** and rotated on every refresh.
- The Kavenegar API key never leaves the server.
- Always run behind HTTPS.
