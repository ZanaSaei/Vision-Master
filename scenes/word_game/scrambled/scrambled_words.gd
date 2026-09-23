extends "res://autoload/BackButtonHandler.gd"
## ============================================================
##  SCRAMBLED WORDS — «بازی املا», the game's entry point.
##
##  Owns the header bar and the back navigation, and hosts the four screens
##  inside itself (mode · lessons · gameplay · results) so switching screens
##  never reloads the scene: the word bank, the player's record and the
##  session in progress all stay put.
##
##  This scene is listed in ThemeService.SELF_THEMED_SCRIPTS, because a board
##  mid-puzzle must not be restyled by the app-wide theme walk. The header is
##  therefore styled explicitly (Global.style_header) and the screens theme
##  themselves through ScrambledTheme, on a live theme toggle included.
##
##  Flow:
##    ModeSelect ──learning──▶ LessonSelect ──lesson──▶ Gameplay ──▶ Results
##         └──────competition──────────────────────────▶ Gameplay ──▶ Results
## ============================================================

const MODE_SELECT_SCENE := preload("res://scenes/word_game/scrambled/ModeSelect.tscn")
const LESSON_SELECT_SCENE := preload("res://scenes/word_game/scrambled/LessonSelect.tscn")
const GAMEPLAY_SCENE := preload("res://scenes/word_game/scrambled/Gameplay.tscn")
const RESULTS_SCENE := preload("res://scenes/word_game/scrambled/Results.tscn")

## Accents of the two modes, reused by the lesson cards and the results.
const COLOR_LEARNING := Color("#22C55E")
const COLOR_COMPETITION := Color("#F59E0B")

const SCENE_WORD_GAME := "res://scenes/word_game/WordGame.tscn"
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


## The header is the app's shared header, so it goes through the same call
## every walked scene gets; the page tint is the game's own.
func _apply_theme() -> void:
	var background := $Background as ColorRect
	if background != null:
		background.color = ScrambledTheme.page_tint()
	Global.style_header(_header)


## ------------------------------------------------------------ navigation --
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


func _start_competition() -> void:
	if not ScrambledGameManager.start_competition():
		push_warning("ScrambledWords: the daily words could not be loaded")
		return
	_swap_to(GAMEPLAY_SCENE)


## Cross-fades the hosted screens, with the incoming one popping in slightly
## (TRANS_BACK), which matches the rest of the game's feel.
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
		out.tween_property(previous, "modulate:a", 0.0, 0.16) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		out.tween_callback(previous.queue_free)

	var tw := create_tween()
	tw.tween_property(next, "modulate:a", 1.0, 0.26) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(next, "scale", Vector2.ONE, 0.36) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_update_title()


## Screens talk back through their own signals; the host decides where the
## player goes, so navigation lives in exactly one place.
func _wire_screen(screen: Control) -> void:
	if screen.has_signal("learning_requested"):
		screen.connect("learning_requested", _show_lesson_select)
	if screen.has_signal("competition_requested"):
		screen.connect("competition_requested", _start_competition)
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


## Backing out of a game: a lesson returns to the lesson list (the next lesson
## is then one tap away), a competition to the mode screen.
func _leave_to_modes() -> void:
	if ScrambledGameManager.mode == ScrambledGameManager.Mode.LEARNING:
		_show_lesson_select()
	else:
		_show_mode_select()


## "بازی دوباره" on the results card: the same mode, dealt again.
func _replay() -> void:
	if ScrambledGameManager.mode == ScrambledGameManager.Mode.COMPETITION:
		_start_competition()
	else:
		_start_learning(ScrambledGameManager.book, ScrambledGameManager.lesson)


## Screens re-theme themselves; the host only retints and restyles the header.
func _update_title() -> void:
	if _screen != null and _screen.has_method("screen_title"):
		_title.text = str(_screen.call("screen_title"))
		return
	_title.text = DEFAULT_TITLE