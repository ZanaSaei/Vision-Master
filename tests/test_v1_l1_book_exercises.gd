extends Node

func test_v1_l1_book_exercises_json() -> void:
	var path: String = "res://data/grammar/v1_l1_book_exercises.json"
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert(file != null, "Workbook JSON must open")
	var json: JSON = JSON.new()
	assert(json.parse(file.get_as_text()) == OK, "Workbook JSON must parse: %s" % json.get_error_message())
	file.close()
	var root: Dictionary = json.data
	var workbook: Dictionary = root.get("book_exercises", {})
	var sections: Array = workbook.get("sections", [])
	assert(sections.size() == 4, "V1L1 workbook must contain only the supplied Parts A-D")
	assert(str(sections[0].get("exercise_id", "")) == "workbook_v1_l1_a_will_forms")
	assert(sections[0].get("items", []).size() == 5)
	assert(str(sections[1].get("exercise_id", "")) == "workbook_v1_l1_b_future_writing")
	assert(sections[1].get("items", []).size() == 4)
	assert(str(sections[2].get("exercise_id", "")) == "workbook_v1_l1_c_be_going_to")
	assert(sections[2].get("items", []).size() == 5)
	assert(str(sections[3].get("type", "")) == "cloze", "Alfredo text must use the interactive cloze renderer")
	assert(sections[3].get("blanks", []).size() == 6)
	assert(str(sections[3].get("passage", "")).contains("Tooran Plain"))
	print("V1L1 workbook validated: exactly Parts A-D with Alfredo cloze")
