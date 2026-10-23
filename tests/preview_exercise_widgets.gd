extends Control
## ============================================================
##  Widget preview — run with run_scene on TestExerciseWidgets.tscn to eyeball
##  the ExerciseEngine widgets after a theme/widget change. Builds one engine
##  per exercise type inside a scrollable VBox (no app navigation needed).
## ============================================================

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Global.get_theme_color("bg")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 60)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)
	margin.add_child(vbox)

	for ex in _examples():
		var engine := ExerciseEngine.new()
		vbox.add_child(engine)
		engine.build(ex)

func _examples() -> Array:
	return [
		{
			"type": "multiple_choice",
			"exercise_id": "preview_mc",
			"instruction": "Choose the correct answer.",
			"items": [{"question": "She ___ to school every day.", "options": ["go", "goes", "going"], "answer": 1}],
		},
		{
			"type": "fill_blank",
			"exercise_id": "preview_fb",
			"instruction": "Complete the sentence.",
			"items": [{"text": "I have two ___.", "answer": ["cats", "cat"]}],
		},
		{
			"type": "matching",
			"exercise_id": "preview_match",
			"instruction": "Match the word to its meaning.",
			"options": ["a cat", "a dog"],
			"items": [{"text": "gato", "answer": 0}],
		},
		{
			"type": "cloze",
			"exercise_id": "preview_cloze",
			"instruction": "Choose the best form.",
			"passage": "I (1) ______ to school and (2) ______ books.",
			"blanks": [
				{"options": ["go", "goes"], "answer": 0},
				{"options": ["read", "reads"], "answer": 0},
			],
		},
		{
			"type": "ordering",
			"exercise_id": "preview_order",
			"instruction": "Put the words in order.",
			"items": [{"text": "First"}, {"text": "Second"}, {"text": "Third"}],
			"answer_order": [0, 1, 2],
		},
		{
			"type": "word_bank",
			"exercise_id": "preview_wb",
			"instruction": "Choose a word.",
			"word_bank": ["apple", "book", "car"],
			"items": [{"text": "I read a ___.", "answer": 1}],
		},
		{
			"type": "text_highlight",
			"exercise_id": "preview_th",
			"instruction": "Tap the nouns.",
			"passage": "The cat sat on the mat",
			"answer_indices": [1, 4],
		},
	]