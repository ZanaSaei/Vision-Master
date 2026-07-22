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

const DICTIONARY_PATH := "res://data/v_dictionary.json"

# ---------- VOCABULARY DATA LOADING ----------

var intro_animation_played := false

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


func _ready() -> void:
	_load_saved_words()
	_load_review_words()
	_load_progress()
	_load_word_database()
	_init_tts()


# ---------- LAST SCENE ----------

func set_last_scene(scene_path: String) -> void:
	_last_scene = scene_path
	_save_progress()


func get_last_scene() -> String:
	return _last_scene


func has_last_scene() -> bool:
	return _last_scene != ""


# ---------- PROGRESS PERSISTENCE ----------

func _save_progress() -> void:
	var data := {"last_scene": _last_scene}
	var file := FileAccess.open(PROGRESS_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


func _load_progress() -> void:
	if not FileAccess.file_exists(PROGRESS_PATH):
		return
	var file := FileAccess.open(PROGRESS_PATH, FileAccess.READ)
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) == OK and json.data is Dictionary:
		_last_scene = json.data.get("last_scene", "")


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
	"audio": word_obj.get("audio", "")
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


func _compute_srs_result(entry: Dictionary, rating: String) -> Dictionary:
	var ease: float     = entry.get("srs_ease", 2.5)
	var interval: float = entry.get("srs_interval", 0.0)
	var reps: int        = entry.get("srs_reps", 0)
	var today := _today_day_number()

	var new_ease := ease
	var new_interval := interval
	var new_reps := reps

	match rating:
		"again":
			new_reps = 0
			new_ease = max(1.3, ease - 0.2)
			new_interval = 0.0
		"hard":
			new_ease = max(1.3, ease - 0.15)
			new_interval = max(1.0, (interval if interval > 0 else 1.0) * 1.2)
			new_reps = reps + 1
		"good":
			if reps == 0:
				new_interval = 1.0
			elif reps == 1:
				new_interval = 3.0
			else:
				new_interval = interval * ease
			new_reps = reps + 1
		"easy":
			if reps == 0:
				new_interval = 2.0
			else:
				new_interval = interval * ease * 1.3
			new_ease = ease + 0.15
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

func _init_tts() -> void:
	var voices = DisplayServer.tts_get_voices_for_language("en")

	if voices.size() > 0:
		english_voice_id = voices[0]
	else:
		var all_voices = DisplayServer.tts_get_voices()
		for voice in all_voices:
			if "en" in voice.to_lower():
				english_voice_id = voice
				break

	if english_voice_id == "":
		push_warning("No English TTS voice found on this device.")

func speak_word(text: String) -> void:
	if text.is_empty() or english_voice_id == "":
		return

	if DisplayServer.tts_is_speaking():
		DisplayServer.tts_stop()

	DisplayServer.tts_speak(text, english_voice_id, 50, 1.0, 1.0)
