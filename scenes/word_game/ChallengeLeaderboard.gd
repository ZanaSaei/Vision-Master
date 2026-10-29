extends "res://autoload/BackButtonHandler.gd"
class_name ChallengeLeaderboard

@onready var _background: ColorRect = $Background
@onready var _back_button: Button = $HeaderBar/HeaderContent/BackButton
@onready var _daily_button: Button = $Scroll/MainMargin/MainColumn/Tabs/DailyButton
@onready var _lifetime_button: Button = $Scroll/MainMargin/MainColumn/Tabs/LifetimeButton
@onready var _status: Label = $Scroll/MainMargin/MainColumn/Status
@onready var _entries: VBoxContainer = $Scroll/MainMargin/MainColumn/Entries
var _daily_selected: bool = true
var _board_request_id: int = 0

func _ready() -> void:
	MenuStyle.style_back_button(_back_button)
	MenuStyle.style_button(_daily_button, "primary")
	MenuStyle.style_button(_lifetime_button, "secondary")
	_back_button.pressed.connect(_go_back)
	_daily_button.pressed.connect(_on_daily_pressed)
	_lifetime_button.pressed.connect(_on_lifetime_pressed)
	_background.color = MenuStyle.c("bg")
	_load_board()

func _on_daily_pressed() -> void:
	_daily_selected = true
	_load_board()

func _on_lifetime_pressed() -> void:
	_daily_selected = false
	_load_board()

func _load_board() -> void:
	_board_request_id += 1
	for child: Node in _entries.get_children():
		_entries.remove_child(child)
		child.queue_free()
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
	var period: String = "امروز · %s" % JalaliCalendar.persian_digits(str(data.get("date", ""))) if _daily_selected else "مجموع امتیازهای ثبت‌شده"
	var self_row: Variant = data.get("self", null)
	if self_row is Dictionary:
		var self_data: Dictionary = self_row
		_status.text = "%s\nرتبهٔ شما: %s · امتیاز: %s" % [period, JalaliCalendar.persian_digits(str(self_data.get("rank", "—"))), JalaliCalendar.persian_digits(str(self_data.get("score", 0)))]
	else:
		_status.text = "%s\nهنوز امتیازی در این بازه ندارید." % period
	var rows: Array = data.get("entries", [])
	if rows.is_empty():
		_entries.add_child(_make_label("هنوز بازیکنی در این بازه امتیاز ثبت نکرده است.", 26))
		return
	for raw: Variant in rows:
		if not raw is Dictionary:
			continue
		var entry: Dictionary = raw
		var highlighted: bool = bool(entry.get("isSelf", false))
		var panel: PanelContainer = PanelContainer.new()
		panel.add_theme_stylebox_override("panel", MenuStyle.card_style(MenuStyle.accent() if highlighted else MenuStyle.border(), 18, highlighted, false))
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		panel.add_child(row)
		row.add_child(_make_label("#%s" % JalaliCalendar.persian_digits(str(entry.get("rank", "—"))), 24))
		row.add_child(_make_label(str(entry.get("name", "بازیکن")), 23))
		var score: Label = _make_label(JalaliCalendar.persian_digits(str(entry.get("score", 0))), 25)
		score.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(score)
		_entries.add_child(panel)

func _make_label(value: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = value
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", MenuStyle.vazir())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", MenuStyle.text())
	return label

func _go_back() -> void:
	TransitionManager.change_scene("res://scenes/word_game/WordGameHub.tscn")

func _on_android_back_pressed() -> void:
	_go_back()