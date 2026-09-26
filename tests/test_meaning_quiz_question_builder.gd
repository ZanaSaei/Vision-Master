extends SceneTree

const BUILDER = preload("res://scenes/word_game/meaning_quiz_question_builder.gd")


func _initialize() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/extracted_words.json"))
	assert(data is Array)
	var words: Array[Dictionary] = []
	for raw: Variant in data:
		if raw is Dictionary:
			words.append(raw)
	var questions: Array[Dictionary] = BUILDER.build_questions(words)
	assert(not questions.is_empty())
	var valid_kinds: Array[String] = ["meaning", "synonym", "antonym"]
	var checked: int = 0
	for question: Dictionary in questions:
		assert(valid_kinds.has(str(question["kind"])))
		assert(question["options"].size() == 4)
		assert(question["options"].has(question["answer"]))
		assert(not str(question["prompt"]).contains("."))
		checked += 1
	print("Validated %d generated English competition questions" % checked)
	quit()
