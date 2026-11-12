class_name FlashcardHub
extends "res://autoload/BackButtonHandler.gd"
# ============================================================
# FLASHCARD HUB — فلش کارت و لایتنر
# Entry hub reached from the bottom navigation bar's "فلش کارت"
# item. Provides two modes + live vocabulary/SRS overview:
#   - فلش کارت  -> VocabFlashcards in saved_word mode (or SavedWords when empty)
#   - لایتنر    -> WordReview (spaced-repetition review)
# ============================================================

const SCENE_FLASHCARDS: String = "res://scenes/vocabulary/VocabFlashcards.tscn"
const SCENE_SAVED_WORDS: String = "res://scenes/saved_words/SavedWords.tscn"
const SCENE_REVIEW: String = "res://scenes/review/WordReview.tscn"
const SCENE_MAIN_MENU: String = "res://scenes/main_menu/MainMenu.tscn"
const SCENE_SELF: String = "res://scenes/vocabulary/FlashcardHub.tscn"

const GlossSheenScript := preload("res://ui/widgets/gloss_sheen.gd")

const COLOR_BLUE := Color("#2F6FD8")
const COLOR_GOLD := Color("#A87C24")
const MASTERED_INTERVAL_DAYS := 7.0

@onready var _content_col: VBoxContainer = $RootScroll/OuterMargin/Content
@onready var flashcard_button: Button = $RootScroll/OuterMargin/Content/FlashcardButton
@onready var leitner_button: Button = $RootScroll/OuterMargin/Content/LeitnerButton
@onready var flashcard_label: Label = $RootScroll/OuterMargin/Content/FlashcardButton/Margin/Row/TextColumn/Title
@onready var leitner_label: Label = $RootScroll/OuterMargin/Content/LeitnerButton/Margin/Row/TextColumn/Title

@onready var _flashcard_badge_label: Label = $RootScroll/OuterMargin/Content/FlashcardButton/Margin/Row/TextColumn/TopTagRow/ContextBadge/BadgeLabel
@onready var _flashcard_icon_chip: Control = $RootScroll/OuterMargin/Content/FlashcardButton/Margin/Row/IconChip
@onready var _leitner_badge_label: Label = $RootScroll/OuterMargin/Content/LeitnerButton/Margin/Row/TextColumn/TopTagRow/DueBadge/BadgeLabel

@onready var _mastery_percent_label: Label = $RootScroll/OuterMargin/Content/MasteryCard/Margin/VBox/HeaderRow/PercentPill/PercentLabel
@onready var _mastery_progress: ProgressBar = $RootScroll/OuterMargin/Content/MasteryCard/Margin/VBox/MasteryProgress
@onready var _new_pill_label: Label = $RootScroll/OuterMargin/Content/MasteryCard/Margin/VBox/BreakdownRow/NewPill/Label
@onready var _learning_pill_label: Label = $RootScroll/OuterMargin/Content/MasteryCard/Margin/VBox/BreakdownRow/LearningPill/Label
@onready var _mastered_pill_label: Label = $RootScroll/OuterMargin/Content/MasteryCard/Margin/VBox/BreakdownRow/MasteredPill/Label
@onready var _mastery_hint: Label = $RootScroll/OuterMargin/Content/MasteryCard/Margin/VBox/MasteryHint

var _navigating: bool = false
var _button_tweens: Dictionary = {}
var _ambient_tween: Tween = null


func _ready() -> void:
	super._ready()
	wire_header_bar("فلش کارت")
	_wire_buttons()
	_attach_gloss_accents()
	_refresh_stats()

	if not Global.review_words_changed.is_connected(_on_review_words_changed):
		Global.review_words_changed.connect(_on_review_words_changed)

	_play_intro_animation()


