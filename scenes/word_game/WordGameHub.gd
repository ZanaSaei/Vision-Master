extends "res://autoload/BackButtonHandler.gd"
class_name WordGameHub

const LEARNING_SCENE: String = "res://scenes/word_game/WordGameLearning.tscn"
const DAILY_SCENE: String = "res://scenes/word_game/DailyWordGame.tscn"
const MAIN_MENU_SCENE: String = "res://scenes/main_menu/MainMenu.tscn"
const AUTH_SCENE: String = "res://scenes/auth/Auth.tscn"

const GlossSheenScript := preload("res://ui/widgets/gloss_sheen.gd")

const COLOR_BLUE := Color("#2F6FD8")
const COLOR_GOLD := Color("#A87C24")
const COLOR_PURPLE := Color("#7C3AED")

const COLLAPSED_LEADERBOARD_LIMIT := 10

enum BoardAction { NONE, LOGIN, RETRY }

@onready var _root_scroll: ScrollContainer = $RootScroll
@onready var _main_col: VBoxContainer = $RootScroll/OuterMargin/MainColumn

@onready var _daily_button: Button = $RootScroll/OuterMargin/MainColumn/DailyButton
@onready var _daily_badge_label: Label = $RootScroll/OuterMargin/MainColumn/DailyButton/Margin/Row/TextColumn/TopTagRow/ContextBadge/BadgeLabel
@onready var _daily_icon_chip: Control = $RootScroll/OuterMargin/MainColumn/DailyButton/Margin/Row/IconChip
@onready var _learning_button: Button = $RootScroll/OuterMargin/MainColumn/LearningButton

@onready var _lifetime_stat_card: Button = $RootScroll/OuterMargin/MainColumn/StatsBento/LifetimeStatCard
@onready var _lifetime_stat_value: Label = $RootScroll/OuterMargin/MainColumn/StatsBento/LifetimeStatCard/Margin/VBox/TopRow/ValueLabel
@onready var _lifetime_stat_sub: Label = $RootScroll/OuterMargin/MainColumn/StatsBento/LifetimeStatCard/Margin/VBox/SubLabel
@onready var _today_stat_card: Button = $RootScroll/OuterMargin/MainColumn/StatsBento/TodayStatCard
@onready var _today_stat_value: Label = $RootScroll/OuterMargin/MainColumn/StatsBento/TodayStatCard/Margin/VBox/TopRow/ValueLabel
@onready var _today_stat_sub: Label = $RootScroll/OuterMargin/MainColumn/StatsBento/TodayStatCard/Margin/VBox/SubLabel

@onready var _leaderboard_card: PanelContainer = $RootScroll/OuterMargin/MainColumn/LeaderboardCard
@onready var _rank_pill_label: Label = $RootScroll/OuterMargin/MainColumn/LeaderboardCard/BoardMargin/BoardVBox/BoardHeader/RankPill/RankPillLabel
@onready var _daily_board_button: Button = $RootScroll/OuterMargin/MainColumn/LeaderboardCard/BoardMargin/BoardVBox/SegmentedTrack/Tabs/DailyBoardButton
@onready var _lifetime_button: Button = $RootScroll/OuterMargin/MainColumn/LeaderboardCard/BoardMargin/BoardVBox/SegmentedTrack/Tabs/LifetimeButton
@onready var _status: Label = $RootScroll/OuterMargin/MainColumn/LeaderboardCard/BoardMargin/BoardVBox/StatusBanner/StatusVBox/Status
@onready var _board_action_button: Button = $RootScroll/OuterMargin/MainColumn/LeaderboardCard/BoardMargin/BoardVBox/StatusBanner/StatusVBox/BoardActionButton
@onready var _daily_entries: VBoxContainer = $RootScroll/OuterMargin/MainColumn/LeaderboardCard/BoardMargin/BoardVBox/DailyEntries
@onready var _lifetime_entries: VBoxContainer = $RootScroll/OuterMargin/MainColumn/LeaderboardCard/BoardMargin/BoardVBox/LifetimeEntries
@onready var _show_more_button: Button = $RootScroll/OuterMargin/MainColumn/LeaderboardCard/BoardMargin/BoardVBox/ShowMoreButton

