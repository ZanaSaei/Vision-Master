extends "res://autoload/BackButtonHandler.gd"
class_name WordGameHub

const LEARNING_SCENE: String = "res://scenes/word_game/WordGameLearning.tscn"
const DAILY_SCENE: String = "res://scenes/word_game/DailyWordGame.tscn"
const MAIN_MENU_SCENE: String = "res://scenes/main_menu/MainMenu.tscn"
const BUTTON_PRESSED_SCALE: float = 0.94
const BUTTON_PRESS_DURATION: float = 0.12
const BUTTON_RELEASE_DURATION: float = 0.20

@onready var _back_button: Button = $HeaderBar/HeaderContent/BackButton
@onready var _learning_button: Button = $Scroll/MainMargin/MainColumn/ModeButtons/LearningButton
@onready var _daily_button: Button = $Scroll/MainMargin/MainColumn/ModeButtons/DailyButton
@onready var _daily_board_button: Button = $Scroll/MainMargin/MainColumn/Tabs/DailyBoardButton
@onready var _lifetime_button: Button = $Scroll/MainMargin/MainColumn/Tabs/LifetimeButton
@onready var _status: Label = $Scroll/MainMargin/MainColumn/Status
@onready var _entries: VBoxContainer = $Scroll/MainMargin/MainColumn/Entries

var _daily_selected: bool = true
var _board_request_id: int = 0
var _button_tweens: Dictionary = {}

func _ready() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	for button: Button in [_learning_button, _daily_button, _daily_board_button, _lifetime_button]:
		button.pivot_offset = button.size / 2.0
		button.resized.connect(_on_button_resized.bind(button))
		button.button_down.connect(_on_button_down.bind(button))
		button.button_up.connect(_on_button_up.bind(button))

	_learning_button.pressed.connect(_on_learning_pressed)
	_daily_button.pressed.connect(_on_daily_pressed)
	_daily_board_button.pressed.connect(_on_daily_board_pressed)
	_lifetime_button.pressed.connect(_on_lifetime_board_pressed)
	_load_board()

func _on_button_resized(button: Button) -> void:
	button.pivot_offset = button.size / 2.0

func _on_button_down(button: Button) -> void:
	_animate_button_scale(button, BUTTON_PRESSED_SCALE, BUTTON_PRESS_DURATION, Tween.EASE_OUT)

func _on_button_up(button: Button) -> void:
	_animate_button_scale(button, 1.0, BUTTON_RELEASE_DURATION, Tween.EASE_OUT)

func _animate_button_scale(button: Button, target_scale: float, duration: float, easing: Tween.EaseType) -> void:
	var button_id: int = button.get_instance_id()
	var previous_tween: Tween = _button_tweens.get(button_id) as Tween
	if previous_tween != null and previous_tween.is_running():
		previous_tween.kill()

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(easing)
	tween.tween_property(button, "scale", Vector2(target_scale, target_scale), duration)
	_button_tweens[button_id] = tween

func _on_learning_pressed() -> void:
	TransitionManager.change_scene(LEARNING_SCENE)

func _on_daily_pressed() -> void:
	TransitionManager.change_scene(DAILY_SCENE)

func _on_daily_board_pressed() -> void:
	_daily_selected = true
	_load_board()

func _on_lifetime_board_pressed() -> void:
	_daily_selected = false
	_load_board()

func _update_tab_selection() -> void:
	# Selection state only — visuals are Inspector-owned.
	# In WordGameHub.tscn set toggle_mode = true on both tab buttons and
	# style button_pressed differently from normal to show selection.
	_daily_board_button.button_pressed = _daily_selected
	_lifetime_button.button_pressed = not _daily_selected


func _load_board() -> void:
	_board_request_id += 1
	for child: Node in _entries.get_children():
		_entries.remove_child(child)
		child.queue_free()
	_update_tab_selection()
	if not API.is_configured() or not API.is_logged_in():
		_status.text = "برای مشاهدهٔ رتبه‌بندی جهانی، ورود و اتصال اینترنت لازم است."
		return
	var request_id: int = _board_request_id
	_status.text = "در حال دریافت رتبه‌بندی رسمی از سرور…"
	if _daily_selected:
		API.fetch_daily_leaderboard(50, 0, func(ok: bool, data: Dictionary) -> void: _on_board_loaded(request_id, true, ok, data))
	else:
		API.fetch_lifetime_leaderboard(50, 0, func(ok: bool, data: Dictionary) -> void: _on_board_loaded(request_id, false, ok, data))

func _on_board_loaded(request_id: int, was_daily: bool, ok: bool, data: Dictionary) -> void:
	if request_id != _board_request_id or was_daily != _daily_selected:
		return
	if not ok:
		_status.text = "رتبه‌بندی از سرور دریافت نشد؛ لطفاً اتصال را بررسی کنید."
		return
	var period: String = "امروز · %s" % str(data.get("date", "")) if _daily_selected else "مجموع امتیازهای ثبت‌شده"
	var self_row: Variant = data.get("self", null)
	if self_row is Dictionary:
		var self_data: Dictionary = self_row
		_status.text = "%s\nرتبهٔ شما: %s · امتیاز: %s" % [period, str(self_data.get("rank", "—")), str(self_data.get("score", 0))]
	else:
		_status.text = "%s\nهنوز امتیازی در این بازه ندارید." % period
	var rows: Array = data.get("entries", [])
	if rows.is_empty():
		_entries.add_child(_make_label("هنوز بازیکنی در این بازه امتیاز ثبت نکرده است."))
		return
	for raw: Variant in rows:
		if not raw is Dictionary:
			continue
		var entry: Dictionary = raw
		var panel: PanelContainer = PanelContainer.new()
		panel.name = "SelfRow" if bool(entry.get("isSelf", false)) else "Row"
		var row: HBoxContainer = HBoxContainer.new()
		panel.add_child(row)
		row.add_child(_make_label("#%s" % str(entry.get("rank", "—"))))
		row.add_child(_make_label(str(entry.get("name", "بازیکن"))))
		var score: Label = _make_label(str(entry.get("score", 0)))
		score.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(score)
		_entries.add_child(panel)

func _make_label(value: String) -> Label:
	var label: Label = Label.new()
	label.text = value
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _on_back_pressed() -> void:
	TransitionManager.change_scene(MAIN_MENU_SCENE)

func _on_android_back_pressed() -> void:
	_on_back_pressed()
