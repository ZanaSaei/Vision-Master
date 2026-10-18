extends "res://autoload/BackButtonHandler.gd"
# ============================================================
# کلمه روز — the daily Wordle puzzle.
#
# This scene hosts the puzzle content in wordle/WordleScreen.tscn. Header
# controls are omitted so the daily puzzle can use the full screen; Android
# back remains supported by BackButtonHandler.
# ============================================================

const SCENE_WORD_GAME := "res://scenes/word_game/WordGameHub.tscn"

## The instanced puzzle content provides the panel-close API used by Android
## back, without this scene needing to know its concrete game type.
@onready var game_content: Node = $Game


func _on_android_back_pressed() -> void:
	if game_content != null and game_content.has_method("close_panels") \
			and bool(game_content.call("close_panels")):
		return
	TransitionManager.change_scene(SCENE_WORD_GAME)
