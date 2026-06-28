extends Control

# ============================================================
#  VOCAB FLASHCARDS — handles both LESSON and SAVED modes.
#
#  LESSON mode (Global.flashcard_mode == "lesson"):
#    - Loads words from the current lesson's JSON
#    - Header: back arrow + audio button
#    - Bottom nav: 📖 home | ☰ lesson list | ⚙ settings
#    - Heart: toggles save / unsave
#
#  SAVED mode (Global.flashcard_mode == "saved"):
#    - Loads all words from Global.get_saved_words()
#    - Header: back arrow + audio button (dynamically loads lesson audio)
#    - Bottom nav: 📖 home | 🗑 Remove Word | 📝 Quiz
#    - Heart: static filled indicator (word is saved)
# ============================================================

enum Mode { LESSON, SAVED }

var word_list: Array     = []
var current_index: int   = 0
var current_book: int    = 0
var current_lesson: int  = 0
var vocab_audio_filename := ""
var mode: Mode           = Mode.LESSON
var is_flipped: bool     = false
var is_animating: bool   = false

# ---------- Drag, Slide & Rotation state ----------
var is_sliding: bool       = false
var is_dragging: bool      = false
var initial_card_x: float  = 0.0
var total_drag_dist: float = 0.0
const DRAG_THRESHOLD       := 80.0  # How far to drag before it counts as a word change
const DRAG_FLIP_TOLERANCE  := 10.0  # If dragged less than this, treat as a tap (flip)
const DRAG_ROTATION_FACTOR := 0.02  # How much the card tilts while dragging
const SLIDE_DURATION       := 0.2
const SNAP_DURATION        := 0.15

# ---------- Dot constants ----------
const DOT_ACTIVE_W    := 24
const DOT_INACTIVE_W  := 14
const DOT_HEIGHT      := 6
const DOT_RADIUS      := 3
const DOT_ACTIVE_COLOR    := Color("#2563EB")
const DOT_INACTIVE_COLOR  := Color("#CBD5E1")

# ---------- Scene paths ----------
const SCENE_MAIN_MENU      := "res://scenes/main_menu/MainMenu.tscn"
const SCENE_LESSON_MENU    := "res://scenes/lesson_menu/LessonMenu.tscn"
const SCENE_SETTINGS       := "res://scenes/settings/Settings.tscn"
const SCENE_QUIZ           := "res://scenes/quiz/Quiz.tscn"
const SCENE_NO_SAVED_WORDS := "res://scenes/saved_words/SavedWords.tscn"

# ---------- Node references ----------
@onready var lesson_title: Label               = $HeaderBar/HeaderContent/HeaderSpacer/LessonTitle

@onready var progress_dots: HBoxContainer      = $MarginContainer/MainLayout/ProgressBackground/ProgressDotsContainer
@onready var card_panel: PanelContainer        = $MarginContainer/MainLayout/CardScrollContainer/CardMargin/CardPanel

@onready var front_face: CenterContainer       = $MarginContainer/MainLayout/CardScrollContainer/CardMargin/CardPanel/CardContent/FrontFace
@onready var front_word_label: Label           = $MarginContainer/MainLayout/CardScrollContainer/CardMargin/CardPanel/CardContent/FrontFace/WordLabel

@onready var back_face: VBoxContainer          = $MarginContainer/MainLayout/CardScrollContainer/CardMargin/CardPanel/CardContent/BackFace
@onready var back_word_label: Label            = $MarginContainer/MainLayout/CardScrollContainer/CardMargin/CardPanel/CardContent/BackFace/WordRow/WordRowContent/BackWordLabel
@onready var meaning_en_label: Label           = $MarginContainer/MainLayout/CardScrollContainer/CardMargin/CardPanel/CardContent/BackFace/MeaningEnRow/MeaningEnRowContent/MeaningEnLabel
@onready var meaning_fa_label: Label           = $MarginContainer/MainLayout/CardScrollContainer/CardMargin/CardPanel/CardContent/BackFace/MeaningFaRow/MeaningFaRowContent/MeaningFaLabel
@onready var example_label: Label              = $MarginContainer/MainLayout/CardScrollContainer/CardMargin/CardPanel/CardContent/BackFace/ExampleRow/ExampleRowContent/ExampleLabel

