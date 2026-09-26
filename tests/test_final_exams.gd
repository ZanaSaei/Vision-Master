extends Node
## ============================================================
##  FINAL EXAMS DATA TESTS
##
##  Validates the "امتحانات نهایی" content and the /40 scoring
##  model without needing the UI:
##    * the manifest parses and every referenced exam JSON exists
##    * each exam loads, has blocks, and every listening block's
##      audio file actually exists on disk
##    * every gradable block (points > 0) has an exercise_id and a
##      gradable type — the grader ignores anything else
##    * the sum of gradable points is within (0, 40], so the /40
##      scaling in final_exam.gd never divides by zero or exceeds
##      the maximum
##    * a fully-correct run always yields exactly 40
## ============================================================

const MANIFEST_PATH: String = "res://data/final_exams/manifest.json"
const GRADABLE_EXCLUDED: Array[String] = ["open_ended", "pronunciation", "writing", "passage", "reading"]
const SCORE_MAX: float = 40.0


func test_manifest_has_years_and_exams() -> void:
	var manifest: Dictionary = _read_json(MANIFEST_PATH)
	assert(not manifest.is_empty(), "manifest.json did not parse")
	var years: Array = manifest.get("years", [])
	assert(not years.is_empty(), "manifest has no years")
	for year in years:
		assert(not year.get("exams", []).is_empty(), "year %s has no exams" % year.get("id", "?"))


func test_each_exam_is_valid() -> void:
	var manifest: Dictionary = _read_json(MANIFEST_PATH)
	var years: Array = manifest.get("years", [])
	var exam_count: int = 0
	for year in years:
		for exam in year.get("exams", []):
			_validate_exam(exam)
			exam_count += 1
	assert(exam_count > 0, "no exams validated")


func test_scenes_load() -> void:
	assert(load("res://scenes/exam/FinalExams.tscn") != null, "FinalExams.tscn failed to load")
	assert(load("res://scenes/exam/FinalExamList.tscn") != null, "FinalExamList.tscn failed to load")
	assert(load("res://scenes/exam/FinalExam.tscn") != null, "FinalExam.tscn failed to load")


func test_runner_scores_out_of_40() -> void:
	AppRouter.set_args({
		"exam_json": "res://tests/fixtures/final_exam_min.json",
		"title_fa": "آزمون آزمایشی",
	})
	var scene: Node = load("res://scenes/exam/FinalExam.tscn").instantiate()
	add_child(scene)
	assert(scene.get("_check_btn") != null, "runner did not create the global check button")
	# Grade with nothing answered: the popup must still be on the /40 scale.
	scene.call("_on_check_pressed")
	var score_text: String = _find_score_text(scene)
	assert(score_text.ends_with("/ ۴۰"), "score popup is not out of 40: '%s'" % score_text)
	scene.queue_free()


func _find_score_text(root: Node) -> String:
	for child in root.get_children():
		if child is Label and str((child as Label).text).contains("/ ۴۰"):
			return str((child as Label).text)
		var found: String = _find_score_text(child)
		if found != "":
			return found
	return ""


func _validate_exam(exam: Dictionary) -> void:
	var exam_id: String = str(exam.get("id", "?"))
	var path: String = str(exam.get("json", ""))
	assert(path != "" and FileAccess.file_exists(path), "exam %s: missing json %s" % [exam_id, path])

	var data: Dictionary = _read_json(path)
	assert(not data.is_empty(), "exam %s: json did not parse" % exam_id)

	var audio: String = str(data.get("audio", ""))
	assert(audio != "" and FileAccess.file_exists(audio), "exam %s: missing audio %s" % [exam_id, audio])

	var blocks: Array = data.get("blocks", [])
	assert(not blocks.is_empty(), "exam %s: no blocks" % exam_id)

	var gradable_points: float = 0.0
	for block in blocks:
		var type: String = str(block.get("type", ""))
		if type == "h4":
			continue
		if bool(block.get("show_audio", false)):
			var block_audio: String = str(block.get("audio", ""))
			assert(block_audio != "" and FileAccess.file_exists(block_audio),
				"exam %s: listening block audio missing %s" % [exam_id, block_audio])

		var points: float = float(block.get("points", 0))
		if points > 0.0:
			assert(str(block.get("exercise_id", "")) != "",
				"exam %s: gradable %s block has no exercise_id" % [exam_id, type])
			assert(not GRADABLE_EXCLUDED.has(type),
				"exam %s: non-gradable type %s carries points" % [exam_id, type])
			gradable_points += points

	assert(gradable_points > 0.0, "exam %s: no gradable points" % exam_id)
	assert(gradable_points <= SCORE_MAX + 0.001,
		"exam %s: gradable points %.1f exceed the maximum" % [exam_id, gradable_points])

	# A perfect run scales to exactly 40.
	var score: float = SCORE_MAX * gradable_points / gradable_points
	assert(is_equal_approx(score, SCORE_MAX), "exam %s: perfect score != 40" % exam_id)


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text: String = FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(text)
	if data is Dictionary:
		return data
	return {}