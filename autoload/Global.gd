extends Node

signal review_words_changed()
# Emitted whenever local progression changes and needs to reach the server
# (see SyncManager). Suspended while applying a server snapshot so a remote
# apply doesn't immediately bounce back as a local change.
signal progress_dirty()

# ============================================================
#  GLOBAL.GD — Autoload Singleton
#  Handles: loading lesson JSON data, and the saved-words system
# ============================================================

# ============================================================
# TTS (Text-To-Speech) Engine
# ============================================================
var english_voice_id: String = ""
var _category_cache: Dictionary = {}
# Cache of parsed JSON lesson arrays keyed by res:// path, plus a per-file
# book_lesson -> entry index so lookups are O(1) instead of re-parsing the
# whole file and linearly scanning it on every scene entry.
var _json_cache: Dictionary = {}
var _lesson_index_cache: Dictionary = {}
var _word_db_loaded := false

const DICTIONARY_PATH := "res://data/v_dictionary.json"

# ---------- VOCABULARY DATA LOADING ----------

var intro_animation_played := false

var audio_player: AudioStreamPlayer

# Word database for quick lookup
var word_database: Dictionary = {}

# Verb forms mapping
var verb_forms: Dictionary = {}


func load_vocabulary(book_number: int, lesson_number: int) -> Dictionary:
	var path := "res://data/v%d_vocabularies.json" % book_number
	return _lookup_lesson_entry(path, book_number, lesson_number)


func get_audio_path(book_number: int, lesson_number: int, filename: String) -> String:
	return "res://assets/audio/v%d/l%d/%s" % [book_number, lesson_number, filename]


# ============================================================
# UNIFIED CONVERSATION / READING DATA LOADING
# ------------------------------------------------------------
# v_conversation.json and v_reading.json are each a single flat
# array of lesson entries (like v_dictionary.json), with "book"
# and "lesson" fields on every entry — instead of the old
# per-book "v{book}_conversations.json" / "{lessons:{"1":...}}"
# format. These two functions find the matching entry.
# ============================================================

const CONVERSATION_PATH := "res://data/v_conversation.json"
const READING_PATH      := "res://data/v_reading.json"


func load_conversation(book_number: int, lesson_number: int) -> Dictionary:
	return _load_unified_lesson_entry(CONVERSATION_PATH, book_number, lesson_number)


func load_reading(book_number: int, lesson_number: int) -> Dictionary:
	return _load_unified_lesson_entry(READING_PATH, book_number, lesson_number)


func _load_unified_lesson_entry(path: String, book_number: int, lesson_number: int) -> Dictionary:
	return _lookup_lesson_entry(path, book_number, lesson_number)


## Parses a lesson-data JSON file (a flat array of lesson entries) exactly
## once per session and caches it. Returns the cached Array (empty on error).
func _load_lesson_file(path: String) -> Array:
	if _json_cache.has(path):
		return _json_cache[path]
	if not FileAccess.file_exists(path):
		push_error("File not found: " + path)
		return []
	var file := FileAccess.open(path, FileAccess.READ)
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	var error := json.parse(text)
	if error != OK:
		push_error("Failed to parse JSON at %s — %s" % [path, json.get_error_message()])
		return []
	var data = json.data
	if not data is Array:
		push_error("Invalid JSON format at %s: expected an array of lesson entries" % path)
		return []
	_json_cache[path] = data
	return data


## Finds a lesson entry by book/lesson. Builds a book_lesson -> entry index
## for the file on first use, so lookups are O(1) instead of a linear scan.
func _lookup_lesson_entry(path: String, book_number: int, lesson_number: int) -> Dictionary:
	if not _lesson_index_cache.has(path):
		_lesson_index_cache[path] = {}
		var index: Dictionary = _lesson_index_cache[path]
		for entry in _load_lesson_file(path):
			var b := int(entry.get("book", -1))
			var l := int(entry.get("lesson", -1))
			if b < 0 or l < 0:
				continue
			index["%d_%d" % [b, l]] = entry
	# Return a deep copy: the cache must stay pristine so any scene that
	# mutates the returned entry (tagging book/lesson, etc.) can't poison
	# the cached data for the rest of the session.
	return _lesson_index_cache[path].get("%d_%d" % [book_number, lesson_number], {}).duplicate(true)


# Joins an array of sentence objects ({"en":..., "fa":..., "start":..., "end":...})
# into one plain-text string using only the "en" field. Farsi and timing data
# are intentionally ignored here for now (used later for karaoke sync/translation).
func join_sentences(sentences: Array) -> String:
	var parts: Array = []
	for s in sentences:
		var en: String = s.get("en", "")
		if en != "":
			parts.append(en)
	return " ".join(parts)


# Some entries in the unified files store "audio" as a full res:// path
# (e.g. "res://assets/audio/v1/l1/conversation.mp3") rather than just a
# filename. This resolves either form to a usable path.
func resolve_audio_path(book_number: int, lesson_number: int, audio_value: String, fallback_filename: String) -> String:
	if audio_value == "":
		return get_audio_path(book_number, lesson_number, fallback_filename)
	if audio_value.begins_with("res://"):
		return audio_value
	return get_audio_path(book_number, lesson_number, audio_value)


# ---------- SAVED WORDS SYSTEM ----------

const SAVED_WORDS_PATH  := "user://saved_words.json"
const PROGRESS_PATH     := "user://progress.json"
const REVIEW_WORDS_PATH  := "user://review_words.json"

