extends Node

# ============================================================
#  GLOBAL.GD — Autoload Singleton
#  Handles: loading lesson JSON data, and the saved-words system
# ============================================================


# ---------- VOCABULARY DATA LOADING ----------
# NOTE: JSON files only contain vocabulary data. Conversation, Reading,
# Grammar, and Speaking content is built directly into their own scenes.

# Loads res://data/v{book}_l{lesson}.json and returns it as a Dictionary
func load_vocabulary(book_number: int, lesson_number: int) -> Dictionary:
	var path := "res://data/v%d_l%d.json" % [book_number, lesson_number]

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

	return json.data


# Builds the full resource path to an audio file for a given book/lesson.
# Example: Global.get_audio_path(1, 1, "vocab.mp3") -> "res://assets/audio/v1/l1/vocab.mp3"
func get_audio_path(book_number: int, lesson_number: int, filename: String) -> String:
	return "res://assets/audio/v%d/l%d/%s" % [book_number, lesson_number, filename]


# ---------- SAVED WORDS SYSTEM ----------

const SAVED_WORDS_PATH  := "user://saved_words.json"
const PROGRESS_PATH     := "user://progress.json"

# Which book + lesson are currently selected
var current_book: int   = 1
var current_lesson: int = 1

# Controls whether VocabFlashcards loads lesson words or saved words
# "lesson" = normal New Words screen | "saved" = Saved Words screen
var flashcard_mode: String = "lesson"

# Last scene the user visited — used by the Continue button
var _last_scene: String = ""

var saved_words: Array = []

func _ready() -> void:
	_load_saved_words()
	_load_progress()


# ---------- LAST SCENE (Continue Learning) ----------

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


# A word is uniquely identified by its text + which book/lesson it came from
# (since "left" could appear as a vocab word in more than one lesson someday)
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
