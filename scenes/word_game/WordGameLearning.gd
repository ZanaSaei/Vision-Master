extends "res://autoload/BackButtonHandler.gd"
class_name WordGameLearning

const MEANING_SCENE: String = "res://scenes/word_game/MeaningQuiz.tscn"
const SCRAMBLED_SCENE: String = "res://scenes/word_game/scrambled/ScrambledWords.tscn"
const HUB_SCENE: String = "res://scenes/word_game/WordGameHub.tscn"

@onready var _background: ColorRect = $Background
@onready var _back_button: Button = $MainMargin/MainColumn/BackButton
@onready var _wordef_button: Button = $MainMargin/MainColumn/WordefButton
@onready var _unscramble_button: Button = $MainMargin/MainColumn/UnscrambleButton

func _ready() -> void:
	_background.color = MenuStyle.c("bg")
	MenuStyle.style_button(_wordef_button, "primary")
	MenuStyle.style_button(_unscramble_button, "secondary")
	_back_button.pressed.connect(_on_back_pressed)
	_wordef_button.pressed.connect(_on_wordef_pressed)
	_unscramble_button.pressed.connect(_on_unscramble_pressed)

func _on_back_pressed() -> void:
	TransitionManager.change_scene(HUB_SCENE)

func _on_wordef_pressed() -> void:
	TransitionManager.change_scene(MEANING_SCENE)

func _on_unscramble_pressed() -> void:
	TransitionManager.change_scene(SCRAMBLED_SCENE)

func _on_android_back_pressed() -> void:
	TransitionManager.change_scene(HUB_SCENE)
