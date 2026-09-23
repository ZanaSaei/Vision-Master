extends "res://autoload/BackButtonHandler.gd"
# ============================================================
# کلمه روز — the daily Wordle puzzle.
#
# This scene is the host: it owns the header bar (title, back, help) and the
# navigation, while the puzzle itself lives in the instanced game content
# scene (wordle/WordleScreen.tscn). The «کلمه روز» button on the word-game
# hub opens this screen — there is no separate Wordle entry point.
# ============================================================

const SCENE_WORD_GAME := "res://scenes/word_game/WordGame.tscn"

@onready var back_button: Button = $HeaderBar/HeaderContent/BackButton
@onready var help_button: Button = $HeaderBar/HeaderContent/HelpButton
## The instanced game content. Typed as Node on purpose: its small public API
## (show_help / close_panels) is reached through call(), so this shell does
## not need to know the game's script class.
@onready var game_content: Node = $Game


func _ready() -> void:
	back_button.pressed.connect(_on_back_button_pressed)
	help_button.pressed.connect(_on_help_button_pressed)
	# The app-wide theme walk styles a scene when it is *entered*, not on a
	# live toggle; re-walking from here keeps the header and the page surface
	# in step when the theme is switched while the puzzle is open. (The game
	# content re-colours its own board, keyboard and cards.)
	Global.on_theme_changed(_on_theme_changed)


func _on_help_button_pressed() -> void:
	if game_content != null and game_content.has_method("show_help"):
		game_content.call("show_help")


func _on_theme_changed() -> void:
	Global.style_scene(self)


func _on_back_button_pressed() -> void:
	TransitionManager.change_scene(SCENE_WORD_GAME)


## Android back: an open card swallows the press first, so a player reading
## the word card is not thrown out of the puzzle. (The help card used to have
## no way out at all except leaving the screen.)
func _on_android_back_pressed() -> void:
	if game_content != null and game_content.has_method("close_panels") \
			and bool(game_content.call("close_panels")):
		return
	_on_back_button_pressed()
