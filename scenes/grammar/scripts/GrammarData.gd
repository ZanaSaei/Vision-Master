class_name GrammarData
extends RefCounted
# ============================================================
#  GRAMMAR DATA — static loader for grammar micro-lessons
# ------------------------------------------------------------
#  A lesson is a single JSON file at:
#      res://data/grammar/vision{book}_lesson{lesson}.json
#  To add a new lesson for another book/lesson, simply create that
#  file following the schema below — the rest of the system reads
#  it with no code changes.
#
#  SCHEMA (root = { "lesson": { ... } }):
#    lesson:
#      id, book, lesson_number, title_en, title_fa, icon, theme_color
#      xp_per_correct (int, default 10)
#      units: [ ... ]
#
#    A unit is a Dictionary with "type" and unit-specific fields:
#      { "type": "learn",
#        "title_fa", "title_en", "explanation",
#        "cards": [ { "en": "...", "fa": "..." } ] }     # structure patterns
#        # optional legacy: "structure": "..." and "examples": [ {en,fa} ]
#
#      { "type": "multiple_choice",
#        "instruction_fa",
#        "questions": [ { "question", "options": [ ... ],
#                        "correct": <index>, "explanation_fa",
#                        "wrong_explanation_fa" } ] }
#
#      { "type": "fill_blank",
#        "instruction_fa",
#        "items": [ { "text", "answers": [ ...accepted strings ],
#                    "explanation_fa", "wrong_explanation_fa" } ] }
#
#      { "type": "true_false",
#        "instruction_fa",
#        "items": [ { "statement", "answer": <bool>, "explanation_fa" } ] }
#
#      { "type": "matching",
#        "instruction_fa",
#        "items": [ { "left": "...", "right": "..." } ] }
#
#      { "type": "unscramble",
#        "instruction_fa",
#        "items": [ { "words": [ ... ], "answer": "correct sentence" } ] }
# ============================================================

const DIR := "res://data/grammar/"


static func path_for(book: int, lesson: int) -> String:
	return "%svision%d_lesson%d.json" % [DIR, book, lesson]


static func load_lesson(book: int, lesson: int) -> Dictionary:
	var path := path_for(book, lesson)
	if not FileAccess.file_exists(path):
		push_error("Grammar JSON not found: " + path)
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("Grammar JSON parse error at %s: %s" % [path, json.get_error_message()])
		return {}

	var data = json.data
	if not data is Dictionary:
		push_error("Grammar JSON root must be a Dictionary: " + path)
		return {}

	return data.get("lesson", {})