var _navigating: bool = false
var _daily_selected: bool = true
var _daily_request_id: int = 0
var _lifetime_request_id: int = 0

var _daily_status_text: String = "در حال دریافت رتبه‌بندی امروز از سرور…"
var _lifetime_status_text: String = "در حال دریافت رتبه‌بندی کل از سرور…"
var _daily_rank_badge: String = "برترین‌ها 🏆"
var _lifetime_rank_badge: String = "برترین‌ها 🏆"
var _daily_action: BoardAction = BoardAction.NONE
var _lifetime_action: BoardAction = BoardAction.NONE
var _daily_rows: Array = []
var _lifetime_rows: Array = []
var _daily_expanded: bool = false
var _lifetime_expanded: bool = false

var _button_tweens: Dictionary = {}
var _ambient_tween: Tween = null
var _scroll_tween: Tween = null


func _ready() -> void:
	super._ready()
	wire_header_bar("بازی با کلمات")
	_wire_buttons()
	_attach_gloss_accents()
	_connect_auth_signals()

	_apply_panels_visibility()
	_update_tab_selection()
	_sync_active_board_chrome()
	_load_daily_board()
	_load_lifetime_board()
	_play_intro_animation()


func _exit_tree() -> void:
	if _ambient_tween != null and _ambient_tween.is_valid():
		_ambient_tween.kill()
	if _scroll_tween != null and _scroll_tween.is_valid():
		_scroll_tween.kill()
	for key: int in _button_tweens:
		var tw: Tween = _button_tweens[key] as Tween
		if tw != null and tw.is_valid():
			tw.kill()
	_button_tweens.clear()
	_disconnect_auth_signals()


func _connect_auth_signals() -> void:
	if not API.logged_in.is_connected(_on_auth_state_changed):
		API.logged_in.connect(_on_auth_state_changed)
	if not API.logged_out.is_connected(_on_logged_out):
		API.logged_out.connect(_on_logged_out)


func _disconnect_auth_signals() -> void:
	if API.logged_in.is_connected(_on_auth_state_changed):
		API.logged_in.disconnect(_on_auth_state_changed)
	if API.logged_out.is_connected(_on_logged_out):
		API.logged_out.disconnect(_on_logged_out)


func _on_auth_state_changed(_payload: Dictionary) -> void:
	_load_daily_board()
	_load_lifetime_board()


func _on_logged_out() -> void:
	_load_daily_board()
	_load_lifetime_board()


############################################################
# WIRING & SPRING MICRO-INTERACTIONS
############################################################
func _wire_buttons() -> void:
	_daily_button.pressed.connect(_on_daily_pressed)
	_learning_button.pressed.connect(_on_learning_pressed)

	_today_stat_card.pressed.connect(_on_stat_card_pressed.bind(true))
	_lifetime_stat_card.pressed.connect(_on_stat_card_pressed.bind(false))

	_daily_board_button.pressed.connect(_on_daily_board_pressed)
	_lifetime_button.pressed.connect(_on_lifetime_board_pressed)
	_board_action_button.pressed.connect(_on_board_action_pressed)
	_show_more_button.pressed.connect(_on_show_more_pressed)

	var spring_buttons: Array[Button] = [
		_daily_button,
		_learning_button,
		_today_stat_card,
		_lifetime_stat_card,
		_board_action_button,
		_show_more_button,
	]
	for btn: Button in spring_buttons:
		_wire_spring(btn)

	for tab: Button in [_daily_board_button, _lifetime_button]:
		_wire_press_only_spring(tab)


func _attach_gloss_accents() -> void:
	GlossSheenScript.attach(_daily_button, COLOR_BLUE, 30.0)
	GlossSheenScript.attach(_learning_button, COLOR_PURPLE, 26.0)


