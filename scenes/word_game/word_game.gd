extends "res://autoload/BackButtonHandler.gd"
# ============================================================
# WORD GAME HUB — بازی با کلمات
# Entry hub for the three word-based game modes:
#   کلمه روز / بازی معنی / بازی املا
# ============================================================

const SCENE_MAIN_MENU := "res://scenes/main_menu/MainMenu.tscn"
const SCENE_WORD_OF_DAY := "res://scenes/word_game/WordOfDay.tscn"
const SCENE_MEANING := "res://scenes/word_game/MeaningQuiz.tscn"
const SCENE_SPELLING := "res://scenes/word_game/SpellingGame.tscn"
@onready var back_button: Button = $HeaderBar/HeaderContent/BackButton
@onready var word_of_day_button: Button = $Content/WordOfDayButton
@onready var meaning_button: Button = $Content/MeaningButton
@onready var spelling_button: Button = $Content/SpellingButton
@onready var word_of_day_label: Label = $Content/WordOfDayButton/Margin/Row/Title
@onready var meaning_label: Label = $Content/MeaningButton/Margin/Row/Title
@onready var spelling_label: Label = $Content/SpellingButton/Margin/Row/Title

func _ready() -> void:
	for label: Label in [word_of_day_label, meaning_label, spelling_label]:
		label.self_modulate = Color.WHITE
		label.modulate = Color.WHITE
	back_button.pressed.connect(_on_back_button_pressed)
	word_of_day_button.pressed.connect(_on_word_of_day_pressed)
	meaning_button.pressed.connect(_on_meaning_pressed)
	spelling_button.pressed.connect(_on_spelling_pressed)
	_wire_button_animations()


############################################################
# BUTTON ANIMATIONS
############################################################
## Hover-lift / press-squash micro-interactions (same design language as
## the main-menu cards) on every game-mode button.
func _wire_button_animations() -> void:
	for btn: Button in [word_of_day_button, meaning_button, spelling_button]:
		btn.pivot_offset = btn.size / 2.0
		btn.resized.connect(_update_mode_button_pivot.bind(btn))
		btn.mouse_entered.connect(_on_mode_button_hovered.bind(btn))
		btn.mouse_exited.connect(_on_mode_button_exited.bind(btn))
		btn.button_down.connect(_animate_mode_button.bind(btn, Vector2(0.97, 0.97)))
		btn.button_up.connect(_on_mode_button_up.bind(btn))
	_play_entrance_animation()


func _update_mode_button_pivot(btn: Button) -> void:
	btn.pivot_offset = btn.size / 2.0


func _on_mode_button_hovered(btn: Button) -> void:
	if not btn.button_pressed:
		_animate_mode_button(btn, Vector2(1.03, 1.03))


func _on_mode_button_exited(btn: Button) -> void:
	if not btn.button_pressed:
		_animate_mode_button(btn, Vector2.ONE)


func _on_mode_button_up(btn: Button) -> void:
	var target_scale: Vector2 = Vector2(1.03, 1.03) if btn.is_hovered() else Vector2.ONE
	_animate_mode_button(btn, target_scale)


func _animate_mode_button(btn: Button, target_scale: Vector2) -> void:
	if btn.has_meta("word_game_scale_tween"):
		var old_tween: Tween = btn.get_meta("word_game_scale_tween") as Tween
		if old_tween != null and old_tween.is_valid():
			old_tween.kill()
	var tween: Tween = btn.create_tween()
	btn.set_meta("word_game_scale_tween", tween)
	tween.tween_property(btn, "scale", target_scale, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Staggered entrance: each button fades in and rises from slightly below,
## then pops (TRANS_BACK) — mirrors the main menu's intro feel.
func _play_entrance_animation() -> void:
	var buttons: Array[Button] = [word_of_day_button, meaning_button, spelling_button]
	for btn in buttons:
		btn.modulate.a = 0.0
		btn.position.y += 40.0

	await get_tree().process_frame
	if not is_inside_tree():
		return

	for i in buttons.size():
		var btn: Button = buttons[i]
		var tw := create_tween()
		tw.tween_interval(0.08 * i)
		tw.tween_property(btn, "modulate:a", 1.0, 0.32) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(btn, "position:y", btn.position.y - 40.0, 0.32) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Idle scale pulse intentionally disabled; entrance and hover/press
	# micro-interactions remain active.


func _on_back_button_pressed() -> void:
	TransitionManager.change_scene(SCENE_MAIN_MENU)


func _on_android_back_pressed() -> void:
	_on_back_button_pressed()


func _on_word_of_day_pressed() -> void:
	TransitionManager.change_scene(SCENE_WORD_OF_DAY)


func _on_meaning_pressed() -> void:
	TransitionManager.change_scene(SCENE_MEANING)


func _on_spelling_pressed() -> void:
	TransitionManager.change_scene(SCENE_SPELLING)

