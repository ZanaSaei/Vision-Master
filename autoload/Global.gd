extends Node

signal review_words_changed()

# ============================================================
#  GLOBAL.GD — Autoload Singleton
#  Handles: loading lesson JSON data, and the saved-words system
# ============================================================

# ============================================================
# TTS (Text-To-Speech) Engine
# ============================================================
var english_voice_id: String = ""
var _category_cache: Dictionary = {}

const DICTIONARY_PATH := "res://data/v_dictionary.json"

var word_review_return: String = ""
# ---------- VOCABULARY DATA LOADING ----------

var intro_animation_played := false

var audio_player: AudioStreamPlayer

# Word database for quick lookup
var word_database: Dictionary = {}

# Verb forms mapping
var verb_forms: Dictionary = {}


func load_vocabulary(book_number: int, lesson_number: int) -> Dictionary:
	var path := "res://data/v%d_vocabularies.json" % book_number

	if not FileAccess.file_exists(path):
		push_error("Vocabulary file not found: " + path)
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(text)
	if error != OK:
		push_error("Failed to parse JSON at %s — %s" % [path, json.get_error_message()])
		return {}

	var data = json.data

	if not data is Array:
		push_error("Invalid JSON format: expected array of lessons")
		return {}

	for lesson_data in data:
		if lesson_data.get("book") == book_number and lesson_data.get("lesson") == lesson_number:
			return lesson_data

	push_error("Lesson %d not found in book %d" % [lesson_number, book_number])
	return {}


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
	if not FileAccess.file_exists(path):
		push_error("File not found: " + path)
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(text)
	if error != OK:
		push_error("Failed to parse JSON at %s — %s" % [path, json.get_error_message()])
		return {}

	var data = json.data
	if not data is Array:
		push_error("Invalid JSON format at %s: expected a flat array of lesson entries" % path)
		return {}

	for entry in data:
		if entry.get("book") == book_number and entry.get("lesson") == lesson_number:
			return entry

	return {}


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
var flashcard_mode: String = "lesson"
var _last_scene: String = ""
var saved_words: Array = []
var review_words: Array = []
var grammar_unlocked_units: Dictionary = {}
var grammar_start_unit_index: int = 0
var grammar_xp: Dictionary = {}
# Per lesson ("book_lesson") -> Array of بخش indices already completed, so XP
# is only awarded once per unit (never on replays).
var grammar_completed_units: Dictionary = {}

# ---------- APP SETTINGS ----------
const SETTINGS_PATH := "user://settings.json"
var sound_enabled: bool = true   # UI sound effects (Sfx autoload)
var tts_enabled: bool = true     # English text-to-speech pronunciation


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


func save_settings() -> void:
	var data: Dictionary = {
		"sound_enabled": sound_enabled,
		"tts_enabled": tts_enabled,
	}
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


func _ready() -> void:
	_load_saved_words()
	_load_review_words()
	_load_progress()
	_load_word_database()
	_load_settings()
	_init_tts() # You can keep or remove TTS init, keeping it for safety
	
	# Initialize AudioStreamPlayer for playing word audio files
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)

# ---------- LAST SCENE ----------

func set_last_scene(scene_path: String) -> void:
	_last_scene = scene_path
	_save_progress()


func get_last_scene() -> String:
	return _last_scene


func has_last_scene() -> bool:
	return _last_scene != ""


func _grammar_unlock_key(book: int, lesson: int) -> String:
	return "%d_%d" % [book, lesson]


func get_grammar_unlocked_units(book: int, lesson: int, total_units: int = 0) -> int:
	var key: String = _grammar_unlock_key(book, lesson)
	var unlocked: int = int(grammar_unlocked_units.get(key, 1))
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
	_save_progress()
	return total


func get_total_grammar_xp() -> int:
	var total := 0
	for value in grammar_xp.values():
		total += int(value)
	return total


# ---------- GRAMMAR COMPLETED UNITS ----------

func is_unit_completed(book: int, lesson: int, unit_index: int) -> bool:
	var key: String = _grammar_unlock_key(book, lesson)
	var completed: Array = grammar_completed_units.get(key, [])
	return unit_index in completed