func _wire_spring(btn: Button) -> void:
	btn.pivot_offset = btn.size / 2.0
	btn.resized.connect(_on_btn_resized.bind(btn))
	btn.mouse_entered.connect(_on_btn_hover.bind(btn, true))
	btn.mouse_exited.connect(_on_btn_hover.bind(btn, false))
	btn.button_down.connect(_animate_btn_scale.bind(btn, Vector2(0.96, 0.96), 0.07, Tween.TRANS_QUAD))
	btn.button_up.connect(_on_btn_released.bind(btn))


func _wire_press_only_spring(btn: Button) -> void:
	btn.pivot_offset = btn.size / 2.0
	btn.resized.connect(_on_btn_resized.bind(btn))
	btn.button_down.connect(_animate_btn_scale.bind(btn, Vector2(0.97, 0.97), 0.07, Tween.TRANS_QUAD))
	btn.button_up.connect(_animate_btn_scale.bind(btn, Vector2.ONE, 0.18, Tween.TRANS_BACK))


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
# NAVIGATION
############################################################
func _on_daily_pressed() -> void:
	_navigate_forward(DAILY_SCENE)


func _on_learning_pressed() -> void:
	_navigate_forward(LEARNING_SCENE)


func _navigate_forward(scene_path: String) -> void:
	if _navigating:
		return
	_navigating = true
	Sfx.click()
	await get_tree().create_timer(0.08).timeout
	if not is_inside_tree():
		return
	TransitionManager.slide_change_scene(scene_path, TransitionManager.Slide.FORWARD)


func _on_back_pressed() -> void:
	_on_android_back_pressed()


func _on_android_back_pressed() -> void:
	if _navigating:
		return
	_navigating = true
	Sfx.click()
	TransitionManager.slide_change_scene(MAIN_MENU_SCENE, TransitionManager.Slide.BACK)


############################################################
# STAT BENTO & LEADERBOARD TABS
############################################################
func _on_stat_card_pressed(select_daily: bool) -> void:
	Sfx.click()
	if select_daily and not _daily_selected:
		_on_daily_board_pressed()
	elif not select_daily and _daily_selected:
		_on_lifetime_board_pressed()
	_scroll_to_leaderboard()


func _scroll_to_leaderboard() -> void:
	if _root_scroll == null or _leaderboard_card == null:
		return
	var target_y: int = maxi(0, int(_leaderboard_card.position.y - 20.0))
	if _scroll_tween != null and _scroll_tween.is_valid():
		_scroll_tween.kill()
	_scroll_tween = create_tween()
	_scroll_tween.set_trans(Tween.TRANS_CUBIC)
	_scroll_tween.set_ease(Tween.EASE_OUT)
	_scroll_tween.tween_property(_root_scroll, "scroll_vertical", target_y, 0.32)


func _on_daily_board_pressed() -> void:
	if _daily_selected:
		_update_tab_selection()
		return
	Sfx.click()
	_daily_selected = true
	_apply_panels_visibility()
	_update_tab_selection()
	_sync_active_board_chrome()
	_animate_board_switch(_daily_entries)


func _on_lifetime_board_pressed() -> void:
	if not _daily_selected:
		_update_tab_selection()
		return
	Sfx.click()
	_daily_selected = false
	_apply_panels_visibility()
	_update_tab_selection()
	_sync_active_board_chrome()
	_animate_board_switch(_lifetime_entries)


func _animate_board_switch(container: Control) -> void:
	container.modulate.a = 0.0
	var tw: Tween = container.create_tween()
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(container, "modulate:a", 1.0, 0.18)


func _apply_panels_visibility() -> void:
	_daily_entries.visible = _daily_selected
	_lifetime_entries.visible = not _daily_selected


func _update_tab_selection() -> void:
	_daily_board_button.button_pressed = _daily_selected
	_lifetime_button.button_pressed = not _daily_selected


