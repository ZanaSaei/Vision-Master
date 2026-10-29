extends "res://autoload/BackButtonHandler.gd"
class_name DailyWordGame

const DailyChallengeStateStore = preload("res://autoload/DailyChallengeState.gd")

const HUB_SCENE: String = "res://scenes/word_game/WordGameHub.tscn"
const OFFICIAL_GAME_SCENE: String = "res://scenes/word_game/OfficialChallengeGame.tscn"
const SCORE_PANEL: PackedScene = preload("res://scenes/word_game/ScorePanel.tscn")
const GAME_TYPES: Array[String] = ["wordle", "wordef", "unscramble"]
const GAME_TITLES: Dictionary = {"wordle": "Wordle", "wordef": "Wordef", "unscramble": "Unscramble"}
var _root: VBoxContainer
var _status: Label
var _month_title: Label
var _day_strip: HBoxContainer
var _scroll: ScrollContainer
var _game_buttons: Dictionary = {}
var _calendar_data: Dictionary = {}
var _selected_date: String = ""
var _summary: Dictionary = {}
var _score_panel: ChallengeScorePanel
var _busy: bool = false
var _summary_request_date: String = ""
var _attempt_status_request_date: String = ""
var _summary_refresh_generation: int = 0

func _ready() -> void:
	_build_ui()
	_load_calendar()

func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = MenuStyle.c("bg")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var scroll_page: ScrollContainer = ScrollContainer.new()
	scroll_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll_page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll_page)

	var margin: MarginContainer = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 240)
	margin.add_theme_constant_override("margin_bottom", 250)
	scroll_page.add_child(margin)

	_root = VBoxContainer.new()
	_root.add_theme_constant_override("separation", 18)
	margin.add_child(_root)

	_month_title = _make_label("در حال دریافت تقویم…", 30, true)
	_root.add_child(_month_title)

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size.y = 178
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_root.add_child(_scroll)
	_day_strip = HBoxContainer.new()
	_day_strip.add_theme_constant_override("separation", 10)
	_day_strip.layout_direction = Control.LAYOUT_DIRECTION_RTL
	_scroll.add_child(_day_strip)

	var summary_title: Label = _make_label("امتیاز روز انتخاب‌شده", 28, true)
	_root.add_child(summary_title)
	_score_panel = SCORE_PANEL.instantiate() as ChallengeScorePanel
	_root.add_child(_score_panel)
	_score_panel.set_scores(0, 0, "امتیاز روز")

	var status_row: PanelContainer = PanelContainer.new()
	status_row.add_theme_stylebox_override("panel", MenuStyle.card_style(MenuStyle.accent(), 22, false, true))
	var status_pad: MarginContainer = MarginContainer.new()
	status_pad.add_theme_constant_override("margin_left", 18)
	status_pad.add_theme_constant_override("margin_right", 18)
	status_pad.add_theme_constant_override("margin_top", 12)
	status_pad.add_theme_constant_override("margin_bottom", 12)
	status_row.add_child(status_pad)
	_status = _make_label("", 24, false)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_pad.add_child(_status)
	_root.add_child(status_row)

	for game_type: String in GAME_TYPES:
		var button: Button = MenuStyle.make_button("%s  ·  شروع بازی" % GAME_TITLES[game_type], "primary", 112)
		button.layout_direction = Control.LAYOUT_DIRECTION_RTL
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_game_pressed.bind(game_type))
		_root.add_child(button)
		_game_buttons[game_type] = button
	MenuStyle.wire_microinteractions(_game_buttons["wordle"])
	MenuStyle.wire_microinteractions(_game_buttons["wordef"])
	MenuStyle.wire_microinteractions(_game_buttons["unscramble"])
	_wire_header()