func mark_unit_completed(book: int, lesson: int, unit_index: int) -> void:
	var key: String = _grammar_unlock_key(book, lesson)
	var completed: Array = grammar_completed_units.get(key, [])
	if not (unit_index in completed):
		completed.append(unit_index)
		grammar_completed_units[key] = completed
		_save_progress()


# ---------- PROGRESS PERSISTENCE ----------

func _save_progress() -> void:
	var data: Dictionary = {
		"last_scene": _last_scene,
		"grammar_unlocked_units": grammar_unlocked_units,
		"grammar_xp": grammar_xp,
		"grammar_completed_units": grammar_completed_units,
	}
	var file: FileAccess = FileAccess.open(PROGRESS_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


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


func _load_saved_words() -> void:
	if not FileAccess.file_exists(SAVED_WORDS_PATH):
		saved_words = []
		return

	var file := FileAccess.open(SAVED_WORDS_PATH, FileAccess.READ)
	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) == OK and json.data is Array:
		saved_words = json.data
	else:
		saved_words = []

func _load_review_words() -> void:
	if not FileAccess.file_exists(REVIEW_WORDS_PATH):
		review_words = []
		return

	var file := FileAccess.open(REVIEW_WORDS_PATH, FileAccess.READ)
	var text := file.get_as_text()
	file.close()

	var json := JSON.new()

	if json.parse(text) == OK and json.data is Array:
		review_words = json.data
	else:
		review_words = []

func _persist_saved_words() -> void:
	var file := FileAccess.open(SAVED_WORDS_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(saved_words))
	file.close()

func _persist_review_words() -> void:
	var file := FileAccess.open(REVIEW_WORDS_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(review_words))
	file.close()

func is_word_saved(word: String, book: int, lesson: int) -> bool:
	for entry in saved_words:
		if entry.get("word") == word and entry.get("book") == book and entry.get("lesson") == lesson:
			return true
	return false


func save_word(word_data: Dictionary) -> void:

	if is_word_saved(
		word_data.get("word"),
		word_data.get("book"),
		word_data.get("lesson")
	):
		return

	var copy = word_data.duplicate(true)

	saved_words.append(copy)
	add_review_word(copy)

	_persist_saved_words()


func remove_word(word: String, book: int, lesson: int) -> void:
	for i in range(saved_words.size()):
		var entry = saved_words[i]
		if entry.get("word") == word and entry.get("book") == book and entry.get("lesson") == lesson:
			saved_words.remove_at(i)
			break
	_persist_saved_words()


func get_saved_words() -> Array:
	return saved_words

func add_review_word(word_data: Dictionary) -> void:

	for entry in review_words:
		if entry.get("word") == word_data.get("word") \
		and entry.get("book") == word_data.get("book") \
		and entry.get("lesson") == word_data.get("lesson"):
			return

	review_words.append(word_data.duplicate(true))
	_persist_review_words()
	review_words_changed.emit()

func remove_review_word(word:String, book:int, lesson:int) -> void:

	for i in range(review_words.size()):

		var entry = review_words[i]

		if entry.get("word") == word \
		and entry.get("book") == book \
		and entry.get("lesson") == lesson:

			review_words.remove_at(i)
			break

	_persist_review_words()
	review_words_changed.emit()


func get_review_words() -> Array:
	return review_words


# ---------- DATA MANAGEMENT (used by the Settings screen) ----------

func clear_saved_words() -> void:
	saved_words.clear()
	_persist_saved_words()
	review_words_changed.emit()


func clear_review_words() -> void:
	review_words.clear()
	_persist_review_words()
	review_words_changed.emit()


func reset_all_progress() -> void:
	saved_words.clear()
	review_words.clear()
	grammar_unlocked_units.clear()
	grammar_xp.clear()
	grammar_completed_units.clear()
	_last_scene = ""
	_persist_saved_words()
	_persist_review_words()
	_save_progress()
	review_words_changed.emit()


