extends "res://autoload/BackButtonHandler.gd"

# ============================================================
#  SAVED WORDS
#  If words exist → switches to VocabFlashcards in SAVED mode.
#  If empty → shows a friendly empty state; navigation remains available below.
# ============================================================

const SCENE_FLASHCARDS := "res://scenes/vocabulary/VocabFlashcards.tscn"

@onready var empty_state: VBoxContainer = $EmptyState


func _ready() -> void:
	wire_header_bar()

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


func _on_android_back_pressed() -> void:
	# Return to the screen that opened the saved-word flow (the flashcard hub),
	# falling back to the main menu when none was recorded.
	var back_route: String = str(AppRouter.get_arg("saved_back_route", "res://scenes/vocabulary/FlashcardHub.tscn"))
	TransitionManager.change_scene(back_route)
