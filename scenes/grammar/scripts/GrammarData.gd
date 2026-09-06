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

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var err: Error = json.parse(text)
	if err != OK:
		push_error("Grammar JSON parse error at %s: %s" % [path, json.get_error_message()])
		return {}

	var data: Variant = json.data
	if not data is Dictionary:
		push_error("Grammar JSON root must be a Dictionary: " + path)
		return {}

	var lesson_dict: Dictionary = (data as Dictionary).get("lesson", {})
	# Validate units up front so a malformed file can never silently award
	# XP / progress for an empty group (see GrammarLesson._show_current_activity):
	# drop group units that carry no activities and warn loudly instead.
	var units: Array = lesson_dict.get("units", [])
	var valid: Array = []
	for unit in units:
		if not unit is Dictionary:
			push_warning("GrammarData: skipping non-dictionary unit in " + path)
			continue
		var unit_type := str(unit.get("type", ""))
		if unit_type == "group" and not (unit.get("activities", []) is Array and not (unit.get("activities", []) as Array).is_empty()):
			push_warning("GrammarData: group unit '%s' has no activities; skipped in %s" % [str(unit.get("id", "?")), path])
			continue
		valid.append(unit)
	lesson_dict["units"] = valid
	return lesson_dict


static func unit_icon(unit: Dictionary) -> String:
	match str(unit.get("type", "")):
		"group":
			return "🗂️"
		"learn":
			return "📚"
		"multiple_choice":
			return "🟣"
		"fill_blank":
			return "📝"
		"true_false":
			return "✅"
		"matching":
			return "🔗"
		"unscramble":
			return "🔀"
		_:
			return "📦"


static func unit_title(unit: Dictionary) -> String:
	var title: String = str(unit.get("title_fa", ""))
	if title.is_empty():
		title = str(unit.get("instruction_fa", ""))
	if title.is_empty():
		title = str(unit.get("type", "Unit"))
	return title


static func unit_label(unit: Dictionary) -> String:
	return "%s\n%s" % [unit_icon(unit), unit_title(unit)]