func _sync_active_board_chrome() -> void:
	_status.text = _daily_status_text if _daily_selected else _lifetime_status_text
	_rank_pill_label.text = _daily_rank_badge if _daily_selected else _lifetime_rank_badge

	var action: BoardAction = _daily_action if _daily_selected else _lifetime_action
	match action:
		BoardAction.LOGIN:
			_board_action_button.text = "ورود به حساب کاربری"
			_board_action_button.visible = true
		BoardAction.RETRY:
			_board_action_button.text = "تلاش مجدد"
			_board_action_button.visible = true
		_:
			_board_action_button.visible = false

	var rows: Array = _daily_rows if _daily_selected else _lifetime_rows
	var expanded: bool = _daily_expanded if _daily_selected else _lifetime_expanded
	if rows.size() > COLLAPSED_LEADERBOARD_LIMIT:
		_show_more_button.visible = true
		if expanded:
			_show_more_button.text = "نمایش کمتر ▴"
		else:
			_show_more_button.text = "نمایش همه رتبه‌ها (%s) ▾" % MenuStyle.persian_digits(str(rows.size()))
	else:
		_show_more_button.visible = false


func _on_board_action_pressed() -> void:
	var action: BoardAction = _daily_action if _daily_selected else _lifetime_action
	if action == BoardAction.LOGIN:
		_navigate_forward(AUTH_SCENE)
	elif action == BoardAction.RETRY:
		Sfx.click()
		if _daily_selected:
			_load_daily_board()
		else:
			_load_lifetime_board()


func _on_show_more_pressed() -> void:
	Sfx.click()
	if _daily_selected:
		_daily_expanded = not _daily_expanded
		_render_entries(_daily_entries, _daily_rows, true, _daily_expanded)
	else:
		_lifetime_expanded = not _lifetime_expanded
		_render_entries(_lifetime_entries, _lifetime_rows, false, _lifetime_expanded)
	_sync_active_board_chrome()


############################################################
# LEADERBOARD DATA LOADING
############################################################
func _load_daily_board() -> void:
	_daily_request_id += 1
	_daily_rows = []
	_clear_children(_daily_entries)
	if not API.is_configured() or not API.is_logged_in():
		_daily_status_text = "برای مشاهده رتبه‌بندی امروز و ثبت امتیاز رسمی، وارد حساب کاربری شوید."
		_daily_rank_badge = "رقابت روزانه 🌐"
		_daily_action = BoardAction.LOGIN
		_today_stat_value.text = "مهمان"
		_today_stat_sub.text = "نیاز به ورود به حساب"
		_daily_badge_label.text = "امتیاز رسمی · ۳ بازی روزانه 🏆"
		_sync_active_board_chrome()
		return
	var request_id: int = _daily_request_id
	_daily_status_text = "در حال دریافت رتبه‌بندی امروز از سرور…"
	_daily_rank_badge = "در حال دریافت…"
	_daily_action = BoardAction.NONE
	_today_stat_value.text = "…"
	_today_stat_sub.text = "در حال دریافت"
	_sync_active_board_chrome()
	API.fetch_daily_leaderboard(50, 0, func(ok: bool, data: Dictionary) -> void: _on_daily_loaded(request_id, ok, data))


func _load_lifetime_board() -> void:
	_lifetime_request_id += 1
	_lifetime_rows = []
	_clear_children(_lifetime_entries)
	if not API.is_configured() or not API.is_logged_in():
		_lifetime_status_text = "برای مشاهده رتبه‌بندی کل بازیکنان، وارد حساب کاربری شوید."
		_lifetime_rank_badge = "رتبه کل 🌐"
		_lifetime_action = BoardAction.LOGIN
		_lifetime_stat_value.text = "مهمان"
		_lifetime_stat_sub.text = "نیاز به ورود به حساب"
		_sync_active_board_chrome()
		return
	var request_id: int = _lifetime_request_id
	_lifetime_status_text = "در حال دریافت رتبه‌بندی کل از سرور…"
	_lifetime_rank_badge = "در حال دریافت…"
	_lifetime_action = BoardAction.NONE
	_lifetime_stat_value.text = "…"
	_lifetime_stat_sub.text = "در حال دریافت"
	_sync_active_board_chrome()
	API.fetch_lifetime_leaderboard(50, 0, func(ok: bool, data: Dictionary) -> void: _on_lifetime_loaded(request_id, ok, data))


