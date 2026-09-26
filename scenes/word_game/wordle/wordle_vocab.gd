class_name WordleVocab
extends RefCounted
## ============================================================
##  WORDLE VOCAB — vocabulary data layer for the Wordle game.
##
##  Loads data/v_dictionary.json exactly once per session, filters it
##  into a pool of valid game words, and exposes metadata lookups.
##
##  A valid GAME word must:
##    * be a single English word (letters only, no spaces / hyphens /
##      apostrophes / slashes / any punctuation)
##    * be at least 5 letters long
##    * not be a proper noun / abbreviation / phrase
##  Candidates come from the entry's main "word" plus every valid word
##  inside synonyms.en and antonyms.en. The final pool is deduplicated.
## ============================================================

const DICTIONARY_PATH := "res://data/v_dictionary.json"

## Supported Wordle answer/guess lengths.
const MIN_WORD_LENGTH := 5
const MAX_WORD_LENGTH := 7

## English-only alphabet guard: rejects spaces, hyphens, apostrophes,
## slashes, digits, accented letters, multi-word expressions, etc.
const _WORD_PATTERN := "^[a-z]{%d,%d}$" % [MIN_WORD_LENGTH, MAX_WORD_LENGTH]

## Cached processed data (built lazily on first access).
static var _word_set: Dictionary = {}
static var _word_pool: Array[String] = []
## Pool words that own a dictionary entry — the daily engine picks from these.
static var _answer_pool: Array[String] = []
## word -> the entry that IS this word (its own dictionary page).
static var _meta_index: Dictionary = {}
## word -> the first entry that mentioned it, whether as its own word or as
## one of its synonyms/antonyms. Only consulted when _meta_index has no
## answer, so a pool word always has something to show on the end card.
static var _origin_index: Dictionary = {}
## The filter regex, compiled once instead of once per candidate word.
static var _regex: RegEx = null
static var _loaded := false


## All eligible game words, sorted (stable order for the daily engine).
## Used to validate GUESSES: typing a derived form such as "quitted" is fine.
static func get_word_pool() -> Array[String]:
	_ensure_loaded()
	return _word_pool


## The subset of the pool that has a dictionary entry of its own — the words
## allowed to become a daily ANSWER.
##
## The full pool is right for guesses but too rough for answers: it also
## contains words that only appear as somebody else's synonym (derived and
## irregular forms like "quitted"), which make for a poor puzzle. Entry words
## are the dictionary's own head words, so they stay recognisable.
## Falls back to the whole pool if the dictionary somehow yields none.
static func get_answer_pool() -> Array[String]:
	_ensure_loaded()
	return _answer_pool if not _answer_pool.is_empty() else _word_pool


## True when `word` is a playable guess (in the processed dictionary).
static func is_valid_word(word: String) -> bool:
	_ensure_loaded()
	return _word_set.has(word.to_lower())


## Vocabulary entry (Dictionary) for a word, or {} when the word only
## entered the pool via a synonym/antonym with no entry of its own.
static func get_entry_meta(word: String) -> Dictionary:
	_ensure_loaded()
	return _meta_index.get(word.to_lower(), {})


## Vocabulary info for `word`, always giving the end card something useful:
##   exact       — `word` has a dictionary page of its own
##   !exact      — `word` only entered the pool through another entry's
##                 synonym/antonym list, so that entry is shown instead
##                 (previously such an answer rendered as "—" everywhere)
## Returns { "meta": Dictionary, "source_word": String, "exact": bool }.
static func get_word_info(word: String) -> Dictionary:
	_ensure_loaded()
	var lower := word.to_lower()
	if _meta_index.has(lower):
		return { "meta": _meta_index[lower], "source_word": lower, "exact": true }
	var origin: Dictionary = _origin_index.get(lower, {})
	if origin.is_empty():
		return { "meta": {}, "source_word": "", "exact": false }
	return {
		"meta": origin,
		"source_word": str(origin.get("word", "")),
		"exact": false,
	}


