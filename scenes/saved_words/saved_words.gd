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

	# The empty state is only for the genuinely-empty case, so hide it up
	# front. This screen is a pass-through whenever words exist and must
	# never flash "Empty" while it is routing on to the flashcards.
	empty_state.visible = false

	# The same route is reached directly from the Main Menu drawer and from
	# older saved-word navigation. Check the current Global list at entry time.
	var saved_words: Array = Global.get_saved_words()
	if saved_words.is_empty():
		empty_state.visible = true
		return

	# Explicitly route into saved flashcards; do not depend on stale route args.
	AppRouter.set_args({"mode": "saved", "return_route": SCENE_FLASHCARDS})
	TransitionManager.change_scene(SCENE_FLASHCARDS)


func _on_back_button_pressed() -> void:
	TransitionManager.change_scene(SCENE_MAIN_MENU)

func _on_android_back_pressed() -> void:
	_on_back_button_pressed()
