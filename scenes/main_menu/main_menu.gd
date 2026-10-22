extends "res://autoload/BackButtonHandler.gd"

############################################################
# MAIN MENU — Continue + Leaderboards (Godot 4.7)
# One big scene-tree Continue button + two leaderboard panels
# (daily / lifetime) switched by two horizontal tab buttons.
############################################################

const COLOR_CONTINUE := Color("#3B82F6")

var _navigating: bool = false
var _back_message_nodes: Array[Node] = []
var _daily_selected: bool = true
var _daily_request_id: int = 0
var _lifetime_request_id: int = 0

@onready var _main_col: VBoxContainer = $RootScroll/OuterMargin/MainColumn
@onready var _continue_button: Button = $RootScroll/OuterMargin/MainColumn/ContinueSlot/ContinueButton
@onready var _continue_sub: Label = $RootScroll/OuterMargin/MainColumn/ContinueSlot/ContinueButton/Margin/Row/TextColumn/SubLabel
@onready var _continue_title: Label = $RootScroll/OuterMargin/MainColumn/ContinueSlot/ContinueButton/Margin/Row/TextColumn/TitleLabel
@onready var _brand_mark: TextureRect = $RootScroll/OuterMargin/MainColumn/HeroVBox/BrandMark
@onready var _daily_tab: Button = $RootScroll/OuterMargin/MainColumn/BoardTabs/DailyBoardButton
@onready var _lifetime_tab: Button = $RootScroll/OuterMargin/MainColumn/BoardTabs/LifetimeBoardButton
@onready var _daily_panel: PanelContainer = $RootScroll/OuterMargin/MainColumn/LeaderboardPanelSlot/DailyPanel
@onready var _lifetime_panel: PanelContainer = $RootScroll/OuterMargin/MainColumn/LeaderboardPanelSlot/LifetimePanel
@onready var _daily_status: Label = $RootScroll/OuterMargin/MainColumn/LeaderboardPanelSlot/DailyPanel/DailyMargin/DailyVBox/DailyStatus
@onready var _daily_entries: VBoxContainer = $RootScroll/OuterMargin/MainColumn/LeaderboardPanelSlot/DailyPanel/DailyMargin/DailyVBox/DailyEntries
@onready var _lifetime_status: Label = $RootScroll/OuterMargin/MainColumn/LeaderboardPanelSlot/LifetimePanel/LifetimeMargin/LifetimeVBox/LifetimeStatus
@onready var _lifetime_entries: VBoxContainer = $RootScroll/OuterMargin/MainColumn/LeaderboardPanelSlot/LifetimePanel/LifetimeMargin/LifetimeVBox/LifetimeEntries


############################################################
# READY
############################################################
func _ready() -> void:
	super._ready()
	_setup_continue_button()
	_daily_tab.pressed.connect(_on_daily_tab_pressed)
	_lifetime_tab.pressed.connect(_on_lifetime_tab_pressed)
	Global.on_theme_changed(_on_theme_changed)
	_apply_panels_visibility()
	_update_tab_selection()
	_load_daily_board()
	_load_lifetime_board()
	if not Global.intro_animation_played:
		Global.intro_animation_played = true
		_play_intro_animation()
	else:
		_start_ambient()


############################################################
# CONTINUE BUTTON (scene-tree node, wired here)
############################################################

func _setup_continue_button() -> void:
	if _continue_button.pressed.is_connected(_on_continue_pressed):
		_continue_button.pressed.disconnect(_on_continue_pressed)
	_continue_button.pressed.connect(_on_continue_pressed)
	_refresh_continue_state()


func _refresh_continue_state() -> void:
	var last: String = Global.get_last_scene()
	if last.is_empty() or not ResourceLoader.exists(last):
		_continue_button.disabled = true
		_continue_sub.text = "هنوز چیزی را شروع نکرده‌ای؛ یک بازی روزانه انجام بده تا اینجا ادامه‌اش بدهی! 🌱"
		_continue_button.tooltip_text = "اول یک بخش را باز کن تا ادامه‌اش اینجا باشد"
	else:
		_continue_button.disabled = false
		_continue_sub.text = _continue_destination_label(last)
		_continue_button.tooltip_text = "بازگشت به آخرین بخشی که باز کرده‌اید"


func _continue_destination_label(scene_path: String) -> String:
	var scene_names: Dictionary = {
		"res://scenes/lesson_menu/LessonMenu.tscn": "بازگشت به فهرست درس‌ها",
		"res://scenes/grammar/GrammarHub.tscn": "بازگشت به دستور زبان",
		"res://scenes/grammar/GrammarUnits.tscn": "ادامه تمرین دستور زبان",
		"res://scenes/grammar/GrammarLesson.tscn": "ادامه درس دستور زبان",
		"res://scenes/book_menu/BookSelection.tscn": "بازگشت به انتخاب کتاب",
		"res://scenes/word_game/WordGameHub.tscn": "ادامه بازی با کلمات",
		"res://scenes/word_game/DailyWordGame.tscn": "ادامه چالش روزانه",
	}
	return str(scene_names.get(scene_path, "بازگشت به آخرین بخش بازشده"))