# ---------- ENHANCED WORD DATABASE ----------

func _load_word_database() -> void:
	"""Load every word from the single unified dictionary file into the database"""
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


func get_word_definition(word: String) -> Dictionary:
	"""Get definition for a word from the database"""
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

	# Try removing plural 's' for nouns
	if key.ends_with("s") and len(key) > 1:
		var singular = key.trim_suffix("s")
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
	_load_word_database()


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


func _today_day_number() -> int:
	return int(Time.get_unix_time_from_system() / 86400.0)


func _ensure_srs_fields(entry: Dictionary) -> void:
	if not entry.has("srs_interval"):
		entry["srs_interval"] = 0.0
	if not entry.has("srs_ease"):
		entry["srs_ease"] = 2.5
	if not entry.has("srs_reps"):
		entry["srs_reps"] = 0
	if not entry.has("srs_due"):
		entry["srs_due"] = -1   # -1 means "new, never studied"


func get_due_words() -> Array:
	var today := _today_day_number()
	var due: Array = []
	var new_count := 0

	for entry in review_words:
		_ensure_srs_fields(entry)
		if entry["srs_due"] == -1:
			if new_count < SRS_NEW_CARDS_PER_SESSION:
				due.append(entry)
				new_count += 1
		elif entry["srs_due"] <= today:
			due.append(entry)

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
	var ease_factor: float = entry.get("srs_ease", 2.5)
	var interval: float = entry.get("srs_interval", 0.0)
	var reps: int        = entry.get("srs_reps", 0)
	var today := _today_day_number()

	var new_ease := ease_factor
	var new_interval := interval
	var new_reps := reps

	match rating:
		"again":
			new_reps = 0
			new_ease = max(1.3, ease_factor - 0.2)
			new_interval = 0.0
		"hard":
			new_ease = max(1.3, ease_factor - 0.15)
			new_interval = max(1.0, (interval if interval > 0 else 1.0) * 1.2)
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
				new_interval = 2.0
			else:
				new_interval = interval * ease_factor * 1.3
			new_ease = ease_factor + 0.15
			new_reps = reps + 1

	var new_due: int
	if rating == "again":
		new_due = today
	else:
		new_due = today + int(ceil(new_interval))

	return {
		"ease": new_ease,
		"interval": new_interval,
		"reps": new_reps,
		"due": new_due
	}


func review_word(word: String, book: int, lesson: int, rating: String) -> void:
	for entry in saved_words:
		if entry.get("word") == word and entry.get("book") == book and entry.get("lesson") == lesson:
			_ensure_srs_fields(entry)
			var result := _compute_srs_result(entry, rating)
			entry["srs_ease"]     = result["ease"]
			entry["srs_interval"] = result["interval"]
			entry["srs_reps"]     = result["reps"]
			entry["srs_due"]      = result["due"]
			break
	_persist_saved_words()


func preview_intervals(entry: Dictionary) -> Dictionary:
	_ensure_srs_fields(entry)
	var result := {}
	for rating in ["again", "hard", "good", "easy"]:
		var r := _compute_srs_result(entry, rating)
		result[rating] = _format_interval(r["interval"], rating)
	return result


func _format_interval(interval: float, rating: String) -> String:
	if rating == "again":
		return "چند دقیقه دیگر"
	var days := int(round(interval))
	if days < 1:
		return "امروز"
	elif days == 1:
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
		
	# 2. Check if the file actually exists in the project
	if not ResourceLoader.exists(path):
		push_warning("Audio file not found: " + path + ". Falling back to TTS.")
		if word_text != "":
			speak_word(word_text)
		return
		
	# 3. Try to load and play the audio file
	var stream = load(path)
	if stream is AudioStream:
		if audio_player.playing:
			audio_player.stop() # Stop current audio if it's still playing
		audio_player.stream = stream
		audio_player.play()
	else:
		# 4. Fallback if the file exists but fails to load (e.g., corrupted file)
		push_error("Failed to load audio stream from: " + path + ". Falling back to TTS.")
		if word_text != "":
			speak_word(word_text)

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
