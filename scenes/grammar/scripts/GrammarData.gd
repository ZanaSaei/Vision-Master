class_name GrammarData
extends RefCounted
# ============================================================
# GRAMMAR DATA — static loader & XP mastery calculator
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
			return "📚"
		"learn":
			return "💡"
		"multiple_choice":
			return "🎯"
		"fill_blank":
			return "✍️"
		"true_false":
			return "✅"
		"matching":
			return "🔗"
		"unscramble":
			return "🧩"
		_:
			return "⭐"


static func unit_title(unit: Dictionary) -> String:
	var title: String = str(unit.get("title_fa", ""))
	if title.is_empty():
		title = str(unit.get("instruction_fa", ""))
	if title.is_empty():
		title = str(unit.get("type", "Unit"))
	return title


static func unit_label(unit: Dictionary) -> String:
	return "%s\n%s" % [unit_icon(unit), unit_title(unit)]


# ============================================================
# XP & MASTERY PROGRESSION SYSTEM
# ============================================================
# Returns a dictionary with:
# - current_xp: int
# - max_xp: int (base XP from all units + flawless/exam potential)
# - completed_units: int
# - total_units: int
# - progress_ratio: float (0.0 to 1.0)
# - rank_title_fa: String
# - rank_icon: String
# - rank_color: Color
# - next_rank_xp: int (XP needed to reach next rank, 0 if maxed)
static func get_mastery_status(book: int, lesson: int) -> Dictionary:
	var lesson_dict := load_lesson(book, lesson)
	var units: Array = lesson_dict.get("units", [])
	var xp_per_unit: int = int(lesson_dict.get("xp_per_unit", 10))
	var total_units: int = units.size()
	var completed_count: int = 0

	for i in range(total_units):
		var u: Dictionary = units[i]
		if Global.is_unit_completed(book, lesson, i, str(u.get("id", ""))):
			completed_count += 1

	var current_xp: int = Global.get_grammar_xp(book, lesson)
	# Base max XP is total_units * xp_per_unit (minimum 50 so empty/small lessons still scale nicely)
	var base_max_xp: int = maxi(total_units * xp_per_unit, 50)
	# If the student earned flawless bonuses or exam XP beyond base_max_xp, expand ceiling gracefully
	var max_xp: int = maxi(base_max_xp, current_xp)
	var ratio: float = clampf(float(current_xp) / float(base_max_xp), 0.0, 1.0)

	var rank_title := "مبتدی"
	var rank_icon := "🌱"
	var rank_color := Color("#94A3B8")
	var next_threshold := int(ceil(base_max_xp * 0.25))

	if ratio >= 1.0:
		rank_title = "استاد گرامر"
		rank_icon = "🏆"
		rank_color = Color("#F59E0B") # Gold
		next_threshold = 0
	elif ratio >= 0.75:
		rank_title = "حرفه‌ای"
		rank_icon = "👑"
		rank_color = Color("#A855F7") # Purple
		next_threshold = base_max_xp
	elif ratio >= 0.50:
		rank_title = "مسلط"
		rank_icon = "⚡"
		rank_color = Color("#06B6D4") # Cyan
		next_threshold = int(ceil(base_max_xp * 0.75))
	elif ratio >= 0.25 or current_xp > 0:
		rank_title = "یادگیرنده"
		rank_icon = "📘"
		rank_color = Color("#10B981") # Emerald
		next_threshold = int(ceil(base_max_xp * 0.50))

	var xp_to_next: int = maxi(0, next_threshold - current_xp)

	return {
		"current_xp": current_xp,
		"max_xp": max_xp,
		"base_max_xp": base_max_xp,
		"completed_units": completed_count,
		"total_units": total_units,
		"progress_ratio": ratio,
		"rank_title_fa": rank_title,
		"rank_icon": rank_icon,
		"rank_color": rank_color,
		"xp_to_next": xp_to_next
	}