func _on_continue_pressed() -> void:
	if _navigating:
		return
	var last: String = Global.get_last_scene()
	if last.is_empty() or not ResourceLoader.exists(last):
		Global.set_last_scene("")
		_continue_sub.text = "مسیری پیدا نشد؛ اول یک بازی روزانه انجام بده! 🎮"
		_refresh_continue_state()
		return
	_navigating = true
	_continue_button.disabled = true
	_continue_sub.text = "در حال باز کردن بخش شما…"
	await get_tree().create_timer(0.10).timeout
	if not is_inside_tree():
		return
	TransitionManager.slide_change_scene(last, TransitionManager.Slide.FORWARD)


############################################################
# LEADERBOARD TABS — switch panels (like WordGameHub)
############################################################
func _on_daily_tab_pressed() -> void:
	_daily_selected = true
	_apply_panels_visibility()
	_update_tab_selection()


func _on_lifetime_tab_pressed() -> void:
	_daily_selected = false
	_apply_panels_visibility()
	_update_tab_selection()


func _apply_panels_visibility() -> void:
	_daily_panel.visible = _daily_selected
	_lifetime_panel.visible = not _daily_selected


func _update_tab_selection() -> void:
	_daily_tab.button_pressed = _daily_selected
	_lifetime_tab.button_pressed = not _daily_selected


############################################################
# LEADERBOARD LOAD — daily + lifetime panels
############################################################
func _load_daily_board() -> void:
	_daily_request_id += 1
	for child: Node in _daily_entries.get_children():
		_daily_entries.remove_child(child)
		child.queue_free()
	if not API.is_configured() or not API.is_logged_in():
		_daily_status.text = "برای دیدن رتبه‌بندی امروز اینترنت و ورود لازم است.\nوصل شو و برگرد! 🌐"
		return
	var request_id: int = _daily_request_id
	_daily_status.text = "در حال دریافت رتبه‌بندی امروز از سرور…"
	API.fetch_daily_leaderboard(50, 0, func(ok: bool, data: Dictionary) -> void: _on_daily_loaded(request_id, ok, data))


func _load_lifetime_board() -> void:
	_lifetime_request_id += 1
	for child: Node in _lifetime_entries.get_children():
		_lifetime_entries.remove_child(child)
		child.queue_free()
	if not API.is_configured() or not API.is_logged_in():
		_lifetime_status.text = "برای دیدن رتبه‌بندی کل اینترنت و ورود لازم است.\nوصل شو و برگرد! 🌐"
		return
	var request_id: int = _lifetime_request_id
	_lifetime_status.text = "در حال دریافت رتبه‌بندی کل از سرور…"
	API.fetch_lifetime_leaderboard(50, 0, func(ok: bool, data: Dictionary) -> void: _on_lifetime_loaded(request_id, ok, data))


func _on_daily_loaded(request_id: int, ok: bool, data: Dictionary) -> void:
	if request_id != _daily_request_id:
		return
	if not ok:
		_daily_status.text = "اینترنت وصل نیست! اتصالت را بررسی کن و دوباره تلاش کن. 📡"
		return
	var period: String = "امروز"
	if str(data.get("date", "")) != "":
		period = "امروز · %s" % MenuStyle.persian_digits(str(data.get("date", "")))
	var self_row: Variant = data.get("self", null)
	if self_row is Dictionary:
		var self_data: Dictionary = self_row
		_daily_status.text = "%s\nرتبهٔ شما: %s · امتیاز: %s" % [period, MenuStyle.persian_digits(str(self_data.get("rank", "—"))), MenuStyle.persian_digits(str(self_data.get("score", 0)))]
	else:
		_daily_status.text = "%s\nامروز هنوز بازی نکرده‌ای! همین حالا چالش روزانه را بازی کن و اسمت را به جدول اضافه کن! 🔥🎮" % period
	_fill_entries(_daily_entries, data, true)


