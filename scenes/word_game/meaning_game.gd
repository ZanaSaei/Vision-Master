extends "res://autoload/BackButtonHandler.gd"
# ============================================================
# بازی معنی — Meaning Game
# Placeholder scene; gameplay will be added later.
# ============================================================

const SCENE_WORD_GAME := "res://scenes/word_game/WordGame.tscn"

@onready var back_button: Button = $HeaderBar/HeaderContent/BackButton


func _ready() -> void:
	back_button.pressed.connect(_on_back_button_pressed)


func _on_back_button_pressed() -> void:
	TransitionManager.change_scene(SCENE_WORD_GAME)


func _on_android_back_pressed() -> void:
	_on_back_button_pressed()
