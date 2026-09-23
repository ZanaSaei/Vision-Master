class_name ScrambledData
extends RefCounted
## ============================================================
##  SCRAMBLED DATA — the word bank behind «بازی املا».
##
##  Reads res://data/scrambled_words.json, a book > lesson > word list that
##  mirrors how the game is played: pick a book, pick a lesson, spell that
##  lesson's words. The daily challenge uses the same bank through
##  all_words(), which flattens it in a fixed order — the daily picker slices
##  that order, so nothing here may sort or shuffle it.
##
##  Word entries carry `word` (the thing to spell), `meaning` (the English
##  meaning, shown as the hint) and `meaning_fa` (the Persian meaning, the
##  optional second half of the hint).
##
##  Every read is guarded: a missing or unreadable file yields an empty bank
##  and the screens show a friendly "no words" card instead of breaking.
## ============================================================

const DATA_PATH := "res://data/scrambled_words.json"

static var _books: Array = []
static var _all_words: Array = []
static var _loaded := false


## ---------------------------------------------------------------- books --
## Books in file order: [{book, title, grade_fa, lesson_count, word_count,
## lessons: [...]}].
static func books() -> Array:
	_ensure_loaded()
	return _books


static func book_count() -> int:
	return books().size()


static func book_data(book_number: int) -> Dictionary:
	for entry in books():
		if int(entry["book"]) == book_number:
			return entry
	return {}


static func has_book(book_number: int) -> bool:
	return not book_data(book_number).is_empty()


static func book_label(book_number: int) -> String:
	var data := book_data(book_number)
	if data.is_empty():
		return "Vision %d" % book_number
	return str(data.get("title", "Vision %d" % book_number))


static func grade_label(book_number: int) -> String:
	return str(book_data(book_number).get("grade_fa", ""))


## -------------------------------------------------------------- lessons --
## Lessons of one book: [{lesson, title, title_fa, word_count, words: [...]}].
static func lessons(book_number: int) -> Array:
	var data := book_data(book_number)
	if data.is_empty():
		return []
	return data.get("lessons", [])


static func lesson_data(book_number: int, lesson_number: int) -> Dictionary:
	for entry in lessons(book_number):
		if int(entry["lesson"]) == lesson_number:
			return entry
	return {}


static func has_lesson(book_number: int, lesson_number: int) -> bool:
	return not lesson_data(book_number, lesson_number).is_empty()


## The Persian title of a lesson («شگفتی‌های آفرینش»), "" when it has none.
static func lesson_title_fa(book_number: int, lesson_number: int) -> String:
	return str(lesson_data(book_number, lesson_number).get("title_fa", ""))


## ---------------------------------------------------------------- words --
## The lesson's words in file order: [{word, meaning, meaning_fa}].
static func words(book_number: int, lesson_number: int) -> Array:
	var data := lesson_data(book_number, lesson_number)
	if data.is_empty():
		return []
	return data.get("words", [])


## The playable list of a lesson. `by_length` deals the short words first,
## which is the difficulty ramp learning mode plays.
static func words_ordered(book_number: int, lesson_number: int, by_length := true) -> Array:
	var list := words(book_number, lesson_number).duplicate()
	if by_length:
		list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var la := str(a["word"]).length()
			var lb := str(b["word"]).length()
			if la == lb:
				return str(a["word"]) < str(b["word"])
			return la < lb)
	return list


static func word_count(book_number: int, lesson_number: int) -> int:
	return words(book_number, lesson_number).size()


## Every word of every book, in file order, each tagged with its book/lesson.
## The daily picker depends on that order staying stable.
static func all_words() -> Array:
	_ensure_loaded()
	return _all_words


static func total_word_count() -> int:
	_ensure_loaded()
	return _all_words.size()
## ------------------------------------------------------------ internals --
## Drops the parsed copy so the next read re-parses the file. Used by tests
## after the bank on disk has been swapped.
static func reset_cache() -> void:
	_books = []
	_all_words = []
	_loaded = false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_books = []
	_all_words = []

	if not FileAccess.file_exists(DATA_PATH):
		push_warning("ScrambledData: %s is missing" % DATA_PATH)
		return
	var text := FileAccess.get_file_as_string(DATA_PATH)
	if text.is_empty():
		push_warning("ScrambledData: cannot read %s" % DATA_PATH)
		return

	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		push_warning("ScrambledData: %s is not readable JSON" % DATA_PATH)
		return
	var raw_books = (json.data as Dictionary).get("books", [])
	if not (raw_books is Array):
		return

	for raw_book in raw_books:
		if not (raw_book is Dictionary):
			continue
		var book_number := int(raw_book.get("book", 0))
		if book_number <= 0:
			continue
		var built_lessons: Array = []
		var book_words := 0
		for raw_lesson in raw_book.get("lessons", []):
			if not (raw_lesson is Dictionary):
				continue
			var lesson_number := int(raw_lesson.get("lesson", 0))
			if lesson_number <= 0:
				continue
			var built_words: Array = []
			for raw_word in raw_lesson.get("words", []):
				if not (raw_word is Dictionary):
					continue
				var spelling := str(raw_word.get("word", "")).strip_edges()
				if spelling.is_empty():
					continue
				var entry := {
					"word": spelling,
					"meaning": str(raw_word.get("meaning", "")).strip_edges(),
					"meaning_fa": str(raw_word.get("meaning_fa", "")).strip_edges(),
					# Tagged here, once: the controller and the practice record
					# both need to know which lesson a word came from.
					"book": book_number,
					"lesson": lesson_number,
				}
				built_words.append(entry)
				var flat := entry.duplicate()
				_all_words.append(flat)
			if built_words.is_empty():
				continue
			book_words += built_words.size()
			built_lessons.append({
				"lesson": lesson_number,
				"title": str(raw_lesson.get("title", "Lesson %d" % lesson_number)),
				"title_fa": str(raw_lesson.get("title_fa", "")),
				"word_count": built_words.size(),
				"words": built_words,
			})
		if built_lessons.is_empty():
			continue
		_books.append({
			"book": book_number,
			"title": str(raw_book.get("title", "Vision %d" % book_number)),
			"grade_fa": str(raw_book.get("grade_fa", "")),
			"lesson_count": built_lessons.size(),
			"word_count": book_words,
			"lessons": built_lessons,
		})
