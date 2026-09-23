class_name ScrambledDailyPicker
extends RefCounted
## ============================================================
##  DAILY WORD PICKER — the five words of today's مسابقه.
##
##  Deterministic by design: the same day must deal every player the same
##  five words, in the same order, so the bank is shuffled once with a fixed
##  seed and each day then claims its own fixed window of WORDS_PER_DAY
##  entries. Consecutive days therefore never overlap until the whole bank
##  has been walked through.
##
##  now_utc_unix() is the single clock hook — a server time could replace it
##  without touching anything else in the game.
## ============================================================

const WORDS_PER_DAY := 5
## Fixed on purpose: the daily order is frozen, never seeded from the clock.
const SHUFFLE_SEED := 20260214
const SECONDS_PER_DAY := 86400

static var _shuffled: Array = []
static var _shuffled_built := false


## The game's clock. UTC on purpose, like the rest of the app's daily logic.
static func now_utc_unix() -> int:
	return int(Time.get_unix_time_from_system())


## Days since the Unix epoch, UTC — the game's notion of "today".
static func day_index() -> int:
	return int(floor(float(now_utc_unix()) / float(SECONDS_PER_DAY)))


## Today's date as "YYYY-MM-DD" (UTC). Used as the save key of the daily
## score, so a day can never be recorded twice.
static func date_key() -> String:
	return Time.get_date_string_from_unix_time(now_utc_unix())


## Stable identifier of today's puzzle ("scrambled-2026-09-17").
static func puzzle_id() -> String:
	return "scrambled-%s" % date_key()


static func seconds_until_next_day() -> int:
	var now := now_utc_unix()
	var into_day := now - day_index() * SECONDS_PER_DAY
	return maxi(1, SECONDS_PER_DAY - into_day)


## "۵ ساعت و ۱۲ دقیقه" — how long the current challenge stays available.
static func time_left_text() -> String:
	var left := seconds_until_next_day()
	var hours := int(floor(float(left) / 3600.0))
	var minutes := int(floor(float(left % 3600) / 60.0))
	if hours > 0:
		return "%s ساعت و %s دقیقه" % [digits(hours), digits(minutes)]
	if minutes > 0:
		return "%s دقیقه" % digits(minutes)
	return "کمتر از یک دقیقه"


## Today's five words (fewer only when the bank is smaller than that).
static func pick() -> Array:
	var bank := _bank()
	if bank.is_empty():
		return []
	var count := mini(WORDS_PER_DAY, bank.size())
	var start := (day_index() * WORDS_PER_DAY) % bank.size()
	var picked: Array = []
	for i in count:
		picked.append(bank[(start + i) % bank.size()])
	return picked


## The word window of any given day, without touching the clock. Used by the
## tests to prove that the daily order is stable and never repeats within it.
static func pick_for_day(day: int) -> Array:
	var bank := _bank()
	if bank.is_empty():
		return []
	var count := mini(WORDS_PER_DAY, bank.size())
	var start := (day * WORDS_PER_DAY) % bank.size()
	var picked: Array = []
	for i in count:
		picked.append(bank[(start + i) % bank.size()])
	return picked


static func reset_cache() -> void:
	_shuffled = []
	_shuffled_built = false


## ------------------------------------------------------------ internals --
## The bank in its frozen daily order: shuffled once with SHUFFLE_SEED.
static func _bank() -> Array:
	if _shuffled_built:
		return _shuffled
	_shuffled_built = true
	_shuffled = ScrambledData.all_words().duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = SHUFFLE_SEED
	for i in range(_shuffled.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var held = _shuffled[i]
		_shuffled[i] = _shuffled[j]
		_shuffled[j] = held
	return _shuffled


## Persian numerals, so the countdown reads like the rest of the app. Kept
## local on purpose: the picker is data logic and must not need the UI layer
## (MenuStyle pulls in the Global autoload).
static func digits(value: int) -> String:
	var out := ""
	for ch in str(value):
		var code := ch.unicode_at(0)
		if code >= 48 and code <= 57:
			out += char(code + 1728)
		else:
			out += ch
	return out
