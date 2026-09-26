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

var _pulse_tween: Tween = null


func _ready() -> void:
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
		MenuStyle.wire_microinteractions(btn)
	_play_entrance_animation()


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

	# Once the stagger finishes, start the idle pulse on the featured button.
	await get_tree().create_timer(0.08 * buttons.size() + 0.4).timeout
	if not is_inside_tree():
		return
	_start_ambient_pulse()


## Gentle looping "breathe" pulse on the کلمه روز button so it reads as the
## featured mode of the hub (mirrors the main menu's ambient title pulse).
## Paused while the pointer is over the button so it never fights the
## hover/press micro-interactions, which also tween `scale`.
func _start_ambient_pulse() -> void:
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(word_of_day_button, "scale", Vector2(1.015, 1.015), 1.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(word_of_day_button, "scale", Vector2.ONE, 1.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Hover/press squash the button — give them exclusive control of scale.
	word_of_day_button.mouse_entered.connect(_pause_ambient_pulse)
	word_of_day_button.mouse_exited.connect(_resume_ambient_pulse)


func _pause_ambient_pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.pause()


func _resume_ambient_pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		word_of_day_button.scale = Vector2.ONE
		_pulse_tween.play()


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