var current_book: int   = 1
var current_lesson: int = 1
var _last_scene: String = ""
var saved_words: Array = []
var review_words: Array = []
var grammar_unlocked_units: Dictionary = {}
var grammar_start_unit_index: int = 0
var grammar_xp: Dictionary = {}
# Per lesson ("book_lesson") -> Array of بخش indices already completed, so XP
# is only awarded once per unit (never on replays).
var grammar_completed_units: Dictionary = {}

# Suppresses progress_dirty while a server snapshot is being applied.
var _suspend_dirty: bool = false

# == SCHEMA ==============================================================
# Mirrors SyncManager.SCHEMA_VERSION so the local snapshot is stamped before
# it ever reaches the server. Kept in sync with the sync layer; bump both.
const SCHEMA_VERSION := 2

# Last-writer-wins metadata: entity key ("grammar_xp", "saved_words", ...) ->
# unix time the entity was last touched locally. The sync merge uses these to
# decide which side wins when both devices edited the same key, instead of a
# blind whole-blob overwrite.
var _key_updated_at: Dictionary = {}


func _touch_progress_key(key: String) -> void:
	# Records when an entity changed so the sync merge can do last-writer-wins.
	# The calling mutator is responsible for persisting + emitting dirty.
	_key_updated_at[key] = int(Time.get_unix_time_from_system())


func _emit_dirty() -> void:
	if not _suspend_dirty:
		progress_dirty.emit()


# ---------- APP SETTINGS ----------
const SETTINGS_PATH := "user://settings.json"
var sound_enabled: bool = true   # UI sound effects (Sfx autoload)
var tts_enabled: bool = true     # English text-to-speech pronunciation
var theme_mode: int = 0          # 0 = Dark, 1 = Light


var _theme: Node = null

# ---------- THEME SYSTEM (delegated to ThemeService, owned by Global) ----------
signal theme_changed(mode: int)

enum ThemeMode { DARK, LIGHT }

func theme_is_dark() -> bool:
	return _theme.theme_is_dark()

func get_theme_color(role: String) -> Color:
	return _theme.get_theme_color(role)

func on_theme_changed(callback: Callable) -> void:
	_theme.on_theme_changed(callback)

func get_base_theme() -> Theme:
	return _theme.get_base_theme()

func set_theme_mode(new_mode: int) -> void:
	_theme.set_theme_mode(new_mode)

func style_scene(root: Node) -> void:
	if _theme != null:
		_theme.style_scene(root)

func style_header(header: Node) -> void:
	if _theme != null:
		_theme.style_header(header)

func set_translation_toggle_state(btn: Button, active: bool) -> void:
	if _theme != null:
		_theme.set_translation_toggle_state(btn, active)

func _relay_theme_changed(mode: int) -> void:
	theme_mode = mode
	save_settings()
	theme_changed.emit(mode)

func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return
	var data: Dictionary = json.data
	sound_enabled = bool(data.get("sound_enabled", true))
	tts_enabled = bool(data.get("tts_enabled", true))
	theme_mode = int(data.get("theme_mode", 0))


func save_settings() -> void:
	var data: Dictionary = {
		"sound_enabled": sound_enabled,
		"tts_enabled": tts_enabled,
		"theme_mode": theme_mode,
	}
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not open %s for writing (error %d) — settings not saved." % [SETTINGS_PATH, FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify(data))
	file.close()


func _ready() -> void:
	_load_saved_words()
	_load_review_words()
	_load_progress()
	# The 1 MB dictionary parse is deferred off the boot critical path (and
	# lazily loaded on first lookup) so startup doesn't freeze on it.
	call_deferred("_load_word_database")
	_load_settings()
	_init_tts() # You can keep or remove TTS init, keeping it for safety

	# Decomposed theme system: a dedicated ThemeService node owns the palette,
	# scene-styling walk and header engine; Global only forwards to it.
	_theme = preload("res://autoload/ThemeService.gd").new()
	add_child(_theme)
	_theme.setup(theme_mode)
	_theme.theme_changed.connect(_relay_theme_changed)

	# Style every scene as it becomes current (covers transitions and the
	# initial launch) so Dark / Light is consistent app-wide.
	get_tree().scene_changed.connect(_on_scene_changed)
	call_deferred("_style_initial_scene")

	# Initialize AudioStreamPlayer for playing word audio files
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)


func _on_scene_changed() -> void:
	style_scene(get_tree().current_scene)


func _style_initial_scene() -> void:
	style_scene(get_tree().current_scene)

# ---------- LAST SCENE ----------

func set_last_scene(scene_path: String) -> void:
	_last_scene = scene_path
	_touch_progress_key("last_scene")
	_save_progress()


func get_last_scene() -> String:
	return _last_scene


func has_last_scene() -> bool:
	return _last_scene != ""


func _grammar_unlock_key(book: int, lesson: int) -> String:
	return "%d_%d" % [book, lesson]


func get_grammar_unlocked_units(book: int, lesson: int, total_units: int = 0) -> int:
	var key: String = _grammar_unlock_key(book, lesson)
	# Derive the unlock count from the completed set so reordering or editing
	# units in a lesson JSON can never leave a stale unlock count: each
	# completed unit grants one more unlocked unit (legacy index-based entries
	# still count, so old saves keep working).
	var completed: Array = grammar_completed_units.get(key, [])
	var unlocked: int = completed.size() + 1
	# Also honor any previously stored (legacy / deep-link) unlock value so
	# we never regress progress that was recorded before this derivation.
	var stored: int = int(grammar_unlocked_units.get(key, 1))
	unlocked = maxi(unlocked, stored)
	if total_units > 0:
		unlocked = clampi(unlocked, 1, total_units)
	else:
		unlocked = maxi(unlocked, 1)
	return unlocked