func _on_daily_loaded(request_id: int, ok: bool, data: Dictionary) -> void:
	if request_id != _daily_request_id:
		return
	if not ok:
		_daily_status_text = "اتصال به سرور برقرار نشد؛ اینترنت خود را بررسی کنید و دوباره تلاش کنید. 📡"
		_daily_rank_badge = "آفلاین 📡"
		_daily_action = BoardAction.RETRY
		_today_stat_value.text = "آفلاین"
		_today_stat_sub.text = "خطا در اتصال به سرور"
		_sync_active_board_chrome()
		return
	_daily_action = BoardAction.NONE
	var period: String = "امروز"
	if str(data.get("date", "")) != "":
		period = "امروز · %s" % MenuStyle.persian_digits(str(data.get("date", "")))
	var self_row: Variant = data.get("self", null)
	if self_row is Dictionary:
		var self_data: Dictionary = self_row
		var rank_fa: String = MenuStyle.persian_digits(str(self_data.get("rank", "—")))
		var score_fa: String = MenuStyle.persian_digits(str(self_data.get("score", 0)))
		_daily_status_text = "%s · رتبه شما: %s · امتیاز: %s" % [period, rank_fa, score_fa]
		_daily_rank_badge = "رتبه %s 🏆" % rank_fa
		_today_stat_value.text = "رتبه %s" % rank_fa
		_today_stat_sub.text = "%s امتیاز امروز" % score_fa
		_daily_badge_label.text = "امتیاز امروز: %s ⭐" % score_fa
	else:
		_daily_status_text = "%s\nامروز هنوز بازی نکرده‌ای! چالش روزانه را شروع کن و اسمت را ثبت کن 🔥" % period
		_daily_rank_badge = "چالش امروز 🔥"
		_today_stat_value.text = "۰ امتیاز"
		_today_stat_sub.text = "هنوز چالش امروز را بازی نکرده‌اید"
		_daily_badge_label.text = "امتیاز رسمی · ۳ بازی روزانه 🏆"
	_daily_rows = data.get("entries", [])
	_render_entries(_daily_entries, _daily_rows, true, _daily_expanded)
	_sync_active_board_chrome()


func _on_lifetime_loaded(request_id: int, ok: bool, data: Dictionary) -> void:
	if request_id != _lifetime_request_id:
		return
	if not ok:
		_lifetime_status_text = "اتصال به سرور برقرار نشد؛ اینترنت خود را بررسی کنید و دوباره تلاش کنید. 📡"
		_lifetime_rank_badge = "آفلاین 📡"
		_lifetime_action = BoardAction.RETRY
		_lifetime_stat_value.text = "آفلاین"
		_lifetime_stat_sub.text = "خطا در اتصال به سرور"
		_sync_active_board_chrome()
		return
	_lifetime_action = BoardAction.NONE
	var self_row: Variant = data.get("self", null)
	if self_row is Dictionary:
		var self_data: Dictionary = self_row
		var rank_fa: String = MenuStyle.persian_digits(str(self_data.get("rank", "—")))
		var score_fa: String = MenuStyle.persian_digits(str(self_data.get("score", 0)))
		_lifetime_status_text = "مجموع امتیازهای ثبت‌شده · رتبه شما: %s · امتیاز: %s" % [rank_fa, score_fa]
		_lifetime_rank_badge = "رتبه %s 🏆" % rank_fa
		_lifetime_stat_value.text = "رتبه %s" % rank_fa
		_lifetime_stat_sub.text = "%s امتیاز کل" % score_fa
	else:
		_lifetime_status_text = "هنوز امتیازی ثبت نکرده‌ای! از چالش امروز شروع کن و به بالای جدول برس 🚀"
		_lifetime_rank_badge = "برترین‌ها 🏆"
		_lifetime_stat_value.text = "۰ امتیاز"
		_lifetime_stat_sub.text = "هنوز امتیاز رسمی ثبت نشده"
	_lifetime_rows = data.get("entries", [])
	_render_entries(_lifetime_entries, _lifetime_rows, false, _lifetime_expanded)
	_sync_active_board_chrome()


