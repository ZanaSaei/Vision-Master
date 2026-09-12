extends Control

# ============================================================
#  SAVED WORDS
#  If words exist → switches to VocabFlashcards in SAVED mode.
#  If empty → shows a friendly empty state with a back button.
# ============================================================

const SCENE_MAIN_MENU  := "res://scenes/main_menu/MainMenu.tscn"
const SCENE_FLASHCARDS := "res://scenes/vocabulary/VocabFlashcards.tscn"

@onready var empty_state: VBoxContainer = $EmptyState
@onready var back_button: Button        = $EmptyState/BackButton


func _ready() -> void:
	back_button.pressed.connect(_on_back_button_pressed)

	if Global.get_saved_words().is_empty():
		# Nothing saved yet — show the empty state in this scene
		empty_state.visible = true
	else:
		# Words exist — hand off to VocabFlashcards in SAVED mode
		AppRouter.set_args({"mode": "saved"})
		TransitionManager.change_scene(SCENE_FLASHCARDS)


func _on_back_button_pressed() -> void:
	TransitionManager.change_scene(SCENE_MAIN_MENU)

func _on_android_back_pressed() -> void:
	_on_back_button_pressed()
