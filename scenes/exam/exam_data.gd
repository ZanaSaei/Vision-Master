class_name ExamData
extends RefCounted
## ============================================================
##  EXAM DATA — plain data-access helper for the "امتحانات نهایی"
##  (Final Exams) feature.
##
##  The content lives in JSON files:
##    res://data/final_exams/manifest.json   → years + exam index
##    res://data/final_exams/<id>.json       → one exam (blocks)
##
##  This class only reads and validates that data. It owns no
##  nodes and no presentation, so the year-picker, exam-list and
##  exam-runner scenes can share a single, consistent loader.
## ============================================================

const MANIFEST_PATH: String = "res://data/final_exams/manifest.json"


## Reads and parses the exam manifest. Returns {} on any failure.
static func load_manifest() -> Dictionary:
	return _read_json(MANIFEST_PATH)


## Reads and parses one exam file by its res:// path. Returns {} on failure.
static func load_exam(exam_path: String) -> Dictionary:
	return _read_json(exam_path)


## Returns the list of years from the manifest (each a Dictionary).
static func years() -> Array:
	return load_manifest().get("years", [])


## Returns a single year Dictionary by its id (e.g. "12"), or {} if absent.
static func year_by_id(year_id: String) -> Dictionary:
	for year in years():
		if str(year.get("id", "")) == year_id:
			return year
	return {}


## Returns the exams of a year, sorted newest-to-oldest by date_key.
static func exams_for_year(year_id: String) -> Array:
	var exams: Array = year_by_id(year_id).get("exams", []).duplicate()
	exams.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("date_key", 0)) > int(b.get("date_key", 0)))
	return exams


## Reads a JSON file into a Dictionary; logs and returns {} on error.
static func _read_json(path: String) -> Dictionary:
	# An empty path is "no exam selected" (the scene opened directly or a stale
	# deep link) — a benign, expected state, so it degrades to {} without the
	# noisy error a genuinely missing file deserves.
	if path.is_empty():
		return {}
	if not FileAccess.file_exists(path):
		push_error("ExamData: file not found: " + path)
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("ExamData: cannot open: " + path)
		return {}
	var text: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		push_error("ExamData: JSON parse error in %s: %s" % [path, json.get_error_message()])
		return {}
	var data: Variant = json.data
	if data is Dictionary:
		return data
	push_error("ExamData: expected a JSON object in " + path)
	return {}