func set_grammar_unlocked_units(book: int, lesson: int, unlocked: int) -> void:
	var key: String = _grammar_unlock_key(book, lesson)
	var current: int = int(grammar_unlocked_units.get(key, 1))
	var next_value: int = maxi(current, unlocked)
	grammar_unlocked_units[key] = next_value
	_touch_progress_key("grammar_unlocked_units")
	_save_progress()


func set_grammar_start_unit(index: int) -> void:
	grammar_start_unit_index = maxi(index, 0)


# ---------- GRAMMAR XP ----------

func get_grammar_xp(book: int, lesson: int) -> int:
	var key: String = _grammar_unlock_key(book, lesson)
	return int(grammar_xp.get(key, 0))


# Adds earned XP for a lesson, persists it, and returns the new total.
func add_grammar_xp(book: int, lesson: int, amount: int) -> int:
	var key: String = _grammar_unlock_key(book, lesson)
	var total: int = int(grammar_xp.get(key, 0)) + maxi(amount, 0)
	grammar_xp[key] = total
	_touch_progress_key("grammar_xp")
	_save_progress()
	return total


func get_total_grammar_xp() -> int:
	var total := 0
	for value in grammar_xp.values():
		total += int(value)
	return total


# ---------- GRAMMAR COMPLETED UNITS ----------

func is_unit_completed(book: int, lesson: int, unit_index: int, unit_id: String = "") -> bool:
	var key: String = _grammar_unlock_key(book, lesson)
	var completed: Array = grammar_completed_units.get(key, [])
	# Match by stable id first (content edits / reorders stay consistent),
	# then fall back to the legacy index for old saves.
	if unit_id != "" and unit_id in completed:
		return true
	return unit_index in completed


func mark_unit_completed(book: int, lesson: int, unit_index: int, unit_id: String = "") -> void:
	var key: String = _grammar_unlock_key(book, lesson)
	var completed: Array = grammar_completed_units.get(key, [])
	if unit_id != "":
		if unit_id in completed:
			return
		# If the legacy index form is already present, upgrade it in place to
		# the stable id instead of appending a duplicate — the completed set
		# must stay a set so the unlock count (derived from its size) never
		# over-counts the same unit.
		var legacy_at := completed.find(unit_index)
		if legacy_at >= 0:
			completed[legacy_at] = unit_id
		else:
			completed.append(unit_id)
	else:
		if unit_index in completed:
			return
		completed.append(unit_index)
	grammar_completed_units[key] = completed
	_touch_progress_key("grammar_completed_units")
	_save_progress()


# ---------- PROGRESS PERSISTENCE ----------

# Central, crash-safe write helper: every persist path goes through here so
# a failed FileAccess.open (storage full, permission error on Android, etc.)
# logs a clear error instead of crashing on a null object.
func _write_json_file(path: String, data: Variant) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not open %s for writing (error %d) — data not saved." % [path, FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify(data))
	file.close()


func _save_progress() -> void:
	var data: Dictionary = {
		"last_scene": _last_scene,
		"grammar_unlocked_units": grammar_unlocked_units,
		"grammar_xp": grammar_xp,
		"grammar_completed_units": grammar_completed_units,
	}
	_write_json_file(PROGRESS_PATH, data)
	_emit_dirty()


func _load_progress() -> void:
	if not FileAccess.file_exists(PROGRESS_PATH):
		return
	var file: FileAccess = FileAccess.open(PROGRESS_PATH, FileAccess.READ)
	var text: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	if json.parse(text) == OK and json.data is Dictionary:
		var data: Dictionary = json.data
		_last_scene = str(data.get("last_scene", ""))
		var unlocked: Variant = data.get("grammar_unlocked_units", {})
		if unlocked is Dictionary:
			grammar_unlocked_units = unlocked
		var xp_data: Variant = data.get("grammar_xp", {})
		if xp_data is Dictionary:
			grammar_xp = xp_data
		var completed_data: Variant = data.get("grammar_completed_units", {})
		if completed_data is Dictionary:
			grammar_completed_units = completed_data


# ------------------------------------------------------------
# PROGRESS SNAPSHOT (used by SyncManager to sync with the server)
# ------------------------------------------------------------

## The full local progression as a single serialisable dictionary.
func get_progress_snapshot() -> Dictionary:
	return {
		"last_scene": _last_scene,
		"grammar_unlocked_units": grammar_unlocked_units.duplicate(true),
		"grammar_xp": grammar_xp.duplicate(true),
		"grammar_completed_units": grammar_completed_units.duplicate(true),
		"saved_words": saved_words.duplicate(true),
		"review_words": review_words.duplicate(true),
		"schema_version": SCHEMA_VERSION,
		"key_updated_at": _key_updated_at.duplicate(true),
	}


## Replace the local progression with an already-merged snapshot and persist it.
## Does not emit progress_dirty (the merge result is what we're syncing).
func apply_progress_snapshot(data: Dictionary) -> void:
	if data == null or data.is_empty():
		return
	_suspend_dirty = true
	_last_scene = str(data.get("last_scene", _last_scene))
	var unlocked: Variant = data.get("grammar_unlocked_units", null)
	if unlocked is Dictionary:
		grammar_unlocked_units = unlocked
	var xp_data: Variant = data.get("grammar_xp", null)
	if xp_data is Dictionary:
		grammar_xp = xp_data
	var completed: Variant = data.get("grammar_completed_units", null)
	if completed is Dictionary:
		grammar_completed_units = completed
	if data.get("saved_words") is Array:
		saved_words = data["saved_words"]
	if data.get("review_words") is Array:
		review_words = data["review_words"]
	if data.get("key_updated_at") is Dictionary:
		_key_updated_at = data["key_updated_at"]
	_save_progress()
	_persist_saved_words()
	_persist_review_words()
	_suspend_dirty = false
	review_words_changed.emit()


