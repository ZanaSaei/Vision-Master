extends Node

func test_v1_l1_grammar_exam_json() -> void:
	var path: String = "res://data/grammar/v1_l1_grammar_exam.json"
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert(file != null, "Exam JSON must open")
	var json: JSON = JSON.new()
	assert(json.parse(file.get_as_text()) == OK, "Exam JSON must parse: %s" % json.get_error_message())
	file.close()
	var data: Dictionary = json.data
	var lessons: Array = data.get("lessons", [])
	assert(lessons.size() == 1, "Expected one V1L1 exam")
	var blocks: Array = lessons[0].get("exam_exercises", [])
	var found_parts: Dictionary = {}
	var auto_gradable_count: int = 0
	var objective_points: int = 0
	var writing_points: int = 0
	for block in blocks:
		if str(block.get("type", "")) == "h4":
			var label: String = str(block.get("text", ""))
			for part_number in range(1, 8):
				if label.begins_with("Part %d" % part_number):
					found_parts[part_number] = true
		elif str(block.get("type", "")) in ["writing", "open_ended"]:
			writing_points += int(block.get("score_points", 0))
		elif str(block.get("type", "")) not in ["passage", "reading"]:
			var item_count: int = block.get("items", []).size()
			auto_gradable_count += item_count
			objective_points += item_count * int(block.get("points_per_item", 1))
	assert(found_parts.size() == 7, "All seven parts must be present")
	assert(auto_gradable_count == 33, "Expected 33 objectively gradable items")
	assert(str(blocks[blocks.size() - 1].get("type", "")) == "writing", "Part 7 must be writing")
	assert(objective_points == 90, "Parts 1-6 must total 90 points")
	assert(writing_points == 10, "Part 7 must reserve 10 points for teacher scoring")
	print("V1L1 grammar exam validated: 7 parts, 33 auto-gradable items, 90 objective + 10 teacher points")
