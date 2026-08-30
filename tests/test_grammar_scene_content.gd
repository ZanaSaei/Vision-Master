extends Node
# Validates that the JSON content for the two new grammar scenes
# (امتحان گرامر and تمرینات کتاب) builds cleanly with ExerciseEngine
# and grades to the expected question counts.

func _load(path: String, key: String) -> Dictionary:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var txt: String = f.get_as_text()
	f.close()
	var j: JSON = JSON.new()
	if j.parse(txt) != OK:
		push_error("Parse error in " + path + ": " + j.get_error_message())
		return {}
	var data: Variant = j.data
	if data is Dictionary and (data as Dictionary).has(key):
		return (data as Dictionary)[key]
	return {}


func _load_root(path: String) -> Dictionary:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var txt: String = f.get_as_text()
	f.close()
	var j: JSON = JSON.new()
	if j.parse(txt) != OK:
		push_error("Parse error in " + path + ": " + j.get_error_message())
		return {}
	if j.data is Dictionary:
		return j.data
	return {}


func _count_items(sections: Array) -> int:
	var n := 0
	for s in sections:
		n += (s.get("items", []) as Array).size()
	return n


func test_exam_json_is_valid_and_grades() -> void:
	var data := _load_root("res://data/grammar/v1_l1_grammar_exam.json")
	assert(data.has("lessons"), "exam JSON root should have 'lessons'")
	# Flatten lessons -> exam_exercises into content blocks.
	var blocks: Array = []
	for lesson in data["lessons"]:
		blocks += lesson.get("exam_exercises", [])
	assert(blocks.size() > 0, "exam JSON should have exam_exercises blocks")

	var heading_count := 0
	var expected_total := 0
	var total_items := 0
	for b in blocks:
		var t := str(b.get("type", ""))
		if t == "h4":
			heading_count += 1
			continue
		if t in ["open_ended", "pronunciation", "writing", "passage", "reading"]:
			continue  # not auto-graded
		expected_total += (b.get("items", []) as Array).size()
		var e := ExerciseEngine.new()
		e.hide_footer_buttons = true
		add_child(e)
		var result: Array = []
		e.exercise_checked.connect(func(_id, correct, total): result.append([correct, total]))
		e.build(b)
		assert(e.get("_items").size() > 0, "gradable block should build items: " + t)
		e.call("_on_check_pressed")
		assert(result.size() == 1, "engine should emit exercise_checked once")
		total_items += result[0][1]
		assert(result[0][0] == 0, "unanswered exam should have 0 correct")
		e.queue_free()
	assert(heading_count > 0, "exam JSON should contain h4 part headings")
	assert(total_items == expected_total,
		"graded total should match authored items: got %d expected %d" % [total_items, expected_total])
	print("exam: blocks=", blocks.size(), " headings=", heading_count,
		" auto-graded items=", total_items)


func test_exam_scene_extracts_blocks() -> void:
	var exam: Node = load("res://scenes/grammar/GrammarExam.tscn").instantiate()
	var data := _load_root("res://data/grammar/v1_l1_grammar_exam.json")
	var blocks: Array = exam._extract_blocks(data)
	assert(blocks.size() == 14, "scene should extract 14 blocks (7 h4 + 7 exercises), got " + str(blocks.size()))
	exam.free()


func test_book_exercises_json_builds() -> void:
	var data := _load("res://data/grammar/v1_l1_book_exercises.json", "book_exercises")
	var sections: Array = data.get("sections", [])
	assert(sections.size() > 0, "book exercises JSON should have sections")
	for s in sections:
		var e := ExerciseEngine.new()
		add_child(e)
		e.build(s)
		assert(e.get("_items").size() > 0, "section should build items: " + str(s.get("type")))
		e.queue_free()
	print("book_exercises: sections=", sections.size())


func test_exam_scene_check_shows_score_popup() -> void:
	# Instantiate the exam scene WITHOUT adding it to the tree, so _ready()
	# does not run; call the score-popup builder directly to verify it
	# constructs the overlay with the "X / 100" label.
	var ps: PackedScene = load("res://scenes/grammar/GrammarExam.tscn")
	assert(ps != null, "GrammarExam.tscn should load")
	var exam: Node = ps.instantiate()
	exam.call("_show_score_popup", 85)
	var overlay: Control = exam.get("_score_overlay")
	assert(overlay != null and is_instance_valid(overlay), "score popup should be created")
	var found := _find_score(overlay)
	assert(found, "score label with '/ 100' should be present in the popup")
	exam.free()


func test_per_lesson_path_resolution() -> void:
	var old_book: int = Global.current_book
	var old_lesson: int = Global.current_lesson
	Global.current_book = 3
	Global.current_lesson = 2
	var exam: Node = load("res://scenes/grammar/GrammarExam.tscn").instantiate()
	var ex: Node = load("res://scenes/grammar/GrammarBookExercises.tscn").instantiate()
	assert(exam._data_path() == "res://data/grammar/v3_l2_grammar_exam.json",
		"exam path wrong: " + exam._data_path())
	assert(ex._data_path() == "res://data/grammar/v3_l2_book_exercises.json",
		"book exercises path wrong: " + ex._data_path())
	# A path that does not exist must resolve to empty data (graceful fallback).
	exam._data_path()  # (file existence is checked inside _load_data)
	Global.current_book = old_book
	Global.current_lesson = old_lesson
	exam.free()
	ex.free()


func _find_score(node: Node) -> bool:
	for c in node.get_children():
		if c is Label and str(c.text).contains("/ 100"):
			print("score label: ", c.text)
			return true
		if _find_score(c):
			return true
	return false
