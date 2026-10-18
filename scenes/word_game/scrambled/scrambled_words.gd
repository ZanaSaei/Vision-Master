extends "res://autoload/BackButtonHandler.gd"
const MODE_SELECT_SCENE := preload("res://scenes/word_game/scrambled/ModeSelect.tscn")
const LESSON_SELECT_SCENE := preload("res://scenes/word_game/scrambled/LessonSelect.tscn")
const GAMEPLAY_SCENE := preload("res://scenes/word_game/scrambled/Gameplay.tscn")
const RESULTS_SCENE := preload("res://scenes/word_game/scrambled/Results.tscn")
const SCENE_WORD_GAME := "res://scenes/word_game/WordGameHub.tscn"
const DEFAULT_TITLE := "بازی املا"
@onready var _header: PanelContainer = $HeaderBar
@onready var _back_button: Button = $HeaderBar/HeaderContent/BackButton
@onready var _title: Label = $HeaderBar/HeaderContent/HeaderTitle
@onready var _host: Control = $ScreenHost
var _screen: Control = null
func _ready() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	_apply_theme()
	Global.on_theme_changed(_on_theme_changed)
	_show_mode_select()
func _on_theme_changed(_mode: int) -> void:
	_apply_theme()
func _apply_theme() -> void:
	var background := $Background as ColorRect
	if background != null:
		background.color = ScrambledTheme.page_tint()
	Global.style_header(_header)
func _on_back_pressed() -> void:
	if _screen != null and _screen.has_method("handle_back"):
		_screen.call("handle_back")
		return
	TransitionManager.change_scene(SCENE_WORD_GAME)
func _on_android_back_pressed() -> void:
	_on_back_pressed()
func _show_mode_select() -> void:
	_swap_to(MODE_SELECT_SCENE)
func _show_lesson_select() -> void:
	_swap_to(LESSON_SELECT_SCENE)
func _show_results() -> void:
	_swap_to(RESULTS_SCENE)
func _start_learning(book: int, lesson: int) -> void:
	if not ScrambledGameManager.start_learning(book, lesson):
		push_warning("ScrambledWords: lesson %d/%d has no playable words" % [book, lesson])
		return
	_swap_to(GAMEPLAY_SCENE)
func _swap_to(scene: PackedScene) -> void:
	var next := scene.instantiate() as Control
	next.set_anchors_preset(Control.PRESET_FULL_RECT)
	next.pivot_offset = _host.size * 0.5
	next.resized.connect(func() -> void: next.pivot_offset = next.size * 0.5)
	next.modulate.a = 0.0
	next.scale = Vector2(0.95, 0.95)
	_host.add_child(next)
	_wire_screen(next)
	var previous := _screen
	_screen = next
	if previous != null:
		var out := create_tween()
		out.tween_property(previous, "modulate:a", 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		out.tween_callback(previous.queue_free)
	var tw := create_tween()
	tw.tween_property(next, "modulate:a", 1.0, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(next, "scale", Vector2.ONE, 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_update_title()
func _wire_screen(screen: Control) -> void:
	if screen.has_signal("learning_requested"):
		screen.connect("learning_requested", _show_lesson_select)
	if screen.has_signal("exit_requested"):
		screen.connect("exit_requested", _leave_game)
	if screen.has_signal("lesson_chosen"):
		screen.connect("lesson_chosen", _start_learning)
	if screen.has_signal("back_requested"):
		screen.connect("back_requested", _show_mode_select)
	if screen.has_signal("quit_requested"):
		screen.connect("quit_requested", _leave_to_modes)
	if screen.has_signal("session_finished"):
		screen.connect("session_finished", _show_results)
	if screen.has_signal("home_requested"):
		screen.connect("home_requested", _show_mode_select)
	if screen.has_signal("replay_requested"):
		screen.connect("replay_requested", _replay)
func _leave_game() -> void:
	TransitionManager.change_scene(SCENE_WORD_GAME)
func _leave_to_modes() -> void:
	if ScrambledGameManager.mode == ScrambledGameManager.Mode.LEARNING:
		_show_lesson_select()
	else:
		_show_mode_select()
func _replay() -> void:
	if ScrambledGameManager.mode == ScrambledGameManager.Mode.COMPETITION:
		_show_mode_select()
	else:
		_start_learning(ScrambledGameManager.book, ScrambledGameManager.lesson)
func _update_title() -> void:
	if _screen != null and _screen.has_method("screen_title"):
		_title.text = str(_screen.call("screen_title"))
		return
	_title.text = DEFAULT_TITLE
