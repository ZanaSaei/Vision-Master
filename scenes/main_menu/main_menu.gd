extends Control

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


func _ready() -> void:
	saved_words_button.pressed.connect(_on_saved_words_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	book1_button.pressed.connect(_on_book_pressed.bind(1))
	book2_button.pressed.connect(_on_book_pressed.bind(2))
	book3_button.pressed.connect(_on_book_pressed.bind(3))

	_setup_book_buttons()
	_setup_continue_button()


func _setup_book_buttons() -> void:

	book1_button.text = "📘  Vision 1 — دهم"
	book2_button.text = "📗  Vision 2 — یازدهم"
	book3_button.text = "📙  Vision 3 — دوازدهم"


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
#  NAVIGATION
# ----------------------------------------------------------------
func _on_saved_words_pressed() -> void:
	get_tree().change_scene_to_file(SCENE_SAVED_WORDS)


func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file(SCENE_SETTINGS)


func _on_continue_pressed() -> void:
	var last := Global.get_last_scene()
	if last != "":
		get_tree().change_scene_to_file(last)


func _on_book_pressed(book_number: int) -> void:
	# Store which book was chosen so BookMenu knows what to show,
	# then navigate to the Book/Lesson selection screen.
	Global.current_book = book_number
	get_tree().change_scene_to_file(SCENE_BOOK_MENU)