func _on_lifetime_loaded(request_id: int, ok: bool, data: Dictionary) -> void:
	if request_id != _lifetime_request_id:
		return
	if not ok:
		_lifetime_status.text = "اینترنت وصل نیست! اتصالت را بررسی کن و دوباره تلاش کن. 📡"
		return
	var self_row: Variant = data.get("self", null)
	if self_row is Dictionary:
		var self_data: Dictionary = self_row
		_lifetime_status.text = "مجموع امتیازهای ثبت‌شده\nرتبهٔ شما: %s · امتیاز: %s" % [MenuStyle.persian_digits(str(self_data.get("rank", "—"))), MenuStyle.persian_digits(str(self_data.get("score", 0)))]
	else:
		_lifetime_status.text = "هنوز هیچ بازی ثبت نکرده‌ای! از امروز شروع کن و کم‌کم به بالای جدول برس! 🚀📚"
	_fill_entries(_lifetime_entries, data, false)


func _fill_entries(box: VBoxContainer, data: Dictionary, is_daily: bool) -> void:
	var rows: Array = data.get("entries", [])
	if rows.is_empty():
		var empty := Label.new()
		empty.text = "هنوز کسی امروز امتیاز نگرفته؛ اولین نفر باش! 🏆" if is_daily else "هنوز کسی امتیازی ثبت نکرده؛ اولین نفر باش! 🏆"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty.add_theme_font_override("font", MenuStyle.vazir())
		empty.add_theme_font_size_override("font_size", 26)
		empty.add_theme_color_override("font_color", MenuStyle.text_dim())
		box.add_child(empty)
		return
	for raw: Variant in rows:
		if not raw is Dictionary:
			continue
		var entry: Dictionary = raw
		var highlighted: bool = bool(entry.get("isSelf", false))
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", MenuStyle.card_style(MenuStyle.accent() if highlighted else MenuStyle.border(), 18, highlighted, false))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		panel.add_child(row)
		row.add_child(_make_cell("#%s" % MenuStyle.persian_digits(str(entry.get("rank", "—"))), 24))
		row.add_child(_make_cell(str(entry.get("name", "بازیکن")), 23))
		var score := _make_cell(MenuStyle.persian_digits(str(entry.get("score", 0))), 25)
		score.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(score)
		box.add_child(panel)


func _make_cell(value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", MenuStyle.vazir())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", MenuStyle.text())
	return label


############################################################
# THEME + ANIMATION
############################################################
func _on_theme_changed(_mode: int) -> void:
	_apply_theme()


func _apply_theme() -> void:
	if not is_inside_tree():
		return
	_refresh_continue_state()


func _start_ambient() -> void:
	var tw: Tween = create_tween().set_loops()
	tw.tween_property(_brand_mark, "scale", Vector2(1.03, 1.03), 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_brand_mark, "scale", Vector2.ONE, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _play_intro_animation() -> void:
	var targets: Array[Control] = []
	for child in _main_col.get_children():
		if child is Control and not child.is_queued_for_deletion():
			targets.append(child)
	for t in targets:
		t.modulate.a = 0.0
		t.position += Vector2(0, 30)
	await get_tree().process_frame
	if not is_inside_tree():
		return
	for i in targets.size():
		var t: Control = targets[i]
		var tw := create_tween()
		tw.tween_interval(0.06 * i)
		tw.tween_property(t, "modulate:a", 1.0, 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(t, "position:y", t.position.y - 30.0, 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.06 * targets.size() + 0.4).timeout
	if not is_inside_tree():
		return
	_start_ambient()


############################################################
# ANDROID BACK (double-tap to exit)
############################################################
func _on_android_back_pressed() -> void:
	var current_time := Time.get_unix_time_from_system()
	if back_pressed_time > 0 and current_time - back_pressed_time < double_back_timeout:
		get_tree().quit()
	else:
		back_pressed_time = current_time
		_show_back_message()


func _show_back_message() -> void:
	if not _back_message_nodes.is_empty():
		return
	var message := Label.new()
	message.text = "برای خروج دوباره دکمه برگشت را بزنید"
	message.add_theme_font_override("font", MenuStyle.vazir())
	message.add_theme_font_size_override("font_size", 38)
	message.add_theme_color_override("font_color", Color.WHITE)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.anchor_left = 0.0
	message.anchor_top = 0.0
	message.anchor_right = 1.0
	message.anchor_bottom = 1.0
	message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(message)
	var bg := ColorRect.new()
	bg.color = MenuStyle.c("overlay")
	bg.anchor_left = 0.0
	bg.anchor_top = 0.0
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	move_child(bg, 0)
	_back_message_nodes = [bg, message]
	await get_tree().create_timer(1.5).timeout
	if not is_inside_tree():
		return
	var tw := create_tween()
	tw.parallel().tween_property(bg, "modulate:a", 0.0, 0.3)
	tw.parallel().tween_property(message, "modulate:a", 0.0, 0.3)
	await tw.finished
	if not is_inside_tree():
		return
	bg.queue_free()
	message.queue_free()
	_back_message_nodes.clear()
