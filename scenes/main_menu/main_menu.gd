extends "res://autoload/BackButtonHandler.gd"

# ============================================================
#  MAIN MENU
#  Buttons: Saved Words, Settings, Continue, Book 1/2/3
# ============================================================

# Scene paths — update these as you create each scene
const SCENE_BOOK_MENU    := "res://scenes/book_menu/BookMenu.tscn"
const SCENE_SAVED_WORDS  := "res://scenes/saved_words/SavedWords.tscn"
const SCENE_SETTINGS     := "res://scenes/settings/Settings.tscn"

# We store the last visited scene path in Global so Continue works
# across app sessions. Add this variable to Global.gd (see note below).

@onready var saved_words_button: Button = $MainLayout/InnerLayout/TopBar/SavedWordsButton
@onready var settings_button: Button    = $MainLayout/InnerLayout/TopBar/SettingsButton
@onready var continue_button: Button    = $MainLayout/InnerLayout/ContinueButton
@onready var book1_button: Button       = $MainLayout/InnerLayout/Book1Button
@onready var book2_button: Button       = $MainLayout/InnerLayout/Book2Button
@onready var book3_button: Button       = $MainLayout/InnerLayout/Book3Button
@onready var app_title: Label           = $MainLayout/InnerLayout/HeroSection/AppTitle
@onready var app_subtitle: Label        = $MainLayout/InnerLayout/HeroSection/AppSubtitle
@onready var choose_label: Label        = $MainLayout/InnerLayout/ChooseLabel

var _back_pressed_once := false

func _ready() -> void:
	saved_words_button.pressed.connect(_on_saved_words_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	book1_button.pressed.connect(_on_book_pressed.bind(1))
	book2_button.pressed.connect(_on_book_pressed.bind(2))
	book3_button.pressed.connect(_on_book_pressed.bind(3))

	app_title.pivot_offset = app_title.size / 2.0
	continue_button.pivot_offset = continue_button.size / 2.0
	settings_button.pivot_offset = settings_button.size / 2.0
	book1_button.pivot_offset = book1_button.size / 2.0
	book2_button.pivot_offset = book2_button.size / 2.0
	book3_button.pivot_offset = book3_button.size / 2.0
	saved_words_button.pivot_offset = saved_words_button.size / 2.0

	_setup_book_buttons()
	_setup_continue_button()
	_play_intro_animation()

func _setup_book_buttons() -> void:

	book1_button.text = "Vision 1 — دهم"
	book2_button.text = "Vision 2 — یازدهم"
	book3_button.text = "Vision 3 — دوازدهم"


func _setup_continue_button() -> void:
	# If the user has a saved last position, show it on the button.
	# Global.last_scene is a String path set whenever a lesson screen opens.
	if Global.has_last_scene():
		continue_button.text = "▶ از اینجا ادامه دهید"
		continue_button.visible = true
	else:
		# First launch — hide Continue until they've visited a lesson
		continue_button.visible = false

# ----------------------------------------------------------------
#  Intro
# ----------------------------------------------------------------

func _play_intro_animation() -> void:
	# Wait one frame so all Control nodes have their final size.
	await get_tree().process_frame

	# ---------- Initial state ----------
	app_title.pivot_offset = app_title.size / 2
	app_title.scale = Vector2(0.7, 0.7)
	app_title.modulate.a = 0.0

	app_subtitle.position.y += 30
	app_subtitle.modulate.a = 0.0

	var controls := [
		saved_words_button,
		settings_button,
		continue_button,
		book1_button,
		book2_button,
		book3_button,
		choose_label
	]

	for c in controls:
		c.modulate.a = 0.0

	# ---------- Animation ----------
	var tween := create_tween()

	# Title
	tween.parallel().tween_property(
		app_title,
		"scale",
		Vector2.ONE,
		2
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	tween.parallel().tween_property(
		app_title,
		"modulate:a",
		1.0,
		0.35
	)

	# Subtitle
	tween.parallel().tween_property(
		app_subtitle,
		"position:y",
		app_subtitle.position.y - 30,
		2
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	tween.parallel().tween_property(
		app_subtitle,
		"modulate:a",
		1.0,
		2
	)

	# Wait until title/subtitle finish
	tween.tween_interval(0.15)

	# Fade everything else
	for c in controls:
		tween.parallel().tween_property(
			c,
			"modulate:a",
			1.0,
			0.30
		)

# ----------------------------------------------------------------
#  NAVIGATION
# ----------------------------------------------------------------
func _on_saved_words_pressed() -> void:
	var tween = create_tween()
	tween.tween_property(saved_words_button, "scale", Vector2(0.96, 0.96), 0.08)
	Global.flashcard_mode = "saved"
	TransitionManager.change_scene(SCENE_SAVED_WORDS)


func _on_settings_pressed() -> void:
	var tween = create_tween()
	tween.tween_property(settings_button, "scale", Vector2(0.96, 0.96), 0.08)
	TransitionManager.change_scene(SCENE_SETTINGS)


func _on_continue_pressed() -> void:
	var last := Global.get_last_scene()
	if last != "":
		TransitionManager.change_scene(last)
	var tween = create_tween()
	tween.tween_property(continue_button, "scale", Vector2(0.96, 0.96), 0.08)


func _on_book_pressed(book_number: int) -> void:
	Global.current_book = book_number
	TransitionManager.change_scene(SCENE_BOOK_MENU)
	var tween = create_tween()
	if book_number == 1:
		tween.tween_property(book1_button, "scale", Vector2(0.96, 0.96), 0.08)
	elif book_number == 2:
		tween.tween_property(book2_button, "scale", Vector2(0.96, 0.96), 0.08)
	elif book_number == 3:
		tween.tween_property(book3_button, "scale", Vector2(0.96, 0.96), 0.08)

func _on_android_back_pressed() -> void:
	var current_time = Time.get_unix_time_from_system()
	
	if back_pressed_time > 0 and current_time - back_pressed_time < double_back_timeout:
		# Second back press within timeout - close app
		get_tree().quit()
	else:
		# First back press - show message
		back_pressed_time = current_time
		_show_back_message()


func _show_back_message() -> void:
	# Show a toast-like message (using a Label that appears and fades)
	var message := Label.new()
	message.text = "Press back again to exit"
	message.add_theme_font_size_override("font_size", 40)
	message.add_theme_color_override("font_color", Color.WHITE)
	message.add_theme_color_override("font_outline_color", Color.BLACK)
	message.outline_size = 2
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.anchor_left = 0.0
	message.anchor_top = 0.0
	message.anchor_right = 1.0
	message.anchor_bottom = 1.0
	add_child(message)
	
	# Create a background for the message
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.anchor_left = 0.0
	bg.anchor_top = 0.0
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)
	move_child(bg, 0)
	
	# Fade out after 1.5 seconds
	await get_tree().create_timer(1.5).timeout
	
	var tween := create_tween()
	tween.parallel().tween_property(bg, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(message, "modulate:a", 0.0, 0.3)
	await tween.finished
	
	bg.queue_free()
	message.queue_free()
