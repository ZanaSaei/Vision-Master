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


func _ready() -> void:
	var back_btn: Button = get_node_or_null("BackButton") as Button
	if back_btn != null:
		back_btn.pressed.connect(_go_back)

func _go_back() -> void:
	if game_content != null and game_content.has_method("close_panels") \
			and bool(game_content.call("close_panels")):
		return
	var return_target: String = DailyChallengeState.return_scene if DailyChallengeState.return_scene != "" else SCENE_WORD_GAME
	DailyChallengeState.return_scene = ""
	TransitionManager.change_scene(return_target)

func _on_android_back_pressed() -> void:
	_go_back()
