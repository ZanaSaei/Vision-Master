extends Control

# ============================================================
#  WORD DEFINITION POPUP
#  Shows when user taps a word in conversation/reading
#  Slides in from top
# ============================================================

signal word_saved(word_data: Dictionary)

var word_data: Dictionary = {}
var is_animating: bool = false
var is_closing: bool = false


func setup(word: String, definition: Dictionary) -> void:
	word_data = definition
	word_data["word"] = word
	
	# Setup UI
	$Panel/MarginContainer/VBoxContainer/WordLabel.text = word
	
	# Meaning English
	var meaning_en = definition.get("meaning_en", "Meaning not available")
	$Panel/MarginContainer/VBoxContainer/MeaningEnLabel.text = meaning_en
	
	# Meaning Farsi
	var meaning_fa = definition.get("meaning_fa", "")
	if meaning_fa != "":
		$Panel/MarginContainer/VBoxContainer/MeaningFaLable.text = meaning_fa
		$Panel/MarginContainer/VBoxContainer/MeaningFaLable.visible = true
	else:
		$Panel/MarginContainer/VBoxContainer/MeaningFaLable.visible = false
	
	# Word Type & Countable info
	var word_type = definition.get("word_type", "")
	var countable = definition.get("countable", null)
	
	var info_text := ""
	if word_type != "":
		info_text += word_type.capitalize()
		if word_type == "noun" and countable != null:
			info_text += " - " + ("Countable" if countable else "Uncountable")
	
	if info_text != "":
		$Panel/MarginContainer/VBoxContainer/InfoLabel.text = info_text
		$Panel/MarginContainer/VBoxContainer/InfoLabel.visible = true
	else:
		$Panel/MarginContainer/VBoxContainer/InfoLabel.visible = false
	
	# Verb forms
	var verb_forms = definition.get("verb_forms", {})
	if not verb_forms.is_empty():
		var forms_text := "Verb Forms:\n"
		forms_text += "  Base: " + word + "\n"
		if verb_forms.has("past"):
			forms_text += "  Past: " + verb_forms["past"] + "\n"
		if verb_forms.has("past_participle"):
			forms_text += "  Past Participle: " + verb_forms["past_participle"] + "\n"
		if verb_forms.has("present_participle"):
			forms_text += "  Present Participle: " + verb_forms["present_participle"] + "\n"
		if verb_forms.has("third_person"):
			forms_text += "  Third Person: " + verb_forms["third_person"]
		
		$Panel/MarginContainer/VBoxContainer/VerbFormsLabel.text = forms_text
		$Panel/MarginContainer/VBoxContainer/VerbFormsLabel.visible = true
	else:
		$Panel/MarginContainer/VBoxContainer/VerbFormsLabel.visible = false
	
	# Example
	var example = definition.get("example", "")
	if example != "":
		$Panel/MarginContainer/VBoxContainer/ExampleLabel.text = "Example: " + example
		$Panel/MarginContainer/VBoxContainer/ExampleLabel.visible = true
	else:
		$Panel/MarginContainer/VBoxContainer/ExampleLabel.visible = false
	
	# Source
	var source = definition.get("source", "")
	var book = definition.get("book", 0)
	var lesson = definition.get("lesson", 0)
	if source != "":
		$Panel/MarginContainer/VBoxContainer/SourceLabel.text = "From: " + source + " (Lesson " + str(lesson) + ")"
		$Panel/MarginContainer/VBoxContainer/SourceLabel.visible = true
	elif book > 0 and lesson > 0:
		$Panel/MarginContainer/VBoxContainer/SourceLabel.text = "From: Vision " + str(book) + ", Lesson " + str(lesson)
		$Panel/MarginContainer/VBoxContainer/SourceLabel.visible = true
	else:
		$Panel/MarginContainer/VBoxContainer/SourceLabel.visible = false
	
	# Check if already saved
	var word_text = word_data.get("word", "")
	var word_book = word_data.get("book", 0)
	var word_lesson = word_data.get("lesson", 0)
	if Global.is_word_saved(word_text, word_book, word_lesson):
		$Panel/MarginContainer/VBoxContainer/SaveButton.text = "✓ Saved"
		$Panel/MarginContainer/VBoxContainer/SaveButton.disabled = true
	
	# Connect button signals
	$Panel/MarginContainer/VBoxContainer/SaveButton.pressed.connect(_on_save_pressed)
	$Panel/MarginContainer/VBoxContainer/CloseButton.pressed.connect(_on_close_pressed)
	
	# Connect background click
	$Background.gui_input.connect(_on_background_gui_input)
	
	# Slide in from top
	_slide_in()


func _ready() -> void:
	# Start off-screen at top
	position.y = -size.y
	visible = false


func _slide_in() -> void:
	visible = true
	is_animating = true
	
	# Calculate target position (center of screen)
	var target_y: float = (get_viewport().size.y - size.y) / 2
	var start_y: float = -size.y
	
	# Start off-screen
	position.y = start_y
	
	var tween := create_tween()
	tween.tween_property(self, "position:y", target_y, 0.35) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	await tween.finished
	is_animating = false


func _slide_out() -> void:
	if is_animating or is_closing:
		return
	
	is_closing = true
	is_animating = true
	
	var target_y: float = -size.y
	
	var tween := create_tween()
	tween.tween_property(self, "position:y", target_y, 0.3) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	await tween.finished
	visible = false
	is_animating = false
	queue_free()


func _on_close_pressed() -> void:
	_slide_out()


func _on_background_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_slide_out()
	elif event is InputEventScreenTouch and event.pressed:
		_slide_out()


func _on_save_pressed() -> void:
	if word_data.has("word") and word_data.has("book") and word_data.has("lesson"):
		var save_data = {
			"word": word_data["word"],
			"meaning_en": word_data.get("meaning_en", ""),
			"meaning_fa": word_data.get("meaning_fa", ""),
			"example": word_data.get("example", ""),
			"book": word_data.get("book", 0),
			"lesson": word_data.get("lesson", 0),
			"word_type": word_data.get("word_type", "noun"),
			"countable": word_data.get("countable", null),
			"verb_forms": word_data.get("verb_forms", {})
		}
		
		# Check if already saved
		if Global.is_word_saved(save_data["word"], save_data["book"], save_data["lesson"]):
			$Panel/MarginContainer/VBoxContainer/SaveButton.text = "✓ Already Saved"
			$Panel/MarginContainer/VBoxContainer/SaveButton.disabled = true
			return
		
		Global.save_word(save_data)
		word_saved.emit(save_data)
		
		$Panel/MarginContainer/VBoxContainer/SaveButton.text = "✓ Saved!"
		$Panel/MarginContainer/VBoxContainer/SaveButton.disabled = true
		await get_tree().create_timer(1.0).timeout
		_slide_out()