static func _ensure_loaded() -> void:
	if _loaded:
		return
	var raw: Array = _load_dictionary()
	var seen: Dictionary = {}
	var pool: Array[String] = []

	for entry in raw:
		if not entry is Dictionary:
			continue
		var entry_word := str(entry.get("word", "")).to_lower()
		var usable := _is_usable_entry(entry)
		for candidate in _collect_candidates(entry):
			var lower := candidate.to_lower()
			if not seen.has(lower):
				seen[lower] = true
				pool.append(lower)
			# First usable entry that produced the word — the info fallback.
			if usable and not _origin_index.has(lower):
				_origin_index[lower] = entry
			# A real page of its own (not a synonym of somebody else).
			if usable and lower == entry_word:
				_meta_index[lower] = entry

	# Sort for a stable, device-independent order (daily engine input).
	pool.sort()
	var answers: Array[String] = []
	for word in pool:
		if _meta_index.has(word):
			answers.append(word)  # keeps the sorted order
	_word_pool = pool
	_word_set = seen
	_answer_pool = answers
	# Only a successful parse is cached: a transient read failure (file not
	# imported yet on a cold start) can retry on the next access.
	_loaded = not pool.is_empty()


## Loads and parses the dictionary JSON once, via the cache.
static func _load_dictionary() -> Array:
	var file := FileAccess.open(DICTIONARY_PATH, FileAccess.READ)
	if file == null:
		push_error("WordleVocab: cannot open %s" % DICTIONARY_PATH)
		return []
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("WordleVocab: JSON parse error — %s" % json.get_error_message())
		return []
	var data = json.data
	if not data is Array:
		push_error("WordleVocab: unexpected JSON format")
		return []
	return data


## Every filter-passing candidate word for one dictionary entry.
static func _collect_candidates(entry: Dictionary) -> Array[String]:
	var out: Array[String] = []
	# 1. The main word (skip proper nouns / abbreviations / junk types).
	if _passes_filter(str(entry.get("word", ""))) \
			and not _is_excluded_entry_type(entry):
		out.append(str(entry.get("word", "")))
	# 2. Valid words from synonyms.en / antonyms.en lists.
	for key in ["synonyms", "antonyms"]:
		var group = entry.get(key, {})
		if group is Dictionary and group.get("en") is Array:
			for value in group["en"]:
				if value is String and _passes_filter(value):
					out.append(value)
	return out


## The core word filter (see class docs for the full rule list).
## The cheap checks run first: the pool is built from a few thousand
## candidate strings, so nothing here should allocate.
static func _passes_filter(word: String) -> bool:
	var trimmed := word.strip_edges()
	if trimmed.length() < MIN_WORD_LENGTH:
		return false
	# Any uppercase character means a proper noun / name in this dataset.
	if trimmed != trimmed.to_lower():
		return false
	return _word_regex().search(trimmed) != null


## The compiled word pattern (built once per session).
static func _word_regex() -> RegEx:
	if _regex == null:
		_regex = RegEx.new()
		_regex.compile(_WORD_PATTERN)
	return _regex


## An entry good enough to describe one of its own synonyms on the end card:
## a normal page (not an abbreviation / proper noun / symbol / affix) whose
## own head word is a plain lowercase dictionary word.
static func _is_usable_entry(entry: Dictionary) -> bool:
	return not _is_excluded_entry_type(entry) \
		and _passes_filter(str(entry.get("word", "")))


## Excludes entry types that are clearly unusable as normal vocabulary.
## Checks both the primary type and compound types like "proper noun",
## "noun (possessive)", etc. by splitting on common delimiters.
static func _is_excluded_entry_type(entry: Dictionary) -> bool:
	var word_type := str(entry.get("word_type", "")).to_lower()
	# Check the full compound type first
	for bad in ["abbreviation", "proper", "symbol", "prefix", "suffix"]:
		if word_type.contains(bad):
			return true
	# Also check each component of compound types split by "/" or "("
	var parts := word_type.split("/", true)
	for part in parts:
		var trimmed := part.strip_edges()
		for bad in ["abbreviation", "proper", "symbol", "prefix", "suffix"]:
			if trimmed.contains(bad):
				return true
	return false