## The screen wears the app-wide header bar authored in DailyWordGame.tscn, the
## same bar the lesson screens carry. The bar is moved to the end of the child
## list so the scrolling page glides underneath it instead of over it.
func _wire_header() -> void:
	var header: Control = get_node_or_null("HeaderBar") as Control
	if header == null:
		return
	move_child(header, get_child_count() - 1)
	var back: Button = header.get_node_or_null("HeaderContent/BackButton") as Button
	if back != null:
		back.pressed.connect(_go_back)

func _load_calendar() -> void:
	if not API.is_configured() or not API.is_logged_in():
		_set_error("برای چالش رسمی، ورود به حساب و اتصال اینترنت لازم است.")
		return
	_status.text = "در حال بارگذاری تقویم از سرور…"
	API.fetch_challenge_calendar(_on_calendar_loaded)

func _on_calendar_loaded(ok: bool, data: Dictionary) -> void:
	if not ok:
		_set_error(_error_message(data))
		return
	_calendar_data = data
	var today: String = str(data.get("today", ""))
	var persisted: String = DailyChallengeStateStore.load_selected_date()
	_selected_date = persisted if _date_is_in_calendar(persisted, data.get("days", [])) else today
	DailyChallengeStateStore.set_selected_date(_selected_date)
	var jalali: Dictionary = data.get("jalali", {})
	_month_title.text = "%s %s" % [JalaliCalendar.month_name(int(jalali.get("month", 1))), JalaliCalendar.persian_digits(str(jalali.get("year", "")))]
	_build_day_cards(data.get("days", []))
	_load_summary()
	_status.text = "تاریخ چالش بر اساس ساعت رسمی تهران است. آینده قابل انتخاب نیست."

func _date_is_in_calendar(date_key: String, days: Array) -> bool:
	for raw: Variant in days:
		if raw is Dictionary and str(raw.get("date", "")) == date_key and not bool(raw.get("future", false)):
			return true
	return false

func _build_day_cards(days: Array) -> void:
	for child: Node in _day_strip.get_children():
		_day_strip.remove_child(child)
		child.queue_free()
	# Keep chronological ascending data order; the container uses RTL layout so
	# the current/latest date appears at the right edge.
	for index: int in range(days.size()):
		var item: Variant = days[index]
		if not item is Dictionary:
			continue
		var cell: Dictionary = item
		var date_key: String = str(cell.get("date", ""))
		var jalali: Dictionary = cell.get("jalali", {})
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(144, 150)
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.disabled = bool(cell.get("future", false))
		button.set_meta("date", date_key)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_stylebox_override("normal", _day_style(date_key == _selected_date, button.disabled))
		button.add_theme_stylebox_override("disabled", _day_style(date_key == _selected_date, true))
		button.add_theme_stylebox_override("pressed", _day_style(true, false))
		button.add_theme_font_override("font", MenuStyle.vazir())
		button.add_theme_font_size_override("font_size", 1)
		var box: VBoxContainer = VBoxContainer.new()
		box.set_anchors_preset(Control.PRESET_FULL_RECT)
		box.add_theme_constant_override("separation", 2)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(box)
		box.add_child(_make_label(JalaliCalendar.persian_digits(str(jalali.get("day", ""))), 35, true))
		box.add_child(_make_label("%s امتیاز" % JalaliCalendar.persian_digits(str(cell.get("totalScore", 0))), 19, false))
		box.add_child(_make_label("%s/۳" % JalaliCalendar.persian_digits(str(cell.get("completedGames", 0))), 18, false))
		button.pressed.connect(_select_date.bind(date_key))
		_day_strip.add_child(button)
		button.resized.connect(_center_selected_card)
	call_deferred("_center_selected_card")