@onready var prev_button: Button               = $MarginContainer/MainLayout/PanelContainer/BottomControls/PrevButton
@onready var save_button: Button               = $MarginContainer/MainLayout/PanelContainer/BottomControls/SaveButton
@onready var next_button: Button               = $MarginContainer/MainLayout/PanelContainer/BottomControls/NextButton

@onready var audio_button: Button              = $HeaderBar/HeaderContent/AudioButton
@onready var back_nav_button: Button           = $HeaderBar/HeaderContent/BackButton

@onready var nav_book: TextureButton           = $MarginContainer/MainLayout/BottomMargin/BottomNav/IconsMargin/NavContent/NavBook
@onready var nav_list: TextureButton           = $MarginContainer/MainLayout/BottomMargin/BottomNav/IconsMargin/NavContent/NavList
@onready var nav_settings: TextureButton       = $MarginContainer/MainLayout/BottomMargin/BottomNav/IconsMargin/NavContent/NavSettings

@onready var save_inactive = preload("res://images/save_button.png")
@onready var save_active = preload("res://images/saved_button.png")

@onready var audio_player: AudioStreamPlayer   = $AudioPlayer

const FLIP_DURATION := 0.18


func _ready() -> void:
	# Wire static buttons
	prev_button.pressed.connect(_on_prev_pressed)
	next_button.pressed.connect(_on_next_pressed)
	save_button.pressed.connect(_on_save_pressed)
	audio_button.pressed.connect(_on_audio_pressed)
	back_nav_button.pressed.connect(_on_back_pressed)
	nav_book.pressed.connect(_on_nav_book_pressed)
	card_panel.gui_input.connect(_on_card_input)

	audio_button.pivot_offset = audio_button.size / 2.0
	back_nav_button.pivot_offset = back_nav_button.size / 2.0
	next_button.pivot_offset = next_button.size / 2.0
	prev_button.pivot_offset = prev_button.size / 2.0
	nav_book.pivot_offset = nav_book.size / 2.0
	nav_list.pivot_offset = nav_list.size / 2.0
	nav_settings.pivot_offset = nav_settings.size / 2.0

	if Global.flashcard_mode == "saved":
		_enter_saved_mode()
	else:
		_enter_lesson_mode()


# ----------------------------------------------------------------
#  MODE ENTRY POINTS
# ----------------------------------------------------------------
func _enter_lesson_mode() -> void:
	mode = Mode.LESSON
	audio_button.visible = true

	if nav_list.pressed.is_connected(_on_remove_word_pressed):
		nav_list.pressed.disconnect(_on_remove_word_pressed)
	if nav_settings.pressed.is_connected(_on_quiz_pressed):
		nav_settings.pressed.disconnect(_on_quiz_pressed)

	nav_list.pressed.connect(_on_nav_list_lesson_pressed)
	nav_settings.pressed.connect(_on_nav_settings_lesson_pressed)

	nav_list.texture_normal = load("res://images/menu.png")
	nav_list.texture_pressed = load("res://images/menu.png")
	nav_list.tooltip_text = "Lesson List"
	
	nav_settings.texture_normal = load("res://images/setting.png")
	nav_settings.texture_pressed = load("res://images/setting.png")
	nav_settings.tooltip_text = "Settings"

	var book: int   = Global.current_book
	var lesson: int = Global.current_lesson
	var lesson_data := Global.load_vocabulary(book, lesson)
	
	lesson_title.text = "Vision %d\nLesson %s" % [book, lesson]
	
	if lesson_data.is_empty():
		push_error("Failed to load lesson %d from book %d" % [lesson, book])
		get_tree().change_scene_to_file(SCENE_LESSON_MENU)
		return
	
	var vocab_section: Dictionary = lesson_data.get("vocabulary", {})
	setup(
		vocab_section.get("words", []),
		book, lesson,
		vocab_section.get("audio", ""),
		Mode.LESSON
	)


