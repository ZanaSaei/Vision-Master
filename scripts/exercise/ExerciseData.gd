class_name ExerciseData
extends RefCounted

## Wraps the raw JSON dictionary to provide typed, safe access and text normalization.

var raw: Dictionary

func _init(data: Dictionary) -> void:
	raw = data

func get_type() -> String:
	return str(raw.get("type", "open_ended"))

func get_id() -> String:
	return str(raw.get("exercise_id", ""))

func get_items() -> Array:
	return raw.get("items", [])

static func get_en_text(val: Variant) -> String:
	if val is Dictionary:
		return str(val.get("en", ""))
	return str(val)

static func get_fa_text(val: Variant) -> String:
	if val is Dictionary:
		return str(val.get("fa", ""))
	return ""

static func normalize(s: String) -> String:
	s = str(s).to_lower().strip_edges()
	s = s.replace(char(0x2019), "'").replace("'", " ")
	for ch in [".", ",", "!", "?", ";", ":", "“", "”", "(", ")", "[", "]", "{", "}", "/"]:
		s = s.replace(ch, " ")
	while s.contains("  "):
		s = s.replace("  ", " ")
	return s.strip_edges()

## Inner class representing a single gradable item within an exercise
class Item:
	var type: String
	var get_func: Callable      # Returns user answer
	var answer: Variant         # Expected answer
	var answer_display: String
	var feedback_label: Label
	var explanation_en: String
	var explanation_fa: String
	var compiled_patterns: Array[RegEx] = []
	var required_words: Array = []
	var forbidden_words: Array = []
	
	# Specific UI references
	var sample_label: Label = null
	var text_edit: TextEdit = null
	var word_button: Button = null

	func _init(p_type: String, p_get: Callable, p_answer: Variant, p_feedback: Label) -> void:
		type = p_type
		get_func = p_get
		answer = p_answer
		feedback_label = p_feedback
