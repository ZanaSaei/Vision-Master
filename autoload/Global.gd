extends Node

# ============================================================
#  GLOBAL.GD — Autoload Singleton
#  Handles: loading lesson JSON data, and the saved-words system
# ============================================================

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


# ---------- SAVED WORDS SYSTEM ----------

const SAVED_WORDS_PATH  := "user://saved_words.json"
const PROGRESS_PATH     := "user://progress.json"

var current_book: int   = 1
var current_lesson: int = 1
var flashcard_mode: String = "lesson"
var _last_scene: String = ""
var saved_words: Array = []


func _ready() -> void:
	_load_saved_words()
	_load_progress()
	_load_word_database()


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


func _persist_saved_words() -> void:
	var file := FileAccess.open(SAVED_WORDS_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(saved_words))
	file.close()


func is_word_saved(word: String, book: int, lesson: int) -> bool:
	for entry in saved_words:
		if entry.get("word") == word and entry.get("book") == book and entry.get("lesson") == lesson:
			return true
	return false


func save_word(word_data: Dictionary) -> void:
	if is_word_saved(word_data.get("word"), word_data.get("book"), word_data.get("lesson")):
		return
	saved_words.append(word_data)
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


# ---------- ENHANCED WORD DATABASE ----------

func _load_word_database() -> void:
	"""Load all words from all vocabulary JSON files into the database"""
	word_database.clear()
	verb_forms.clear()
	
	var books := [1, 2, 3]
	for book in books:
		_load_words_from_book(book)
	
	print("Word database loaded: %d words" % word_database.size())


func _load_words_from_book(book: int) -> void:
	"""Load words from a specific book's vocabulary"""
	var vocab_path := "res://data/v%d_vocabularies.json" % book
	
	if not FileAccess.file_exists(vocab_path):
		return
	
	var file := FileAccess.open(vocab_path, FileAccess.READ)
	var text := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	if json.parse(text) != OK:
		return
	
	var data = json.data
	if not data is Array:
		return
	
	for lesson_data in data:
		var lesson = lesson_data.get("lesson", 0)
		var vocab = lesson_data.get("vocabulary", {})
		var words = vocab.get("words", [])
		
		for word_obj in words:
			var word = word_obj.get("word", "")
			if word != "":
				var key = word.to_lower()
				if not word_database.has(key):
					# Build enhanced word data
					var word_data = {
						"word": word,
						"meaning_en": word_obj.get("meaning_en", ""),
						"meaning_fa": word_obj.get("meaning_fa", ""),
						"example": word_obj.get("example", ""),
						"book": book,
						"lesson": lesson,
						"word_type": word_obj.get("word_type", "noun"),  # noun, verb, adjective, etc.
						"countable": word_obj.get("countable", null),  # true/false for nouns
						"verb_forms": word_obj.get("verb_forms", {})  # {past, past_participle, present_participle, third_person}
					}
					word_database[key] = word_data
					
					# If it's a verb, add all forms to verb_forms mapping
					if word_data["word_type"] == "verb":
						var forms = word_data["verb_forms"]
						var base_word = word_data["word"]
						
						# Map each form to the base word
						if forms.has("past"):
							verb_forms[forms["past"].to_lower()] = base_word
						if forms.has("past_participle"):
							verb_forms[forms["past_participle"].to_lower()] = base_word
						if forms.has("present_participle"):
							verb_forms[forms["present_participle"].to_lower()] = base_word
						if forms.has("third_person"):
							verb_forms[forms["third_person"].to_lower()] = base_word


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
	"""Try to find word in the current lesson's vocabulary"""
	var book = current_book
	var lesson = current_lesson
	
	var definition = get_word_definition(word)
	if not definition.is_empty():
		if definition.get("book") == book and definition.get("lesson") == lesson:
			return definition
	
	return get_word_definition(word)


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