func _enter_saved_mode() -> void:
	mode = Mode.SAVED
	audio_button.visible = true # Brought this back for saved mode

	lesson_title.text = "کلمات ذخیره شده"

	nav_list.texture_normal = load("res://images/delete.png")
	nav_list.texture_pressed = load("res://images/delete.png")
	nav_list.tooltip_text = "Remove current word"
	
	nav_settings.texture_normal = load("res://images/quiz.png")
	nav_settings.texture_pressed = load("res://images/quiz.png")
	nav_settings.tooltip_text = "Start Quiz"

	if nav_list.pressed.is_connected(_on_nav_list_lesson_pressed):
		nav_list.pressed.disconnect(_on_nav_list_lesson_pressed)
	if nav_settings.pressed.is_connected(_on_nav_settings_lesson_pressed):
		nav_settings.pressed.disconnect(_on_nav_settings_lesson_pressed)

	nav_list.pressed.connect(_on_remove_word_pressed)
	nav_settings.pressed.connect(_on_quiz_pressed)

	save_button.icon = save_active
	save_button.modulate = Color("#EF4444")
	save_button.disabled = true

	var saved_copy = Global.get_saved_words().duplicate()
	setup(saved_copy, 0, 0, "", Mode.SAVED)


# ----------------------------------------------------------------
#  PUBLIC SETUP
# ----------------------------------------------------------------
func setup(words: Array, book: int, lesson: int, audio_filename: String, screen_mode: Mode = Mode.LESSON) -> void:
	word_list            = words
	current_book         = book
	current_lesson       = lesson
	vocab_audio_filename = audio_filename
	mode                 = screen_mode
	current_index        = 0
	is_flipped           = false

	_build_progress_dots()
	_update_card(false)


# ----------------------------------------------------------------
#  PROGRESS DOTS
# ----------------------------------------------------------------
func _build_progress_dots() -> void:
	for child in progress_dots.get_children():
		child.queue_free()

	var total: int = word_list.size()
	var num_dots: int = min(total, 50)

	for i in num_dots:
		var dot := Panel.new()
		var style := StyleBoxFlat.new()
		style.corner_radius_top_left     = DOT_RADIUS
		style.corner_radius_top_right    = DOT_RADIUS
		style.corner_radius_bottom_left  = DOT_RADIUS
		style.corner_radius_bottom_right = DOT_RADIUS
		style.bg_color = DOT_ACTIVE_COLOR if i == current_index else DOT_INACTIVE_COLOR
		dot.add_theme_stylebox_override("panel", style)
		dot.custom_minimum_size = Vector2(
			DOT_ACTIVE_W if i == current_index else DOT_INACTIVE_W,
			DOT_HEIGHT
		)
		progress_dots.add_child(dot)


func _update_progress_dots() -> void:
	var dots := progress_dots.get_children()
	for i in dots.size():
		var dot: Panel = dots[i]
		var style := StyleBoxFlat.new()
		style.corner_radius_top_left     = DOT_RADIUS
		style.corner_radius_top_right    = DOT_RADIUS
		style.corner_radius_bottom_left  = DOT_RADIUS
		style.corner_radius_bottom_right = DOT_RADIUS
		style.bg_color = DOT_ACTIVE_COLOR if i == current_index else DOT_INACTIVE_COLOR
		dot.add_theme_stylebox_override("panel", style)
		dot.custom_minimum_size = Vector2(
			DOT_ACTIVE_W if i == current_index else DOT_INACTIVE_W,
			DOT_HEIGHT
		)


# ----------------------------------------------------------------
#  CARD DISPLAY
# ----------------------------------------------------------------
func _update_card(animate: bool = false) -> void:
	if word_list.is_empty():
		_handle_empty_list()
		return

	var entry: Dictionary = word_list[current_index]

	# Dynamically update audio details in Saved Mode
	if mode == Mode.SAVED:
		current_book = entry.get("book", 0)
		current_lesson = entry.get("lesson", 0)
		var lesson_data := Global.load_vocabulary(current_book, current_lesson)
		if not lesson_data.is_empty():
			vocab_audio_filename = lesson_data.get("vocabulary", {}).get("audio", "")

	front_word_label.text = entry.get("word", "")
	back_word_label.text  = entry.get("word", "")
	meaning_en_label.text = entry.get("meaning_en", "")
	meaning_fa_label.text = entry.get("meaning_fa", "")
	example_label.text    = entry.get("example", "")

	is_flipped = false

	if animate:
		_play_flip(false)
	else:
		_show_face(false)

	_update_progress_dots()

	if mode == Mode.LESSON:
		_refresh_save_button(entry)


