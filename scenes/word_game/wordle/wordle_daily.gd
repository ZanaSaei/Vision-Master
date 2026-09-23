class_name WordleDaily
extends RefCounted
## ============================================================
##  WORDLE DAILY — deterministic daily word engine.
##
##  TIMEZONE STRATEGY:
##  The daily cycle runs on UTC calendar days (midnight-to-midnight UTC).
##  A fixed reference timezone is deliberately chosen over the device's
##  local timezone so every user, on every device, gets the same daily
##  word on the same day.
##
##  SELECTION ALGORITHM (fully deterministic, no local state needed):
##    1. day_index = floor(unix_time_utc / 86400)  — changes exactly at
##       UTC midnight, one increment per calendar day.
##    2. The eligible word pool is sorted, then shuffled ONCE with a
##       FIXED seed (not randomize()). The shuffled sequence is identical
##       on every device and every session.
##    3. daily_word = shuffled_sequence[day_index % pool_size].
##
##  Consequences:
##    * The same date always yields the same word (derivable from the
##      date + master list alone — nothing is stored as source of truth).
##    * Consecutive days yield consecutive entries of the shuffled
##      sequence — no word repeats until the entire pool is exhausted.
##    * After exhaustion, the next cycle replays the same fixed order.
##
##  SERVER HOOK (anti-cheat, future):
##  All time reads go through `now_utc_unix()`. When a server becomes
##  available, replace its body with a trusted HTTP time response
##  (e.g. API.get("/time").server_unix) and fall back to the device
##  clock while offline. Nothing else in the engine needs to change.
## ============================================================

const SHUFFLE_SEED := 2917334520  # fixed — never call randomize() here
const SECONDS_PER_DAY := 86400

static var _sequence_cache: Array[String] = []


## Trusted "now" as a UTC unix timestamp in seconds.
## REPLACE THE BODY with a server time fetch to harden against clock
## tampering (see class docs). The fallback keeps the game offline-safe.
static func now_utc_unix() -> int:
	return int(Time.get_unix_time_from_system())


## Days since the Unix epoch, in UTC. The daily puzzle identifier.
static func day_index() -> int:
	@warning_ignore("integer_division")
	return now_utc_unix() / SECONDS_PER_DAY


## Human-readable puzzle id, e.g. "wordle-2026-09-15" (UTC date).
static func puzzle_id() -> String:
	var days := day_index()
	var dt := Time.get_datetime_dict_from_unix_time(days * SECONDS_PER_DAY)
	return "wordle-%04d-%02d-%02d" % [dt.year, dt.month, dt.day]


## The answer for the current UTC day. Deterministic and reproducible.
static func get_daily_word() -> String:
	var sequence := _shuffled_sequence()
	if sequence.is_empty():
		push_error("WordleDaily: word pool is empty")
		return ""
	return sequence[day_index() % sequence.size()]


## Seconds left until the daily cycle rolls over (next UTC midnight), i.e.
## until a brand-new word is in play. Always in 1..SECONDS_PER_DAY.
static func seconds_until_next_word() -> int:
	return (day_index() + 1) * SECONDS_PER_DAY - now_utc_unix()


## Human countdown to the next word, e.g. "۳ ساعت و ۱۲ دقیقه".
## Digits are converted to Persian numerals here so every call-site reads
## the same; pass the result through MenuStyle.persian_digits() if that
## ever changes.
static func format_until_next_word() -> String:
	var seconds := seconds_until_next_word()
	var minutes: int = int(seconds / 60.0)
	var hours: int = int(minutes / 60.0)
	minutes = minutes % 60
	var parts: Array[String] = []
	if hours > 0:
		parts.append("%d ساعت" % hours)
	if minutes > 0:
		parts.append("%d دقیقه" % minutes)
	if parts.is_empty():
		parts.append("کمتر از یک دقیقه")
	return MenuStyle.persian_digits(" و ".join(parts))


## The whole pool in its fixed shuffled order (cached per session).
## The shuffle is seeded deterministically, so every device produces
## the exact same sequence from the same sorted pool.
static func _shuffled_sequence() -> Array[String]:
	if not _sequence_cache.is_empty():
		return _sequence_cache
	# Answers come from the entry-word pool: the full pool also holds derived
	# forms (e.g. "quitted") that are fair guesses but poor daily puzzles.
	var sequence := WordleVocab.get_answer_pool().duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = SHUFFLE_SEED
	# Fisher–Yates shuffle (deterministic for the fixed seed).
	for i in range(sequence.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: String = sequence[i]
		sequence[i] = sequence[j]
		sequence[j] = tmp
	_sequence_cache = sequence
	return _sequence_cache