func _day_style(selected: bool, disabled: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = MenuStyle.card_style(MenuStyle.accent() if selected else MenuStyle.border(), 20, selected, false)
	if disabled:
		style.bg_color = MenuStyle.surface().darkened(0.18)
		style.border_color = Color(MenuStyle.border(), 0.45)
	return style

func _center_selected_card() -> void:
	if _day_strip == null or _day_strip.get_child_count() == 0:
		return
	for i: int in range(_day_strip.get_child_count()):
		var child: Button = _day_strip.get_child(i) as Button
		var days: Array = _calendar_data.get("days", [])
		if i >= days.size():
			continue
		var cell: Dictionary = days[i]
		var selected: bool = str(cell.get("date", "")) == _selected_date
		child.custom_minimum_size = Vector2(160 if selected else 136, 160 if selected else 142)
		child.add_theme_stylebox_override("normal", _day_style(selected, child.disabled))
	var selected_control: Control = null
	for child_node: Node in _day_strip.get_children():
		var day_button: Button = child_node as Button
		if day_button != null and str(day_button.get_meta("date", "")) == _selected_date:
			selected_control = day_button
	if selected_control != null:
		var target: int = int(selected_control.position.x + selected_control.size.x * 0.5 - _scroll.size.x * 0.5)
		_scroll.scroll_horizontal = maxi(0, target)

func _select_date(date_key: String) -> void:
	_selected_date = date_key
	_summary.clear()
	DailyChallengeStateStore.set_selected_date(date_key)
	_build_day_cards(_calendar_data.get("days", []))
	_load_summary()

func _load_summary() -> void:
	if _selected_date.is_empty():
		return
	_summary_refresh_generation += 1
	var generation: int = _summary_refresh_generation
	var request_date: String = _selected_date
	_summary_request_date = request_date
	API.fetch_challenge_summary(request_date, func(ok: bool, data: Dictionary) -> void:
		if generation != _summary_refresh_generation or request_date != _selected_date:
			return
		_on_summary_loaded(ok, data)
	)

func _refresh_current_attempt_status() -> void:
	var attempt_id: String = DailyChallengeState.current_attempt_id
	if attempt_id.is_empty() or DailyChallengeState.selected_date != _selected_date:
		return
	var request_key: String = _selected_date + ":" + attempt_id
	if _attempt_status_request_date == request_key:
		return
	_attempt_status_request_date = request_key
	API.fetch_challenge_attempt(attempt_id, func(ok: bool, data: Dictionary) -> void:
		if _selected_date != DailyChallengeState.selected_date or attempt_id != DailyChallengeState.current_attempt_id:
			return
		if not ok:
			return
		var attempt: Dictionary = data.get("attempt", {})
		DailyChallengeStateStore.begin_attempt(
			DailyChallengeState.selected_game,
			attempt_id,
			bool(attempt.get("counted", DailyChallengeState.current_attempt_counted)),
			DailyChallengeState.current_public_content,
			str(attempt.get("startedAt", DailyChallengeState.current_attempt_started_at)),
			attempt.get("state", {}),
			str(attempt.get("status", DailyChallengeState.current_attempt_status))
		)
		_load_summary()
	)

func _on_summary_loaded(ok: bool, data: Dictionary) -> void:
	if _summary_request_date != _selected_date:
		return
	if not ok:
		_set_error(_error_message(data))
		return
	_summary = data
	_score_panel.set_scores(int(data.get("dayTotal", 0)), int(data.get("lifetimeTotal", 0)), "امتیاز روز")
	var games: Dictionary = data.get("games", {})
	_refresh_current_attempt_status()
	for game_type: String in GAME_TYPES:
		var game: Dictionary = games.get(game_type, {})
		var button: Button = _game_buttons[game_type] as Button
		button.set_meta("game_type", game_type)
		var completed: bool = bool(game.get("completed", false))
		var in_progress: bool = bool(game.get("inProgress", false))
		button.set_meta("existing_attempt", in_progress and not completed)
		button.set_meta("counted", bool(game.get("counted", false)))
		if completed:
			button.text = "%s  ·  انجام‌شده" % GAME_TITLES[game_type]
		elif in_progress:
			button.text = "%s  ·  ادامه بازی" % GAME_TITLES[game_type]
		else:
			button.text = "%s  ·  شروع بازی" % GAME_TITLES[game_type]
		button.disabled = _is_future_selected() or not _date_is_today()

func _date_is_today() -> bool:
	for raw: Variant in _calendar_data.get("days", []):
		if raw is Dictionary and str(raw.get("date", "")) == _selected_date:
			return bool(raw.get("today", false))
	return false

func _on_game_pressed(game_type: String) -> void:
	if _busy or _summary.is_empty() or _selected_date.is_empty() or _is_future_selected():
		return
	if not _date_is_today():
		_set_error("بازی روزهای گذشته فقط برای مشاهده و تمرین قابل دسترسی است.")
		return
	var game: Dictionary = _summary.get("games", {}).get(game_type, {})
	if bool(game.get("completed", false)):
		_set_error("این بازی قبلاً کامل شده است. تکرار بدون امتیاز از بخش یادگیری انجام می‌شود.")
		return
	var counted: bool = true
	if not API.is_configured() or not API.is_logged_in():
		_set_error("برای شروع چالش رسمی، اینترنت و ورود به حساب لازم است.")
		return
	_busy = true
	_status.text = "در حال رزرو تلاش رسمی…"
	var existing_attempt: bool = bool(game.get("inProgress", false))
	var key: String = "%s:%s:%s" % [API.get_user_id(), _selected_date, game_type]
	if existing_attempt:
		key = ""
	API.start_challenge_attempt(_selected_date, game_type, key, func(ok: bool, data: Dictionary) -> void:
		_busy = false
		if not ok:
			_set_error(_error_message(data))
			_load_summary()
			return
		var attempt: Dictionary = data.get("attempt", {})
		var reserved_id: String = str(attempt.get("id", ""))
		if reserved_id.is_empty():
			_set_error("سرور تلاش بازی را ایجاد نکرد. دوباره تلاش کنید.")
			return
		var attempt_is_counted: bool = bool(attempt.get("counted", counted))
		if str(attempt.get("status", "in_progress")) == "abandoned":
			_set_error("این تلاش پیش‌تر بسته شده است و امکان ادامه ندارد.")
			_load_summary()
			return
		DailyChallengeStateStore.set_selected_date(_selected_date)
		DailyChallengeStateStore.begin_attempt(game_type, reserved_id, attempt_is_counted, data.get("publicContent", {}), str(attempt.get("startedAt", "")), attempt.get("state", {}), str(attempt.get("status", "in_progress")))
		TransitionManager.change_scene(OFFICIAL_GAME_SCENE)
	)

func _is_future_selected() -> bool:
	for raw: Variant in _calendar_data.get("days", []):
		if raw is Dictionary and str(raw.get("date", "")) == _selected_date:
			return bool(raw.get("future", false))
	return true

func _set_error(message: String) -> void:
	_status.text = message

func _error_message(data: Dictionary) -> String:
	var code: String = str(data.get("error", ""))
	if code == "unauthorized" or code == "missing_token" or code == "invalid_token":
		return "برای چالش رسمی ابتدا وارد حساب کاربری شوید."
	if code == "no_base_url" or code == "future_date" or code == "date_unavailable":
		return "چالش رسمی در دسترس نیست؛ اتصال اینترنت و تاریخ انتخاب‌شده را بررسی کنید."
	if code == "attempt_closed":
		return "این تلاش قبلاً بسته شده و قابل بازیابی نیست."
	return "دریافت اطلاعات از سرور ناموفق بود. لطفاً دوباره تلاش کنید."

func _make_label(text_value: String, font_size: int, bold: bool) -> Label:
	var label: Label = Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", MenuStyle.vazir() if not bold else MenuStyle.jakarta_bold())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", MenuStyle.text())
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _go_back() -> void:
	TransitionManager.change_scene(HUB_SCENE)

func _on_android_back_pressed() -> void:
	_go_back()