func _handle_empty_list() -> void:
	if mode == Mode.SAVED:
		get_tree().change_scene_to_file(SCENE_NO_SAVED_WORDS)
	else:
		get_tree().change_scene_to_file(SCENE_MAIN_MENU)


func _refresh_save_button(entry: Dictionary) -> void:
	if mode != Mode.LESSON:
		return
	var saved := Global.is_word_saved(entry.get("word", ""), current_book, current_lesson)
	save_button.icon     = save_active if saved else save_inactive
	save_button.disabled = false


func _show_face(show_back: bool) -> void:
	front_face.visible = not show_back
	back_face.visible  = show_back


# ----------------------------------------------------------------
#  FLIP ANIMATION
# ----------------------------------------------------------------
func _play_flip(landing_on_back: bool) -> void:
	if is_animating or is_sliding:
		return
	is_animating = true
	card_panel.pivot_offset = Vector2(card_panel.size.x / 2.0, card_panel.size.y / 2.0)

	var tween := create_tween()
	tween.tween_property(card_panel, "scale:x", 0.0, FLIP_DURATION).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(func(): _show_face(landing_on_back))
	tween.tween_property(card_panel, "scale:x", 1.0, FLIP_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(func(): is_animating = false)


# ----------------------------------------------------------------
#  DRAG, SLIDE & ROTATE LOGIC
# ----------------------------------------------------------------
func _on_card_input(event: InputEvent) -> void:
	# 1. Handle Dragging (Mouse move or Touch drag)
	if event is InputEventMouseMotion or event is InputEventScreenDrag:
		if is_dragging:
			total_drag_dist += event.relative.x
			
			# Move and Rotate
			card_panel.position.x = initial_card_x + total_drag_dist
			card_panel.rotation_degrees = total_drag_dist * DRAG_ROTATION_FACTOR
			
	# 2. Handle Press and Release
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT or event is InputEventScreenTouch:
		if event.pressed:
			if is_animating or is_sliding or word_list.is_empty():
				return
			# Start drag - Set pivot so it rotates from the center
			card_panel.pivot_offset = Vector2(card_panel.size.x / 2.0, card_panel.size.y / 2.0)
			is_dragging = true
			initial_card_x = card_panel.position.x
			total_drag_dist = 0.0
		else:
			# End drag
			if is_dragging:
				is_dragging = false
				
				# Evaluate the drag distance
				if abs(total_drag_dist) > DRAG_THRESHOLD:
					var direction = 1 if total_drag_dist < 0 else -1
					_finish_slide_animation(direction, initial_card_x)
				elif abs(total_drag_dist) > DRAG_FLIP_TOLERANCE:
					# Didn't drag far enough to change word, snap back
					_snap_back_animation(initial_card_x)
				else:
					# Barely moved at all, treat as a tap/flip
					card_panel.position.x = initial_card_x
					card_panel.rotation_degrees = 0.0
					_flip()


func _finish_slide_animation(direction: int, start_x: float) -> void:
	# direction: 1 (sliding left to next), -1 (sliding right to prev)
	is_sliding = true
	var slide_distance = get_viewport_rect().size.x
	var target_x = start_x - (direction * slide_distance)
	
	# Calculate how much it should be rotated when it reaches the edge
	var target_rotation = (-direction * slide_distance) * DRAG_ROTATION_FACTOR 

	var tween = create_tween()
	
	# Finish sliding out (Position AND Rotation at the same time using parallel)
	tween.tween_property(card_panel, "position:x", target_x, SNAP_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(card_panel, "rotation_degrees", target_rotation, SNAP_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

	tween.tween_callback(func():
		if direction == 1:
			current_index = (current_index + 1) % word_list.size()
		else:
			current_index = (current_index - 1 + word_list.size()) % word_list.size()
			
		_update_card(false)
		
		# Move to opposite side off-screen instantly, and reset rotation to 0
		card_panel.position.x = start_x + (direction * slide_distance)
		card_panel.rotation_degrees = 0.0
	)

	# Slide back in
	tween.tween_property(card_panel, "position:x", start_x, SLIDE_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(func(): is_sliding = false)


func _snap_back_animation(target_x: float) -> void:
	is_sliding = true
	var tween = create_tween()
	
	# Snap back position and rotate back to 0 at the same time
	tween.tween_property(card_panel, "position:x", target_x, SNAP_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(card_panel, "rotation_degrees", 0.0, SNAP_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	
	tween.tween_callback(func(): is_sliding = false)


# Re-use the slide logic for the UI buttons
func _button_slide(direction: int) -> void:
	if is_sliding or is_animating or is_dragging or word_list.is_empty():
		return
		
	# Ensure pivot is centered for rotation
	card_panel.pivot_offset = Vector2(card_panel.size.x / 2.0, card_panel.size.y / 2.0)
	
	# Start a slide from the center
	_finish_slide_animation(direction, card_panel.position.x)


func _flip() -> void:
	if is_animating or is_sliding or word_list.is_empty():
		return
	is_flipped = not is_flipped
	_play_flip(is_flipped)


func _on_prev_pressed() -> void:
	_button_slide(-1)


func _on_next_pressed() -> void:
	_button_slide(1)


# ----------------------------------------------------------------
#  SAVE / REMOVE (heart button)
# ----------------------------------------------------------------
func _on_save_pressed() -> void:
	if mode != Mode.LESSON or word_list.is_empty():
		return
	var entry: Dictionary = word_list[current_index]
	if Global.is_word_saved(entry.get("word", ""), current_book, current_lesson):
		Global.remove_word(entry.get("word", ""), current_book, current_lesson)
	else:
		var data := entry.duplicate()
		data["book"]   = current_book
		data["lesson"] = current_lesson
		Global.save_word(data)
	_refresh_save_button(entry)


# ----------------------------------------------------------------
#  DEDICATED REMOVE (SAVED mode — 🗑 nav button)
# ----------------------------------------------------------------
func _on_remove_word_pressed() -> void:
	if word_list.is_empty():
		return
	var entry : Dictionary = word_list[current_index]
	Global.remove_word(
		entry.get("word", ""),
		entry.get("book", 0),
		entry.get("lesson", 0)
	)
	word_list.remove_at(current_index)
	if current_index >= word_list.size():
		current_index = max(0, word_list.size() - 1)
	var tween := create_tween()
	tween.tween_property(save_button, "scale", Vector2(0.93, 0.93), 0.08) \
	.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(audio_button, "scale", Vector2.ONE, 0.12) \
	.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_build_progress_dots()
	_update_card(false)


# ----------------------------------------------------------------
#  AUDIO
# ----------------------------------------------------------------
func _on_audio_pressed() -> void:
	if vocab_audio_filename == "":
		return
	var path := Global.get_audio_path(current_book, current_lesson, vocab_audio_filename)
	var tween := create_tween()
	tween.tween_property(audio_button, "scale", Vector2(0.93, 0.93), 0.08) \
	.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(audio_button, "scale", Vector2.ONE, 0.12) \
	.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if ResourceLoader.exists(path):
		audio_player.stream = load(path)
		audio_player.play()
	else:
		push_warning("Audio not found: " + path)


# ----------------------------------------------------------------
#  NAVIGATION
# ----------------------------------------------------------------
func _on_back_pressed() -> void:
	Global.flashcard_mode = "lesson"
	if mode == Mode.SAVED:
		TransitionManager.change_scene(SCENE_MAIN_MENU)
	else:
		TransitionManager.change_scene(SCENE_LESSON_MENU)
	var tween = create_tween()
	tween.tween_property(back_nav_button, "scale", Vector2(0.96, 0.96), 0.08)


func _on_nav_book_pressed() -> void:
	Global.flashcard_mode = "lesson"
	TransitionManager.change_scene(SCENE_MAIN_MENU)


func _on_nav_list_lesson_pressed() -> void:
	TransitionManager.change_scene(SCENE_LESSON_MENU)


func _on_nav_settings_lesson_pressed() -> void:
	TransitionManager.change_scene(SCENE_SETTINGS)


func _on_quiz_pressed() -> void:
	TransitionManager.change_scene(SCENE_QUIZ)
