class_name FlashcardHub
extends "res://autoload/BackButtonHandler.gd"
# ============================================================
# FLASHCARD HUB — فلش کارت و لایتنر
# Entry hub reached from the bottom navigation bar's "فلش کارت"
# item. Provides two modes:
#   - فلش کارت  -> VocabFlashcards in saved_word mode
#   - لایتنر    -> WordReview (spaced-repetition review)
# ============================================================

const SCENE_FLASHCARDS: String = "res://scenes/vocabulary/VocabFlashcards.tscn"
const SCENE_SAVED_WORDS: String = "res://scenes/saved_words/SavedWords.tscn"
const SCENE_REVIEW: String = "res://scenes/review/WordReview.tscn"
const SCENE_SELF: String = "res://scenes/vocabulary/FlashcardHub.tscn"

@onready var flashcard_button: Button = $Content/FlashcardButton
@onready var leitner_button: Button = $Content/LeitnerButton
@onready var flashcard_label: Label = $Content/FlashcardButton/Margin/Row/Title
@onready var leitner_label: Label = $Content/LeitnerButton/Margin/Row/Title

var _navigating: bool = false


func _ready() -> void:
	for label: Label in [flashcard_label, leitner_label]:
		label.self_modulate = Color.WHITE
		label.modulate = Color.WHITE
	flashcard_button.pressed.connect(_on_flashcard_pressed)
	leitner_button.pressed.connect(_on_leitner_pressed)
	_wire_button_animations()


############################################################
# BUTTON ANIMATIONS
############################################################
func _wire_button_animations() -> void:
	for btn: Button in [flashcard_button, leitner_button]:
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
	if btn.has_meta("flashcard_hub_scale_tween"):
		var old_tween: Tween = btn.get_meta("flashcard_hub_scale_tween") as Tween
		if old_tween != null and old_tween.is_valid():
			old_tween.kill()
	var tween: Tween = btn.create_tween()
	btn.set_meta("flashcard_hub_scale_tween", tween)
	tween.tween_property(btn, "scale", target_scale, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _play_entrance_animation() -> void:
	var buttons: Array[Button] = [flashcard_button, leitner_button]
	for btn: Button in buttons:
		btn.modulate.a = 0.0
		btn.position.y += 40.0

	await get_tree().process_frame
	if not is_inside_tree():
		return

	for i: int in buttons.size():
		var btn: Button = buttons[i]
		var tw: Tween = create_tween()
		tw.tween_interval(0.08 * i)
		tw.tween_property(btn, "modulate:a", 1.0, 0.32) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(btn, "position:y", btn.position.y - 40.0, 0.32) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


############################################################
# NAVIGATION
############################################################
func _on_android_back_pressed() -> void:
	TransitionManager.change_scene("res://scenes/main_menu/MainMenu.tscn")


func _on_flashcard_pressed() -> void:
	if _navigating:
		return
	_navigating = true
	Sfx.click()
	AppRouter.set_args({
		"mode": "saved",
		"return_route": SCENE_FLASHCARDS,
		"saved_back_route": SCENE_SELF,
	})
	if Global.get_saved_words().is_empty():
		TransitionManager.change_scene(SCENE_SAVED_WORDS)
	else:
		TransitionManager.change_scene(SCENE_FLASHCARDS)


func _on_leitner_pressed() -> void:
	if _navigating:
		return
	_navigating = true
	Sfx.click()
	AppRouter.set_args({"return_route": SCENE_SELF})
	TransitionManager.change_scene(SCENE_REVIEW)
