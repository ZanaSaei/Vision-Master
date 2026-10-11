extends Node

func test_v1_l2_book_exercises_json() -> void:
	var path: String = "res://data/grammar/v1_l2_book_exercises.json"
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert(file != null, "V1L2 workbook JSON must open")
	var json: JSON = JSON.new()
	assert(json.parse(file.get_as_text()) == OK, "V1L2 workbook JSON must parse: %s" % json.get_error_message())
	file.close()
	var sections: Array = json.data.get("book_exercises", {}).get("sections", [])
	assert(sections.size() == 8, "Expected three existing and five supplied workbook sections")
	assert(str(sections[3].get("exercise_id", "")) == "workbook_v1_l2_a_best_sentence")
	assert(sections[3].get("items", []).size() == 4)
	assert(str(sections[4].get("exercise_id", "")) == "workbook_v1_l2_b_make_sentences")
	assert(sections[4].get("items", []).size() == 4)
	assert(str(sections[5].get("exercise_id", "")) == "workbook_v1_l2_c_comparative_superlative_forms")
	assert(sections[5].get("rows", []).size() == 6)
	assert(str(sections[6].get("type", "")) == "word_bank")
	assert(sections[6].get("items", []).size() == 5)
	assert(str(sections[7].get("type", "")) == "word_bank")
	assert(sections[7].get("items", []).size() == 4)
	assert(sections[7].get("word_bank", []).size() == 5, "Part E includes the extra adjective")
	print("V1L2 workbook validated: A-E and 23 exercise items/cells")