func _render_entries(box: VBoxContainer, rows: Array, is_daily: bool, expanded: bool) -> void:
	_clear_children(box)
	if rows.is_empty():
		var empty := Label.new()
		empty.text = "هنوز کسی امروز امتیاز نگرفته؛ اولین نفر باش! 🏆" if is_daily else "هنوز کسی امتیازی ثبت نکرده؛ اولین نفر باش! 🏆"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		empty.add_theme_font_override("font", MenuStyle.vazir())
		empty.add_theme_font_size_override("font_size", 28)
		empty.add_theme_color_override("font_color", MenuStyle.text_dim())
		box.add_child(empty)
		return

	var limit: int = rows.size() if expanded else mini(rows.size(), COLLAPSED_LEADERBOARD_LIMIT)
	var self_shown: bool = false

	for i: int in range(limit):
		var raw: Variant = rows[i]
		if not raw is Dictionary:
			continue
		var entry: Dictionary = raw
		if bool(entry.get("isSelf", false)):
			self_shown = true
		box.add_child(_build_leaderboard_row(entry))

	if not expanded and not self_shown:
		for raw: Variant in rows:
			if not raw is Dictionary:
				continue
			var entry: Dictionary = raw
			if bool(entry.get("isSelf", false)):
				var sep := HSeparator.new()
				sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
				box.add_child(sep)
				box.add_child(_build_leaderboard_row(entry))
				break


func _build_leaderboard_row(entry: Dictionary) -> PanelContainer:
	var highlighted: bool = bool(entry.get("isSelf", false))
	var rank_int: int = int(entry.get("rank", 0))

	var panel := PanelContainer.new()
	panel.name = "SelfRow" if highlighted else "Row"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _leaderboard_row_style(highlighted, rank_int))

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(row)

	# Score pill on the left
	var score_pill := PanelContainer.new()
	score_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	score_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	score_pill.add_theme_stylebox_override("panel", _score_pill_style(highlighted))
	var score_lbl := Label.new()
	score_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	score_lbl.text = "%s امتیاز" % MenuStyle.persian_digits(str(entry.get("score", 0)))
	score_lbl.add_theme_font_override("font", MenuStyle.vazir_bold())
	score_lbl.add_theme_font_size_override("font_size", 25)
	score_lbl.add_theme_color_override("font_color", COLOR_GOLD if highlighted else COLOR_BLUE)
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	score_pill.add_child(score_lbl)
	row.add_child(score_pill)

	# Player name in the middle
	var name_lbl := Label.new()
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.text = str(entry.get("name", "بازیکن"))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.add_theme_font_override("font", MenuStyle.vazir_bold() if highlighted else MenuStyle.vazir())
	name_lbl.add_theme_font_size_override("font_size", 29)
	name_lbl.add_theme_color_override("font_color", MenuStyle.ink())
	row.add_child(name_lbl)

	# Rank badge on the right (RTL start)
	var rank_chip := PanelContainer.new()
	rank_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rank_chip.custom_minimum_size = Vector2(72, 56)
	rank_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rank_chip.add_theme_stylebox_override("panel", _rank_badge_style(rank_int, highlighted))
	var rank_lbl := Label.new()
	rank_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rank_lbl.text = _rank_display(rank_int)
	rank_lbl.add_theme_font_override("font", MenuStyle.vazir_bold())
	rank_lbl.add_theme_font_size_override("font_size", 28 if rank_int <= 3 else 26)
	rank_lbl.add_theme_color_override("font_color", _rank_text_color(rank_int, highlighted))
	rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rank_chip.add_child(rank_lbl)
	row.add_child(rank_chip)

	return panel