func _exit_tree() -> void:
	if _ambient_tween != null and _ambient_tween.is_valid():
		_ambient_tween.kill()
	for key: int in _button_tweens:
		var tw: Tween = _button_tweens[key] as Tween
		if tw != null and tw.is_valid():
			tw.kill()
	_button_tweens.clear()
	if Global.review_words_changed.is_connected(_on_review_words_changed):
		Global.review_words_changed.disconnect(_on_review_words_changed)


func _on_review_words_changed() -> void:
	_refresh_stats()


############################################################
# LIVE VOCABULARY & SRS STATS
############################################################
func _refresh_stats() -> void:
	var saved_count: int = Global.get_saved_words().size()
	var review_list: Array = Global.get_review_words()
	var total_review: int = review_list.size()
	var due_count: int = Global.get_due_words().size()

	var new_count: int = 0
	var learning_count: int = 0
	var mastered_count: int = 0

	for raw: Variant in review_list:
		if not raw is Dictionary:
			continue
		var entry: Dictionary = raw
		var srs_due: int = int(entry.get("srs_due", -1))
		var srs_interval: float = float(entry.get("srs_interval", 0.0))
		if srs_due == -1:
			new_count += 1
		elif srs_interval >= MASTERED_INTERVAL_DAYS:
			mastered_count += 1
		else:
			learning_count += 1

	var saved_fa: String = MenuStyle.persian_digits(str(saved_count))
	var due_fa: String = MenuStyle.persian_digits(str(due_count))

	if saved_count == 0:
		_flashcard_badge_label.text = "شروع ذخیره‌سازی لغات 🔖"
	else:
		_flashcard_badge_label.text = "%s کلمه ذخیره‌شده 🔖" % saved_fa

	if total_review == 0:
		_leitner_badge_label.text = "تکرار فاصله‌دار هوشمند ✨"
	elif due_count > 0:
		_leitner_badge_label.text = "%s کارت آماده مرور 🔥" % due_fa
	else:
		_leitner_badge_label.text = "مرور امروز کامل شد ✓"

	var mastery_ratio: float = float(mastered_count) / float(total_review) if total_review > 0 else 0.0
	var mastery_pct: int = int(round(mastery_ratio * 100.0))
	_mastery_progress.value = mastery_ratio
	_mastery_percent_label.text = "%s٪ تسلط" % MenuStyle.persian_digits(str(mastery_pct))

	_new_pill_label.text = "جدید: %s" % MenuStyle.persian_digits(str(new_count))
	_learning_pill_label.text = "در حال مرور: %s" % MenuStyle.persian_digits(str(learning_count))
	_mastered_pill_label.text = "تثبیت‌شده: %s" % MenuStyle.persian_digits(str(mastered_count))

	if total_review == 0:
		_mastery_hint.text = "با افزودن لغات به جعبه لایتنر، نمودار پیشرفت تسلط شما فعال می‌شود."
	else:
		_mastery_hint.text = "کلماتی که با فاصلهٔ ۷ روز یا بیشتر تثبیت شوند، در بخش «تثبیت‌شده» شمارش می‌شوند."


############################################################
# WIRING & SPRING MICRO-INTERACTIONS
############################################################
func _wire_buttons() -> void:
	flashcard_button.pressed.connect(_on_flashcard_pressed)
	leitner_button.pressed.connect(_on_leitner_pressed)

	var spring_buttons: Array[Button] = [
		flashcard_button,
		leitner_button,
	]
	for btn: Button in spring_buttons:
		_wire_spring(btn)


func _attach_gloss_accents() -> void:
	GlossSheenScript.attach(flashcard_button, COLOR_BLUE, 30.0)
	GlossSheenScript.attach(leitner_button, COLOR_GOLD, 26.0)


func _wire_spring(btn: Button) -> void:
	btn.pivot_offset = btn.size / 2.0
	btn.resized.connect(_on_btn_resized.bind(btn))
	btn.mouse_entered.connect(_on_btn_hover.bind(btn, true))
	btn.mouse_exited.connect(_on_btn_hover.bind(btn, false))
	btn.button_down.connect(_animate_btn_scale.bind(btn, Vector2(0.96, 0.96), 0.07, Tween.TRANS_QUAD))
	btn.button_up.connect(_on_btn_released.bind(btn))