func _load_saved_words() -> void:
	saved_words = _load_word_list_file(SAVED_WORDS_PATH)

func _load_review_words() -> void:
	review_words = _load_word_list_file(REVIEW_WORDS_PATH)


## Reads a saved word list from disk, normalising and de-duplicating it.
## A missing, unreadable, unparseable or non-array file yields an empty list
## rather than an error — json.data is null on a parse failure, so the type
## has to be checked before it is handed on.
func _load_word_list_file(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Could not read %s (error %d)." % [path, FileAccess.get_open_error()])
		return []
	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	# These two are warnings rather than errors on purpose: the loader recovers
	# by starting from an empty list, and the list is rebuilt as the student
	# saves words again. A hard error here would only ever be noise.
	if json.parse(text) != OK:
		push_warning("Could not parse %s: %s — starting from an empty list."
			% [path, json.get_error_message()])
		return []
	if not (json.data is Array):
		push_warning("Unexpected contents in %s: expected an array — starting from an empty list." % path)
		return []

	# Normalise + de-duplicate on read. A hand-edited or half-synced file can
	# hold duplicate entries, entries missing book/lesson, or non-dictionary
	# junk; all of those used to break identity lookups later on.
	return _sanitize_word_list(json.data)


## Turns a raw parsed JSON array into a clean, de-duplicated word list:
## drops non-dictionary entries, guarantees word/book/lesson are present and
## correctly typed, and seeds the SRS fields. Keeps the on-disk format valid
## even if it was hand-edited or produced by an older build.
func _sanitize_word_list(raw: Array) -> Array:
	var clean: Array = []
	var seen: Dictionary = {}
	for item in raw:
		if not (item is Dictionary):
			continue
		var word: String = str(item.get("word", ""))
		if word == "":
			continue
		var book: int   = _as_int(item.get("book", 0), 0)
		var lesson: int = _as_int(item.get("lesson", 0), 0)
		# Case-insensitive identity: the same word saved from two lessons, or
		# with different capitalisation, must not become two review cards.
		var key := "%s|%d|%d" % [word.to_lower(), book, lesson]
		if seen.has(key):
			continue
		seen[key] = true
		var entry: Dictionary = item.duplicate(true)
		entry["word"]   = word
		entry["book"]   = book
		entry["lesson"] = lesson
		# Backfill content for entries stored before enrichment existed (or by
		# an older build), so an already-saved blank card heals on next launch.
		_enrich_word_entry(entry)
		_ensure_srs_fields(entry)
		clean.append(entry)
	return clean

func _persist_saved_words() -> void:
	_write_json_file(SAVED_WORDS_PATH, saved_words)
	_emit_dirty()

func _persist_review_words() -> void:
	_write_json_file(REVIEW_WORDS_PATH, review_words)
	_emit_dirty()

func is_word_saved(word: String, book: int, lesson: int) -> bool:
	for entry in saved_words:
		if _is_same_word(entry, word, book, lesson):
			return true
	return false


func save_word(word_data: Dictionary) -> void:
	var word: String = str(word_data.get("word", ""))
	if word == "":
		return
	var book: int   = _as_int(word_data.get("book", 0), 0)
	var lesson: int = _as_int(word_data.get("lesson", 0), 0)

	if is_word_saved(word, book, lesson):
		# Keep the two destinations independent: if the review card was removed
		# from Word Review, saving again should restore it without duplicating the
		# flashcard entry.
		for saved_entry in saved_words:
			if _is_same_word(saved_entry, word, book, lesson):
				add_review_word(saved_entry)
				return

	var copy: Dictionary = word_data.duplicate(true)
	# Normalise the identity fields so later lookups compare like with like.
	copy["word"]   = word
	copy["book"]   = book
	copy["lesson"] = lesson
	# Fill in any content the caller did not supply from the unified
	# dictionary. Some save paths (e.g. a bare {word, book, lesson}) carry no
	# meaning/example/phonetics at all, which produced a review card whose
	# whole back face was blank. Enriching here means the card is complete
	# regardless of which screen saved it.
	_enrich_word_entry(copy)
	_ensure_srs_fields(copy)

	saved_words.append(copy)
	_touch_progress_key("saved_words")
	_persist_saved_words()
	# add_review_word() persists + emits review_words_changed itself.
	add_review_word(copy)


func remove_word(word: String, book: int, lesson: int) -> void:
	# Flashcard unsave/removal affects only the saved flashcard collection.
	# Leitner cards are managed independently from Word Review's side menu.
	var removed_saved: bool = _remove_from_array(saved_words, word, book, lesson)
	if not removed_saved:
		return
	_touch_progress_key("saved_words")
	_persist_saved_words()


## Removes the first matching entry. Returns true when something was actually
## removed, so callers can skip persisting on a no-op.
## Fills in missing content fields on a saved word entry from the unified
## dictionary. Only blanks are filled — data the caller already provided
## (e.g. the lesson's own example sentence) always wins. This keeps a card's
## back face populated even when it was saved from a screen that only knew the
## word, book and lesson.
func _enrich_word_entry(entry: Dictionary) -> void:
	var word: String = str(entry.get("word", ""))
	if word == "":
		return
	const CONTENT_FIELDS := [
		"meaning_en", "meaning_fa", "example", "phonetics",
		"word_type", "audio", "synonyms", "antonyms",
	]
	# Nothing to do if the entry already carries its content.
	var has_content := false
	for field in CONTENT_FIELDS:
		if not str(entry.get(field, "")).is_empty():
			has_content = true
			break
	if has_content:
		return

	var definition := get_word_definition(word)
	if definition.is_empty():
		return
	for field in CONTENT_FIELDS:
		if entry.has(field):
			continue
		var value: Variant = definition.get(field)
		if value != null and not str(value).is_empty():
			entry[field] = value


func _remove_from_array(arr: Array, word: String, book: int, lesson: int) -> bool:
	for i in range(arr.size() - 1, -1, -1):
		if _is_same_word(arr[i], word, book, lesson):
			arr.remove_at(i)
			return true
	return false


func get_saved_words() -> Array:
	return saved_words.duplicate(true)


func add_review_word(word_data: Dictionary) -> void:
	var word: String = str(word_data.get("word", ""))
	if word == "":
		return
	var book: int   = _as_int(word_data.get("book", 0), 0)
	var lesson: int = _as_int(word_data.get("lesson", 0), 0)

	for entry in review_words:
		if _is_same_word(entry, word, book, lesson):
			return

	var copy: Dictionary = word_data.duplicate(true)
	# Seed the SRS fields on insert. Without this a new card reached the disk
	# with no srs_due at all, and only got the "-1 = new" default as a side
	# effect of get_due_words() mutating the entry in memory.
	_ensure_srs_fields(copy)
	_enrich_word_entry(copy)
	review_words.append(copy)
	_touch_progress_key("review_words")
	_persist_review_words()
	review_words_changed.emit()

func remove_review_word(word: String, book: int, lesson: int) -> void:
	# Word Review's side menu owns removal from the Leitner queue. Keep the
	# flashcard saved list untouched so the word can remain bookmarked.
	var removed_review: bool = _remove_from_array(review_words, word, book, lesson)
	if not removed_review:
		return
	_touch_progress_key("review_words")
	_persist_review_words()
	review_words_changed.emit()


func get_review_words() -> Array:
	return review_words.duplicate(true)


# ---------- DATA MANAGEMENT (used by the Settings screen) ----------

func clear_saved_words() -> void:
	saved_words.clear()
	review_words.clear()
	_touch_progress_key("saved_words")
	_touch_progress_key("review_words")
	_persist_saved_words()
	_persist_review_words()
	review_words_changed.emit()


func clear_review_words() -> void:
	review_words.clear()
	saved_words.clear()
	# Same reason as clear_saved_words(): a clear on one device has to win the
	# last-writer-wins merge on the other, so both keys must be stamped.
	_touch_progress_key("saved_words")
	_touch_progress_key("review_words")
	_persist_review_words()
	_persist_saved_words()
	review_words_changed.emit()


func reset_all_progress() -> void:
	saved_words.clear()
	review_words.clear()
	grammar_unlocked_units.clear()
	_key_updated_at.clear()
	grammar_xp.clear()
	grammar_completed_units.clear()
	_last_scene = ""
	_persist_saved_words()
	_persist_review_words()
	_save_progress()
	review_words_changed.emit()


# ---------- ENHANCED WORD DATABASE ----------

func _load_word_database(force := false) -> void:
	"""Load every word from the single unified dictionary file into the database"""
	if _word_db_loaded and not force:
		return
	word_database.clear()
	verb_forms.clear()

	if not FileAccess.file_exists(DICTIONARY_PATH):
		push_error("Dictionary file not found: " + DICTIONARY_PATH)
		return

	var file := FileAccess.open(DICTIONARY_PATH, FileAccess.READ)
	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("Failed to parse v_dictionary.json — %s" % json.get_error_message())
		return

	var data = json.data
	if not data is Array:
		push_error("Invalid v_dictionary.json format: expected a flat array of word objects")
		return

	for word_obj in data:
		var word: String = word_obj.get("word", "")
		if word == "":
			continue

		var key := word.to_lower()
		if word_database.has(key):
			continue  # keep the first occurrence if a word appears twice

		var word_data := {
	"word": word,
	"pronunciation": word_obj.get("pronunciation", ""),
	"meaning_en": word_obj.get("meaning_en", ""),
	"meaning_fa": word_obj.get("meaning_fa", ""),
	"example": word_obj.get("example", ""),
	"synonyms": word_obj.get("synonyms", {}),
	"antonyms": word_obj.get("antonyms", {}),
	"word_type": word_obj.get("word_type", "noun"),
	"countable": word_obj.get("countable", null),
	"verb_forms": word_obj.get("verb_forms", {}),
	"audio": word_obj.get("audio", ""),
	"phonetics": word_obj.get("phonetics", "")
}
		word_database[key] = word_data

		if word_data["word_type"] == "verb":
			var forms = word_data["verb_forms"]
			var base_word: String = word_data["word"]
			if forms.has("past"): verb_forms[forms["past"].to_lower()] = base_word
			if forms.has("past_participle"): verb_forms[forms["past_participle"].to_lower()] = base_word
			if forms.has("present_participle"): verb_forms[forms["present_participle"].to_lower()] = base_word
			if forms.has("third_person"): verb_forms[forms["third_person"].to_lower()] = base_word

	print("Word database loaded: %d words" % word_database.size())
	_word_db_loaded = true


func get_word_definition(word: String) -> Dictionary:
	"""Get definition for a word from the database"""
	if not _word_db_loaded:
		_load_word_database()
	if word == "":
		return {}

	var key = word.to_lower()

	# Try exact match
	if word_database.has(key):
		return word_database[key]

	# Check if it's a verb form
	if verb_forms.has(key):
		var base_word = verb_forms[key]
		if word_database.has(base_word.to_lower()):
			return word_database[base_word.to_lower()]

	# Try removing plural 's' / 'es' / 'ies' for nouns
	if key.ends_with("s") and len(key) > 1:
		var candidates: Array[String] = [key.trim_suffix("s")]          # cats -> cat
		if key.ends_with("es"):
			candidates.append(key.trim_suffix("es"))                    # boxes -> box
		if key.ends_with("ies"):
			candidates.append(key.trim_suffix("ies") + "y")             # studies -> study
		for singular in candidates:
			if word_database.has(singular):
				return word_database[singular]
			# Check if it's a verb form with 's'
			if verb_forms.has(singular):
				var base_word = verb_forms[singular]
				if word_database.has(base_word.to_lower()):
					return word_database[base_word.to_lower()]

	# Try removing 'ing' for verbs
	if key.ends_with("ing") and len(key) > 3:
		var base = key.trim_suffix("ing")
		if word_database.has(base):
			return word_database[base]
		if verb_forms.has(base):
			var base_word = verb_forms[base]
			if word_database.has(base_word.to_lower()):
				return word_database[base_word.to_lower()]

	# Try removing 'ed' for past tense
	if key.ends_with("ed") and len(key) > 2:
		var base = key.trim_suffix("ed")
		if word_database.has(base):
			return word_database[base]
		if verb_forms.has(base):
			var base_word = verb_forms[base]
			if word_database.has(base_word.to_lower()):
				return word_database[base_word.to_lower()]

	# Try removing 'ly' for adverbs
	if key.ends_with("ly") and len(key) > 2:
		var base = key.trim_suffix("ly")
		if word_database.has(base):
			return word_database[base]

	# Try removing 'er' for comparatives
	if key.ends_with("er") and len(key) > 2:
		var base = key.trim_suffix("er")
		if word_database.has(base):
			return word_database[base]

	# Try removing 'est' for superlatives
	if key.ends_with("est") and len(key) > 3:
		var base = key.trim_suffix("est")
		if word_database.has(base):
			return word_database[base]

	return {}


func get_word_definition_from_current_lesson(word: String) -> Dictionary:
	"""Look up a word in the unified dictionary, then tag it with the
	book/lesson the student is currently viewing — so saved words still
	remember where they were learned, and the SRS system still works."""
	var definition := get_word_definition(word)
	if definition.is_empty():
		return {}

	var tagged := definition.duplicate(true)
	tagged["book"] = current_book
	tagged["lesson"] = current_lesson
	return tagged

func reload_word_database() -> void:
	"""Reload the word database"""
	_load_word_database(true)


# ---------- UI HELPERS ----------

func button_bounce(button: Control, shrink_to: float = 0.92, duration: float = 0.08) -> void:
	if button.pivot_offset == Vector2.ZERO:
		button.pivot_offset = button.size / 2.0

	var tween := create_tween()
	tween.tween_property(button, "scale", Vector2(shrink_to, shrink_to), duration)
	tween.tween_property(button, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ============================================================
#  SPACED REPETITION SYSTEM (simplified SM-2 / Anki-style)
# ============================================================

const SRS_NEW_CARDS_PER_SESSION := 20
# Ceiling on how far a single interval can grow, so a card rated "easy"
# repeatedly can never drift years into the future.
const SRS_MAX_INTERVAL := 365.0
const SRS_MIN_EASE := 1.3
const SRS_MAX_EASE := 3.0


func _today_day_number() -> int:
	# Local-time day number (not UTC) so a "due today" review rolls over at
	# local midnight rather than UTC midnight.
	var local := Time.get_datetime_dict_from_system()
	return int(Time.get_unix_time_from_datetime_dict(local) / 86400.0)


func _as_float(value: Variant, fallback: float) -> float:
	# Saved JSON can hand back a string, null or bool for a numeric field
	# (hand-edited files, older schema). Coerce defensively so a bad value
	# degrades to the default instead of crashing or poisoning the maths.
	if value is float or value is int:
		return float(value)
	return fallback


func _as_int(value: Variant, fallback: int) -> int:
	if value is float or value is int:
		return int(value)
	return fallback


func _ensure_srs_fields(entry: Dictionary) -> void:
	# Fills in any missing field AND normalises out-of-range/garbage values, so
	# the scheduler can assume these four keys are always sane numbers.
	entry["srs_interval"] = maxf(0.0, _as_float(entry.get("srs_interval"), 0.0))
	entry["srs_ease"] = clampf(_as_float(entry.get("srs_ease"), 2.5), SRS_MIN_EASE, SRS_MAX_EASE)
	entry["srs_reps"] = maxi(0, _as_int(entry.get("srs_reps"), 0))
	entry["srs_due"] = _as_int(entry.get("srs_due"), -1)  # -1 = "new, never studied"


func get_due_words() -> Array:
	var today := _today_day_number()
	var reviews: Array = []
	var new_cards: Array = []

	for entry in review_words:
		# A corrupt save must not take the whole review screen down.
		if not (entry is Dictionary):
			continue
		_ensure_srs_fields(entry)
		if entry["srs_due"] == -1:
			new_cards.append(entry)            # never studied yet
		elif entry["srs_due"] <= today:
			reviews.append(entry)              # due for review

	# Most overdue first, so the words closest to being forgotten are studied
	# early in the session instead of being left to the end.
	reviews.sort_custom(func(a, b): return int(a["srs_due"]) < int(b["srs_due"]))

	# Deep copies: the caller mutates what it receives (interval previews,
	# re-queueing), so it must never write through into Global's live SRS
	# state. Returning live references let a UI read corrupt the schedule.
	var due: Array = []
	for entry in reviews:
		due.append(entry.duplicate(true))

	# New cards follow the reviews, capped per session so a large library does
	# not dump hundreds of unseen words in one sitting.
	var shown_new := 0
	for entry in new_cards:
		if shown_new >= SRS_NEW_CARDS_PER_SESSION:
			break
		due.append(entry.duplicate(true))
		shown_new += 1

	return due

func load_category(category: String, book: int, lesson: int) -> Dictionary:
	if not _category_cache.has(category):
		var path := "res://data/%s.json" % category
		if not FileAccess.file_exists(path):
			push_warning("Category file not found: " + path)
			return {}
		var file := FileAccess.open(path, FileAccess.READ)
		var json := JSON.new()
		if json.parse(file.get_as_text()) != OK:
			push_error("JSON error in " + path)
			return {}
		file.close()
		_category_cache[category] = json.data
	
	var data: Dictionary = _category_cache[category]
	return data.get("books", {}).get(str(book), {}).get(str(lesson), {})

func _compute_srs_result(entry: Dictionary, rating: String) -> Dictionary:
	var ease_factor: float = clampf(_as_float(entry.get("srs_ease"), 2.5), SRS_MIN_EASE, SRS_MAX_EASE)
	var interval: float = maxf(0.0, _as_float(entry.get("srs_interval"), 0.0))
	var reps: int = maxi(0, _as_int(entry.get("srs_reps"), 0))
	var today := _today_day_number()

	var new_ease := ease_factor
	var new_interval := interval
	var new_reps := reps

	match rating:
		"again":
			# A lapse drops the card back to the start of the learning steps.
			# It stays due TODAY, so the review scene re-queues it later in the
			# same session instead of the student waiting a full day.
			new_reps = 0
			new_ease = maxf(SRS_MIN_EASE, ease_factor - 0.2)
			new_interval = 0.0
		"hard":
			new_ease = maxf(SRS_MIN_EASE, ease_factor - 0.15)
			# A new card must never get a LONGER wait than "good". Previously
			# "hard" produced 1.2 days here, which ceil() turned into 2 days —
			# rating a card "hard" pushed it further away than rating it "good".
			# On a new card "hard" now means "barely knew it", so the card comes
			# back TODAY, strictly before "good" (+1 day) and "easy".
			new_interval = (interval * 1.2) if interval > 0.0 else 0.0
			new_interval = maxf(1.0, new_interval) if interval > 0.0 else 0.0
			new_reps = reps + 1
		"good":
			if reps == 0:
				new_interval = 1.0
			elif reps == 1:
				new_interval = 3.0
			else:
				new_interval = interval * ease_factor
			new_reps = reps + 1
		"easy":
			if reps == 0:
				new_interval = 3.0
			else:
				new_interval = interval * ease_factor * 1.3
			new_ease = minf(SRS_MAX_EASE, ease_factor + 0.15)
			new_reps = reps + 1

	# An interval can never grow without bound.
	new_interval = clampf(new_interval, 0.0, SRS_MAX_INTERVAL)

	var new_due: int
	if rating == "again":
		new_due = today
	elif new_interval < 1.0:
		# A sub-day interval means "still today" — this is what makes "hard" on
		# a brand new card come back before "good". Forcing a 1-day minimum
		# here (as the old maxi(1, ...) did) is what made both buttons read
		# "۱ روز" and told the student the two choices were identical.
		new_due = today
	else:
		# round(), not ceil(): the label on the rating button is derived from
		# the same interval via _format_interval(), so the promise the UI makes
		# to the student ("۱ روز") is exactly the one kept here.
		new_due = today + int(round(new_interval))

	return {
		"ease": new_ease,
		"interval": new_interval,
		"reps": new_reps,
		"due": new_due
	}


func review_word(word: String, book: int, lesson: int, rating: String) -> void:
	if not rating in ["again", "hard", "good", "easy"]:
		return
	_touch_progress_key("review_words")
	_touch_progress_key("saved_words")

	# The schedule is mirrored in BOTH lists, so update whichever ones actually
	# hold this word. Looking only at saved_words meant a word that lived only
	# in review_words (possible after a partial sync merge, or if the two files
	# ever disagreed) was silently never rescheduled: its SRS result came back
	# empty, review_word() bailed out, and the card stayed due forever.
	_apply_srs_result(saved_words, word, book, lesson, rating)
	_apply_srs_result(review_words, word, book, lesson, rating)

	_persist_saved_words()
	_persist_review_words()


## Runs one grading step against every matching entry in `arr` and returns the
## computed result (empty when the word is not present in that list).
func _apply_srs_result(arr: Array, word: String, book: int, lesson: int, rating: String) -> Dictionary:
	var result: Dictionary = {}
	for entry in arr:
		if not _is_same_word(entry, word, book, lesson):
			continue
		_ensure_srs_fields(entry)
		result = _compute_srs_result(entry, rating)
		entry["srs_ease"]     = result["ease"]
		entry["srs_interval"] = result["interval"]
		entry["srs_reps"]     = result["reps"]
		entry["srs_due"]      = result["due"]
		break
	return result


## Identity test for a saved word: same word text, book and lesson. Tolerates
## non-Dictionary entries (corrupt save) and numeric fields that arrived from
## JSON as a different numeric type.
func _is_same_word(entry: Variant, word: String, book: int, lesson: int) -> bool:
	if not (entry is Dictionary):
		return false
	return str(entry.get("word", "")) == word \
		and _as_int(entry.get("book", 0), 0) == book \
		and _as_int(entry.get("lesson", 0), 0) == lesson


func preview_intervals(entry: Dictionary) -> Dictionary:
	# Preview on a copy. _ensure_srs_fields() writes defaults into the dict it
	# is given, and this is called on every "Show answer" tap — mutating the
	# caller's entry here leaked scheduler state into whatever held it.
	var probe: Dictionary = entry.duplicate(true)
	_ensure_srs_fields(probe)
	var result := {}
	for rating in ["again", "hard", "good", "easy"]:
		var r := _compute_srs_result(probe, rating)
		result[rating] = _format_interval(r["interval"], rating)
	return result


func _format_interval(interval: float, rating: String) -> String:
	if rating == "again":
		# "again" is rescheduled for later in the SAME session, not in minutes.
		return "همین حالا"
	# Anything under a full day comes back today — the label has to say so,
	# otherwise "hard" (today) and "good" (tomorrow) both read "۱ روز" and the
	# student cannot tell the two choices apart.
	if interval < 1.0:
		return "امروز"
	var days := int(round(interval))
	if days == 1:
		return "۱ روز"
	else:
		return "%d روز" % days

func play_word_audio(audio_filename: String, word_text: String = "") -> void:
	# 1. If no audio filename is provided in the JSON, fallback to TTS immediately
	if audio_filename.is_empty():
		if word_text != "":
			speak_word(word_text)
		return

	var path: String = "res://assets/audio/Vocabularies/%s" % audio_filename

	# 2. Load through Content so it works whether the clip is bundled or was
	#    downloaded to user://content/. A word clip that hasn't been fetched yet
	#    (on-demand model) falls back to TTS — no error. Resolved at runtime so
	#    this autoload has no load-order dependency on the Content singleton.
	var content := get_node_or_null("/root/Content")
	var stream: AudioStream = null
	if content != null and content.has_asset(path):
		stream = content.load_audio(path)
	if stream == null:
		if word_text != "":
			speak_word(word_text)
		return

	if audio_player.playing:
		audio_player.stop() # Stop current audio if it's still playing
	audio_player.stream = stream
	audio_player.play()

func _init_tts() -> void:
	# Ask the OS directly for English voices.
	# (kept untyped on purpose — the return type differs between Godot versions)
	var en_voices = DisplayServer.tts_get_voices_for_language("en")
	if en_voices.size() > 0:
		english_voice_id = _extract_voice_id(en_voices[0])

	# Fallback: scan every installed voice and pick an English one.
	if english_voice_id == "":
		var all_voices = DisplayServer.tts_get_voices()
		for voice in all_voices:
			var voice_id := _extract_voice_id(voice)
			var voice_lang := _extract_voice_language(voice).to_lower()

			var is_english := false
			if voice_lang != "":
				is_english = voice_lang.begins_with("en")
			else:
				is_english = "en" in voice_id.to_lower()

			if is_english and voice_id != "":
				english_voice_id = voice_id
				break

	if english_voice_id == "":
		# Not an error: speech is an optional feature. Some devices (and lean
		# desktop installs) have no TTS voices, so the app just runs without
		# audio. Log once (informational) instead of raising a warning.
		print("[TTS] No English voice available on this device; pronunciation/speech disabled. Install a TTS voice to enable it.")


# ------------------------------------------------------------
# In Godot 4.7, DisplayServer.tts_get_voices() returns an
# Array of Dictionaries (one Dictionary per voice), not plain
# String IDs. These helpers safely pull out the voice ID and
# language whether the entry is a Dictionary or a plain String.
# ------------------------------------------------------------
func _extract_voice_id(voice: Variant) -> String:
	if voice is Dictionary:
		# Try the most common key names for the voice identifier.
		for key in ["id", "identifier", "voice_id", "name"]:
			if voice.has(key):
				return str(voice[key])
		return ""
	return str(voice)


func _extract_voice_language(voice: Variant) -> String:
	if voice is Dictionary:
		for key in ["language", "lang", "locale"]:
			if voice.has(key):
				return str(voice[key])
		return ""
	return str(voice)

# On some devices the TTS engine is not ready at autoload time,
# so give voice detection a second chance right before speaking.
func ensure_english_voice() -> void:
	if english_voice_id == "":
		_init_tts()


func speak_word(text: String) -> void:
	if text.is_empty():
		return
	if not tts_enabled:
		return

	# Retry voice detection in case it failed at startup.
	ensure_english_voice()
	if english_voice_id == "":
		return

	if DisplayServer.tts_is_speaking():
		DisplayServer.tts_stop()

	# Real tts_speak() signature: (text, voice, volume, pitch, rate, utterance_id, interrupt)
	# volume is 0..100. The previous version had these shifted one slot over,
	# which put 0 into the volume slot (mute) and 100.0 into pitch (way out of range).
	DisplayServer.tts_speak(
		text,
		english_voice_id,
		100,  # volume (max, 0-100)
		1.0,    # pitch
		1.0,    # rate (normal speed)
		0,      # utterance_id
		true    # interrupt anything currently speaking
	)