func _rank_display(rank_int: int) -> String:
	match rank_int:
		1:
			return "🥇"
		2:
			return "🥈"
		3:
			return "🥉"
		_:
			return MenuStyle.persian_digits(str(rank_int)) if rank_int > 0 else "—"


func _rank_text_color(rank_int: int, highlighted: bool) -> Color:
	if highlighted:
		return COLOR_GOLD
	if rank_int <= 3 and rank_int > 0:
		return MenuStyle.ink()
	return MenuStyle.text_dim()


func _leaderboard_row_style(highlighted: bool, rank_int: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.set_corner_radius_all(18)
	s.content_margin_left = 18.0
	s.content_margin_right = 18.0
	s.content_margin_top = 12.0
	s.content_margin_bottom = 12.0
	s.set_border_width_all(2 if highlighted else 1)
	if highlighted:
		s.bg_color = Color("#F8EED3")
		s.border_color = Color(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b, 0.55)
	elif rank_int == 1:
		s.bg_color = Color("#FFFBF0")
		s.border_color = Color(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b, 0.30)
	else:
		s.bg_color = Color("#FAF7F0")
		s.border_color = Color(0.235, 0.196, 0.118, 0.10)
	return s


func _rank_badge_style(rank_int: int, highlighted: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.set_corner_radius_all(14)
	s.set_border_width_all(1)
	if rank_int == 1:
		s.bg_color = Color(0.95, 0.77, 0.22, 0.20)
		s.border_color = Color(0.85, 0.64, 0.12, 0.45)
	elif rank_int == 2:
		s.bg_color = Color(0.65, 0.70, 0.78, 0.22)
		s.border_color = Color(0.55, 0.60, 0.68, 0.40)
	elif rank_int == 3:
		s.bg_color = Color(0.80, 0.52, 0.30, 0.20)
		s.border_color = Color(0.75, 0.45, 0.22, 0.40)
	elif highlighted:
		s.bg_color = Color(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b, 0.16)
		s.border_color = Color(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b, 0.40)
	else:
		s.bg_color = Color(0.235, 0.196, 0.118, 0.06)
		s.border_color = Color(0.235, 0.196, 0.118, 0.12)
	return s


func _score_pill_style(highlighted: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.set_corner_radius_all(999)
	s.content_margin_left = 16.0
	s.content_margin_right = 16.0
	s.content_margin_top = 6.0
	s.content_margin_bottom = 6.0
	s.set_border_width_all(1)
	var col: Color = COLOR_GOLD if highlighted else COLOR_BLUE
	s.bg_color = Color(col.r, col.g, col.b, 0.12)
	s.border_color = Color(col.r, col.g, col.b, 0.32)
	return s


func _clear_children(container: Node) -> void:
	var children: Array[Node] = container.get_children()
	for child: Node in children:
		container.remove_child(child)
		child.queue_free()


############################################################
# MOTION POLISH
############################################################
func _play_intro_animation() -> void:
	var targets: Array[Control] = []
	for child: Node in _main_col.get_children():
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
	if _daily_icon_chip == null:
		return
	_daily_icon_chip.pivot_offset = _daily_icon_chip.size / 2.0
	if _ambient_tween != null and _ambient_tween.is_valid():
		_ambient_tween.kill()
	_ambient_tween = create_tween().set_loops()
	_ambient_tween.tween_property(_daily_icon_chip, "scale", Vector2(1.05, 1.05), 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_ambient_tween.tween_property(_daily_icon_chip, "scale", Vector2.ONE, 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