func _on_btn_resized(btn: Button) -> void:
	btn.pivot_offset = btn.size / 2.0


func _on_btn_hover(btn: Button, entered: bool) -> void:
	if btn.disabled or btn.button_pressed:
		return
	var target: Vector2 = Vector2(1.02, 1.02) if entered else Vector2.ONE
	var duration: float = 0.16 if entered else 0.20
	_animate_btn_scale(btn, target, duration, Tween.TRANS_BACK)


func _on_btn_released(btn: Button) -> void:
	var target: Vector2 = Vector2(1.02, 1.02) if btn.is_hovered() and not btn.disabled else Vector2.ONE
	_animate_btn_scale(btn, target, 0.20, Tween.TRANS_BACK)


func _animate_btn_scale(btn: Button, target: Vector2, duration: float, trans: Tween.TransitionType) -> void:
	var key: int = btn.get_instance_id()
	var prev: Tween = _button_tweens.get(key) as Tween
	if prev != null and prev.is_valid():
		prev.kill()
	var tw: Tween = btn.create_tween()
	tw.set_trans(trans)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", target, duration)
	_button_tweens[key] = tw


############################################################
# MOTION POLISH
############################################################
func _play_intro_animation() -> void:
	var targets: Array[Control] = []
	for child: Node in _content_col.get_children():
		if child is Control and not child.is_queued_for_deletion():
			var ctrl: Control = child as Control
			ctrl.modulate.a = 0.0
			ctrl.pivot_offset = ctrl.size / 2.0
			ctrl.scale = Vector2(0.96, 0.96)
			targets.append(ctrl)

	await get_tree().process_frame
	if not is_inside_tree():
		return

	var tw: Tween = create_tween()
	tw.set_parallel(true)
	for i: int in range(targets.size()):
		var target: Control = targets[i]
		target.pivot_offset = target.size / 2.0
		var delay: float = 0.04 * float(i)
		tw.tween_property(target, "modulate:a", 1.0, 0.26).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(target, "scale", Vector2.ONE, 0.32).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await tw.finished
	if not is_inside_tree():
		return
	_start_ambient()


func _start_ambient() -> void:
	if _flashcard_icon_chip == null:
		return
	_flashcard_icon_chip.pivot_offset = _flashcard_icon_chip.size / 2.0
	if _ambient_tween != null and _ambient_tween.is_valid():
		_ambient_tween.kill()
	_ambient_tween = create_tween().set_loops()
	_ambient_tween.tween_property(_flashcard_icon_chip, "scale", Vector2(1.05, 1.05), 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_ambient_tween.tween_property(_flashcard_icon_chip, "scale", Vector2.ONE, 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


############################################################
# NAVIGATION
############################################################
func _on_android_back_pressed() -> void:
	if _navigating:
		return
	_navigating = true
	Sfx.click()
	TransitionManager.slide_change_scene(SCENE_MAIN_MENU, TransitionManager.Slide.BACK)


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
	var target: String = SCENE_SAVED_WORDS if Global.get_saved_words().is_empty() else SCENE_FLASHCARDS
	await get_tree().create_timer(0.08).timeout
	if not is_inside_tree():
		return
	TransitionManager.slide_change_scene(target, TransitionManager.Slide.FORWARD)


func _on_leitner_pressed() -> void:
	if _navigating:
		return
	_navigating = true
	Sfx.click()
	AppRouter.set_args({"return_route": SCENE_SELF})
	await get_tree().create_timer(0.08).timeout
	if not is_inside_tree():
		return
	TransitionManager.slide_change_scene(SCENE_REVIEW, TransitionManager.Slide.FORWARD)
