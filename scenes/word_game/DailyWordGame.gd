extends "res://autoload/BackButtonHandler.gd"
class_name DailyWordGame

## Redesigned modern Daily Challenges scene for Vision Master.
## Displays an interactive Persian (Jalali) calendar strip, user connection status,
## multi-stat bento cards (day score, lifetime score, streak, progress), and
## three rich game cards (Wordle, Wordef, Unscramble) with spring micro-interactions.

const DailyChallengeStateStore = preload("res://autoload/DailyChallengeState.gd")
const DailyChallengeMockHelper = preload("res://scenes/word_game/daily_challenge_mock.gd")

const HUB_SCENE: String = "res://scenes/word_game/WordGameHub.tscn"
const LEADERBOARD_SCENE: String = "res://scenes/word_game/ChallengeLeaderboard.tscn"
const AUTH_SCENE: String = "res://scenes/auth/Auth.tscn"

const GAME_TYPES: Array[String] = ["wordle", "wordef", "unscramble"]
const GAME_SCENES: Dictionary = {
	"wordle": "res://scenes/word_game/WordOfDay.tscn",
	"wordef": "res://scenes/word_game/MeaningGame.tscn",
	"unscramble": "res://scenes/word_game/SpellingGame.tscn"
}

const GAME_INFO: Dictionary = {
	"wordle": {
		"title": "وردل انگلیسی (Wordle)",
		"desc": "حدس واژه ۵ حرفی روز در ۶ تلاش هوشمندانه با راهنمای رنگ‌ها",
		"icon": "🟩",
		"points": "۱۰۰ امتیاز",
		"color": Color(0.18, 0.65, 0.42, 1.0)
	},
	"wordef": {
		"title": "وردف واژگان (Wordef)",
		"desc": "آزمون چهارگزینه‌ای معنا، مترادف و متضاد کلمات در ۹۰ ثانیه",
		"icon": "📖",
		"points": "۱۰۰ امتیاز",
		"color": Color(0.38, 0.35, 0.85, 1.0)
	},
	"unscramble": {
		"title": "مرتب‌سازی حروف (Unscramble)",
		"desc": "مرتب کردن ۵ واژه انگلیسی به‌هم‌ریخته با راهنماهای معنایی",
		"icon": "🔤",
		"points": "۱۰۰ امتیاز",
		"color": Color(0.15, 0.58, 0.78, 1.0)
	}
}

# UI Nodes
var _root: VBoxContainer
var _user_badge_label: Label
var _month_title: Label
var _month_caption: Label
var _scroll: ScrollContainer
var _day_strip: HBoxContainer

# Bento stats nodes
var _day_score_label: Label
var _lifetime_score_label: Label
var _streak_label: Label
var _progress_bar: ProgressBar
var _progress_label: Label

# Game card nodes
var _game_cards: Dictionary = {}
var _game_buttons: Dictionary = {}
var _game_status_pills: Dictionary = {}

# Offline / Auth banner
var _offline_box: PanelContainer
var _offline_label: Label

var _calendar_data: Dictionary = {}
var _selected_date: String = ""
var _summary: Dictionary = {}
var _busy: bool = false
var _summary_request_date: String = ""
var _summary_refresh_generation: int = 0
var _persian_days: Array[String] = ["شنبه", "۱شنبه", "۲شنبه", "۳شنبه", "۴شنبه", "۵شنبه", "جمعه"]

var _day_cards: Dictionary = {}
var _scroll_tween: Tween = null

func _ready() -> void:
	DailyChallengeStateStore.return_scene = scene_file_path
	_build_ui()
	_load_calendar()

func _build_ui() -> void:
	# 1. Background
	var bg: ColorRect = ColorRect.new()
	bg.color = MenuStyle.c("bg")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# 2. Main Page Scroll
	var scroll_page: ScrollContainer = ScrollContainer.new()
	scroll_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll_page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_page.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(scroll_page)

	var margin: MarginContainer = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 270)
	margin.add_theme_constant_override("margin_bottom", 320)
	scroll_page.add_child(margin)

	_root = VBoxContainer.new()
	_root.add_theme_constant_override("separation", 28)
	_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(_root)

	# 3. Connection & User Status Header Banner (RTL & Right-Aligned)
	_build_user_banner()

	# 4. Offline / Login Card (Hidden when online)
	_build_offline_banner()

	# 5. Month Title (Centered) & Jalali Ribbon
	_build_calendar_section()

	# 6. Bento Stats Card (Scores, Streak, Progress)
	_build_bento_stats()

	# 7. Games Section (Wordle, Wordef, Unscramble Cards)
	_build_games_section()

	# 8. Leaderboard & Tips Footer
	_build_footer_section()

	_wire_header()

func _build_user_banner() -> void:
	var user_panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = MenuStyle.card_style(MenuStyle.border(), 22, false, false)
	style.bg_color = MenuStyle.surface().darkened(0.04) if MenuStyle.is_dark() else MenuStyle.surface().lightened(0.3)
	user_panel.add_theme_stylebox_override("panel", style)

	var pad: MarginContainer = MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 24)
	pad.add_theme_constant_override("margin_right", 24)
	pad.add_theme_constant_override("margin_top", 18)
	pad.add_theme_constant_override("margin_bottom", 18)
	user_panel.add_child(pad)

	var row: HBoxContainer = HBoxContainer.new()
	row.layout_direction = Control.LAYOUT_DIRECTION_LTR
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_child(row)

	var server_time_lbl: Label = _make_label("ساعت رسمی تهران 🇮🇷", 25, false)
	server_time_lbl.add_theme_color_override("font_color", MenuStyle.text_dim())
	server_time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(server_time_lbl)

	# Persian status label: always right-aligned at the right edge
	_user_badge_label = _make_label("در حال بررسی وضعیت اتصال…", 30, false)
	_user_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_user_badge_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_user_badge_label)

	_root.add_child(user_panel)

func _build_offline_banner() -> void:
	_offline_box = PanelContainer.new()
	var off_style: StyleBoxFlat = MenuStyle.card_style(Color(0.85, 0.45, 0.2, 0.8), 24, false, false)
	off_style.bg_color = Color(0.98, 0.94, 0.90, 1.0) if not MenuStyle.is_dark() else Color(0.24, 0.16, 0.12, 1.0)
	_offline_box.add_theme_stylebox_override("panel", off_style)

	var pad: MarginContainer = MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 28)
	pad.add_theme_constant_override("margin_right", 28)
	pad.add_theme_constant_override("margin_top", 22)
	pad.add_theme_constant_override("margin_bottom", 22)
	_offline_box.add_child(pad)

	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	pad.add_child(col)

	var title_lbl: Label = _make_label("🔒 ورود به حساب کاربری لازم است", 36, true)
	title_lbl.add_theme_color_override("font_color", Color(0.85, 0.35, 0.15, 1.0))
	col.add_child(title_lbl)

	_offline_label = _make_label(
		"برای ثبت امتیاز رسمی در جدول رتبه‌بندی جهانی، اتصال اینترنت و حساب کاربری نیاز است. می‌توانید وارد حساب خود شوید یا از حالت آزمایشی (دمو) استفاده نمایید.",
		28, false
	)
	_offline_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_offline_label)

	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.layout_direction = Control.LAYOUT_DIRECTION_RTL
	btn_row.add_theme_constant_override("separation", 18)
	col.add_child(btn_row)

	var login_btn: Button = MenuStyle.make_button("ورود به حساب کاربری", "primary", 104)
	login_btn.add_theme_font_size_override("font_size", 32)
	login_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	login_btn.pressed.connect(_on_login_clicked)
	btn_row.add_child(login_btn)

	var demo_btn: Button = MenuStyle.make_button("پیش‌نمایش آزمایشی (دمو)", "secondary", 104)
	demo_btn.add_theme_font_size_override("font_size", 32)
	demo_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	demo_btn.pressed.connect(_on_enable_demo_clicked)
	btn_row.add_child(demo_btn)

	_root.add_child(_offline_box)
	_offline_box.visible = false

func _build_calendar_section() -> void:
	var cal_header: VBoxContainer = VBoxContainer.new()
	cal_header.add_theme_constant_override("separation", 8)
	cal_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root.add_child(cal_header)

	# Persian Month Title: Center aligned on the screen
	_month_title = _make_label("در حال دریافت تقویم…", 46, true)
	_month_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_month_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cal_header.add_child(_month_title)

	_month_caption = _make_label("تقویم چالش‌های رسمی روزانه", 28, false)
	_month_caption.add_theme_color_override("font_color", MenuStyle.text_dim())
	_month_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_month_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cal_header.add_child(_month_caption)

	# Scroll Container for Days Ribbon: ample height so larger cards can lift up without clipping
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size.y = 304
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_root.add_child(_scroll)

	var day_strip_margin: MarginContainer = MarginContainer.new()
	day_strip_margin.add_theme_constant_override("margin_top", 28)
	day_strip_margin.add_theme_constant_override("margin_bottom", 24)
	day_strip_margin.add_theme_constant_override("margin_left", 20)
	day_strip_margin.add_theme_constant_override("margin_right", 20)
	day_strip_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.add_child(day_strip_margin)

	_day_strip = HBoxContainer.new()
	_day_strip.add_theme_constant_override("separation", 20)
	_day_strip.layout_direction = Control.LAYOUT_DIRECTION_RTL
	_day_strip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	day_strip_margin.add_child(_day_strip)

func _build_bento_stats() -> void:
	var bento_box: PanelContainer = PanelContainer.new()
	var bento_style: StyleBoxFlat = MenuStyle.card_style(MenuStyle.border(), 26, false, true)
	bento_box.add_theme_stylebox_override("panel", bento_style)

	var pad: MarginContainer = MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 28)
	pad.add_theme_constant_override("margin_right", 28)
	pad.add_theme_constant_override("margin_top", 24)
	pad.add_theme_constant_override("margin_bottom", 24)
	bento_box.add_child(pad)

	var main_col: VBoxContainer = VBoxContainer.new()
	main_col.add_theme_constant_override("separation", 20)
	pad.add_child(main_col)

	# Row with 3 stats
	var stats_row: HBoxContainer = HBoxContainer.new()
	stats_row.layout_direction = Control.LAYOUT_DIRECTION_RTL
	stats_row.add_theme_constant_override("separation", 18)
	stats_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_col.add_child(stats_row)

	# 1. Day score
	var day_cell: VBoxContainer = _create_stat_cell("⭐ امتیاز این روز", "۰", Color(0.95, 0.72, 0.15, 1.0))
	_day_score_label = day_cell.get_node("Value") as Label
	stats_row.add_child(day_cell)

	# 2. Lifetime score
	var lifetime_cell: VBoxContainer = _create_stat_cell("🏆 امتیاز کل حساب", "۰", MenuStyle.accent())
	_lifetime_score_label = lifetime_cell.get_node("Value") as Label
	stats_row.add_child(lifetime_cell)

	# 3. Streak
	var streak_cell: VBoxContainer = _create_stat_cell("🔥 روزهای متوالی", "۰ روز", Color(0.95, 0.42, 0.22, 1.0))
	_streak_label = streak_cell.get_node("Value") as Label
	stats_row.add_child(streak_cell)

	# Progress section
	var progress_col: VBoxContainer = VBoxContainer.new()
	progress_col.add_theme_constant_override("separation", 10)
	main_col.add_child(progress_col)

	var prog_header: HBoxContainer = HBoxContainer.new()
	prog_header.layout_direction = Control.LAYOUT_DIRECTION_RTL
	progress_col.add_child(prog_header)

	var prog_title: Label = _make_label("پیشرفت چالش‌های روز:", 28, true)
	prog_header.add_child(prog_title)

	_progress_label = _make_label("۰ از ۳ بازی تکمیل شده", 26, false)
	_progress_label.add_theme_color_override("font_color", MenuStyle.text_dim())
	prog_header.add_child(_progress_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size.y = 22
	_progress_bar.max_value = 3.0
	_progress_bar.step = 1.0
	_progress_bar.value = 0.0
	_progress_bar.show_percentage = false
	progress_col.add_child(_progress_bar)

	_root.add_child(bento_box)

func _create_stat_cell(title: String, initial_val: String, color: Color) -> VBoxContainer:
	var col: VBoxContainer = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)

	var t_label: Label = _make_label(title, 26, false)
	t_label.add_theme_color_override("font_color", MenuStyle.text_dim())
	t_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t_label)

	var v_label: Label = _make_label(initial_val, 38, true)
	v_label.name = "Value"
	v_label.add_theme_color_override("font_color", color)
	v_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(v_label)

	return col

func _build_games_section() -> void:
	var header_col: VBoxContainer = VBoxContainer.new()
	header_col.add_theme_constant_override("separation", 6)
	header_col.layout_direction = Control.LAYOUT_DIRECTION_RTL
	_root.add_child(header_col)

	var title: Label = _make_label("بازی‌های روز انتخاب‌شده", 38, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header_col.add_child(title)

	var caption: Label = _make_label("هر بازی را در روز جاری فقط یک بار با امتیاز رقابتی می‌توانید ثبت کنید.", 27, false)
	caption.add_theme_color_override("font_color", MenuStyle.text_dim())
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header_col.add_child(caption)

	var games_col: VBoxContainer = VBoxContainer.new()
	games_col.add_theme_constant_override("separation", 20)
	_root.add_child(games_col)

	for game_type: String in GAME_TYPES:
		var card: PanelContainer = _build_single_game_card(game_type)
		games_col.add_child(card)
		_game_cards[game_type] = card

func _build_single_game_card(game_type: String) -> PanelContainer:
	var info: Dictionary = GAME_INFO.get(game_type, {})
	var card: PanelContainer = PanelContainer.new()
	var card_style: StyleBoxFlat = MenuStyle.card_style(MenuStyle.border(), 26, false, true)
	card.add_theme_stylebox_override("panel", card_style)

	var pad: MarginContainer = MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 24)
	pad.add_theme_constant_override("margin_right", 24)
	pad.add_theme_constant_override("margin_top", 22)
	pad.add_theme_constant_override("margin_bottom", 22)
	card.add_child(pad)

	var row: HBoxContainer = HBoxContainer.new()
	row.layout_direction = Control.LAYOUT_DIRECTION_RTL
	row.add_theme_constant_override("separation", 22)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_child(row)

	# Left/Action: Start / Continue / Finished button
	var action_box: VBoxContainer = VBoxContainer.new()
	action_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	action_box.custom_minimum_size.x = 260
	action_box.add_theme_constant_override("separation", 8)
	row.add_child(action_box)

	var button: Button = MenuStyle.make_button("شروع بازی ▶", "primary", 102)
	button.add_theme_font_size_override("font_size", 30)
	button.layout_direction = Control.LAYOUT_DIRECTION_RTL
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_on_game_pressed.bind(game_type))
	action_box.add_child(button)
	_game_buttons[game_type] = button
	MenuStyle.wire_microinteractions(button)

	var status_pill: Label = _make_label("آماده چالش", 24, false)
	status_pill.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_pill.add_theme_color_override("font_color", MenuStyle.text_dim())
	action_box.add_child(status_pill)
	_game_status_pills[game_type] = status_pill

	# Center: Game Title, description and score badge
	var text_col: VBoxContainer = VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_col.add_theme_constant_override("separation", 6)
	row.add_child(text_col)

	var title_lbl: Label = _make_label(str(info.get("title", "")), 34, true)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	text_col.add_child(title_lbl)

	var desc_lbl: Label = _make_label(str(info.get("desc", "")), 27, false)
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_color_override("font_color", MenuStyle.text_dim())
	text_col.add_child(desc_lbl)

	var points_lbl: Label = _make_label("⭐ جایزه: " + str(info.get("points", "")), 26, false)
	points_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	points_lbl.add_theme_color_override("font_color", Color(0.95, 0.72, 0.15, 1.0))
	text_col.add_child(points_lbl)

	# Right: Visual Badge / Icon
	var icon_box: PanelContainer = PanelContainer.new()
	icon_box.custom_minimum_size = Vector2(114, 114)
	var icon_style: StyleBoxFlat = StyleBoxFlat.new()
	icon_style.set_corner_radius_all(22)
	icon_style.bg_color = Color(info.get("color", Color.GRAY), 0.18)
	icon_style.border_color = Color(info.get("color", Color.GRAY), 0.4)
	icon_style.set_border_width_all(2)
	icon_box.add_theme_stylebox_override("panel", icon_style)
	icon_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon_box)

	var icon_lbl: Label = _make_label(str(info.get("icon", "🎮")), 54, true)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_box.add_child(icon_lbl)

	return card

func _build_footer_section() -> void:
	var leader_btn: Button = MenuStyle.make_button("🏆 مشاهده جدول رتبه‌بندی برتر مسابقات", "secondary", 114)
	leader_btn.add_theme_font_size_override("font_size", 32)
	leader_btn.layout_direction = Control.LAYOUT_DIRECTION_RTL
	leader_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leader_btn.pressed.connect(_on_leaderboard_pressed)
	_root.add_child(leader_btn)
	MenuStyle.wire_microinteractions(leader_btn)

	var tips_box: PanelContainer = PanelContainer.new()
	var t_style: StyleBoxFlat = MenuStyle.card_style(MenuStyle.border(), 22, false, false)
	tips_box.add_theme_stylebox_override("panel", t_style)
	var t_pad: MarginContainer = MarginContainer.new()
	t_pad.add_theme_constant_override("margin_left", 24)
	t_pad.add_theme_constant_override("margin_right", 24)
	t_pad.add_theme_constant_override("margin_top", 18)
	t_pad.add_theme_constant_override("margin_bottom", 18)
	tips_box.add_child(t_pad)

	var t_lbl: Label = _make_label(
		"💡 نکته: بازی روزهای گذشته را می‌توانید برای تمرین و یادگیری مرور کنید، اما امتیاز رقابتی فقط متعلق به روز جاری است.",
		26, false
	)
	t_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	t_lbl.add_theme_color_override("font_color", MenuStyle.text_dim())
	t_pad.add_child(t_lbl)
	_root.add_child(tips_box)

func _wire_header() -> void:
	var header: Control = get_node_or_null("HeaderBar") as Control
	if header == null:
		return
	move_child(header, get_child_count() - 1)
	var back: Button = header.get_node_or_null("HeaderContent/BackButton") as Button
	if back != null and not back.pressed.is_connected(_go_back):
		back.pressed.connect(_go_back)
	var home: Button = header.get_node_or_null("HeaderContent/HomeButton") as Button
	if home != null and not home.pressed.is_connected(_go_back):
		home.pressed.connect(_go_back)

# ------------------------------------------------------------
# LOGIC & DATA LOADING
# ------------------------------------------------------------

func _load_calendar() -> void:
	var is_ready: bool = API.is_configured() and API.is_logged_in()
	if not is_ready:
		_show_offline_state()
		return
	
	_offline_box.visible = false
	var username: String = API.get_username()
	if username.is_empty():
		username = "کاربر گرامی"
	# Always right aligned RTL status label
	_user_badge_label.text = "🟢 متصل به سرور · کاربر: %s" % username
	_user_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_month_title.text = "در حال بارگذاری تقویم از سرور…"
	_month_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	API.fetch_challenge_calendar(_on_calendar_loaded)

func _show_offline_state() -> void:
	_offline_box.visible = true
	_user_badge_label.text = "🔴 حالت آفلاین / ورود نکرده"
	_user_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_month_title.text = "تقویم چالش‌های روزانه"
	_month_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_day_score_label.text = "—"
	_lifetime_score_label.text = "—"
	_streak_label.text = "—"
	_progress_label.text = "نیاز به ورود به حساب"
	for game_type: String in GAME_TYPES:
		var btn: Button = _game_buttons[game_type] as Button
		btn.disabled = true
		btn.text = "نیاز به اینترنت"
		var pill: Label = _game_status_pills[game_type] as Label
		pill.text = "غیرفعال"

func _on_enable_demo_clicked() -> void:
	DailyChallengeMockHelper.enable_mock()
	_load_calendar()

func _on_login_clicked() -> void:
	TransitionManager.change_scene(AUTH_SCENE)

func _on_calendar_loaded(ok: bool, data: Dictionary) -> void:
	if not ok:
		_show_offline_state()
		_offline_label.text = "ارتباط با سرور برقرار نشد. لطفاً اتصال اینترنت را بررسی فرمایید."
		return
	
	_calendar_data = data
	var today: String = str(data.get("today", ""))
	var persisted: String = DailyChallengeStateStore.load_selected_date()
	_selected_date = persisted if _date_is_in_calendar(persisted, data.get("days", [])) else today
	DailyChallengeStateStore.set_selected_date(_selected_date)
	
	var jalali: Dictionary = data.get("jalali", {})
	# Persian Month Title: Centered on screen
	_month_title.text = "🗓️ %s %s" % [
		JalaliCalendar.month_name(int(jalali.get("month", 1))),
		JalaliCalendar.persian_digits(str(jalali.get("year", "")))
	]
	_month_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	_build_day_cards(data.get("days", []))
	_load_summary()

func _date_is_in_calendar(date_key: String, days: Array) -> bool:
	for raw: Variant in days:
		if raw is Dictionary and str(raw.get("date", "")) == date_key and not bool(raw.get("future", false)):
			return true
	return false

func _build_day_cards(days: Array) -> void:
	_day_cards.clear()
	for child: Node in _day_strip.get_children():
		_day_strip.remove_child(child)
		child.queue_free()

	for index: int in range(days.size()):
		var item: Variant = days[index]
		if not item is Dictionary:
			continue
		var cell: Dictionary = item
		var date_key: String = str(cell.get("date", ""))
		var jalali: Dictionary = cell.get("jalali", {})
		var is_today: bool = bool(cell.get("today", false))
		var is_future: bool = bool(cell.get("future", false))
		var is_selected: bool = (date_key == _selected_date)

		var card_btn: Button = Button.new()
		card_btn.custom_minimum_size = Vector2(204, 240)
		card_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card_btn.disabled = is_future
		card_btn.set_meta("date", date_key)
		card_btn.focus_mode = Control.FOCUS_NONE
		
		# Center pivot for scale/lift animation
		card_btn.pivot_offset = Vector2(102, 120)
		card_btn.resized.connect(func() -> void:
			card_btn.pivot_offset = card_btn.size * 0.5
		)

		# Initial transform for selected vs unselected
		if is_selected:
			card_btn.scale = Vector2(1.10, 1.10)
			card_btn.position.y = -18.0
			card_btn.z_index = 2
		else:
			card_btn.scale = Vector2(1.0, 1.0)
			card_btn.position.y = 0.0
			card_btn.z_index = 0

		# Styles
		card_btn.add_theme_stylebox_override("normal", _create_day_style(is_selected, is_today, is_future))
		card_btn.add_theme_stylebox_override("disabled", _create_day_style(false, false, true))
		card_btn.add_theme_stylebox_override("hover", _create_day_style(is_selected, is_today, is_future))
		card_btn.add_theme_stylebox_override("pressed", _create_day_style(true, is_today, false))
		card_btn.add_theme_font_override("font", MenuStyle.vazir())
		card_btn.add_theme_font_size_override("font_size", 1)

		var box: VBoxContainer = VBoxContainer.new()
		box.name = "Box"
		box.set_anchors_preset(Control.PRESET_FULL_RECT)
		box.add_theme_constant_override("separation", 4)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_btn.add_child(box)

		# Weekday short name / Today indicator
		var top_tag: String = "امروز" if is_today else ("🔒 آینده" if is_future else _persian_days[index % 7])
		var top_lbl: Label = _make_label(top_tag, 25, is_today)
		top_lbl.name = "TopTag"
		if is_today:
			top_lbl.add_theme_color_override("font_color", Color(0.95, 0.72, 0.15, 1.0))
		elif is_future:
			top_lbl.add_theme_color_override("font_color", MenuStyle.text_dim())
		box.add_child(top_lbl)

		# Day number
		var day_num_lbl: Label = _make_label(JalaliCalendar.persian_digits(str(jalali.get("day", ""))), 52, true)
		day_num_lbl.name = "DayNum"
		if is_selected:
			day_num_lbl.add_theme_color_override("font_color", MenuStyle.accent())
		box.add_child(day_num_lbl)

		# Score / completion badge
		var score_val: int = int(cell.get("totalScore", 0))
		var completed_count: int = int(cell.get("completedGames", 0))
		var score_text: String = "—" if is_future else ("%s امتیاز" % JalaliCalendar.persian_digits(str(score_val)))
		var score_lbl: Label = _make_label(score_text, 24, false)
		score_lbl.name = "ScoreLabel"
		if score_val > 0:
			score_lbl.add_theme_color_override("font_color", Color(0.2, 0.75, 0.45, 1.0))
		box.add_child(score_lbl)

		var count_text: String = "🔒" if is_future else ("%s/۳ ✔" % JalaliCalendar.persian_digits(str(completed_count)) if completed_count == 3 else "%s/۳" % JalaliCalendar.persian_digits(str(completed_count)))
		var count_lbl: Label = _make_label(count_text, 23, completed_count == 3)
		count_lbl.name = "CountLabel"
		if completed_count == 3:
			count_lbl.add_theme_color_override("font_color", Color(0.2, 0.75, 0.45, 1.0))
		box.add_child(count_lbl)

		card_btn.pressed.connect(_select_date.bind(date_key))
		_day_strip.add_child(card_btn)
		_day_cards[date_key] = card_btn

	call_deferred("_center_selected_card")

func _create_day_style(is_selected: bool, is_today: bool, is_future: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.set_corner_radius_all(22)
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.content_margin_left = 8
	style.content_margin_right = 8

	if is_future:
		style.bg_color = MenuStyle.surface().darkened(0.12) if MenuStyle.is_dark() else Color(0.92, 0.92, 0.92, 1.0)
		style.border_color = Color(MenuStyle.border(), 0.3)
		style.set_border_width_all(1)
		return style

	if is_selected:
		style.bg_color = MenuStyle.accent().lightened(0.15) if MenuStyle.is_dark() else MenuStyle.surface()
		style.border_color = MenuStyle.accent()
		style.set_border_width_all(4)
		style.shadow_color = Color(MenuStyle.accent(), 0.45)
		style.shadow_size = 16
		style.shadow_offset = Vector2(0, 8)
	elif is_today:
		style.bg_color = MenuStyle.surface()
		style.border_color = Color(0.95, 0.72, 0.15, 0.85)
		style.set_border_width_all(3)
		style.shadow_color = Color(0.95, 0.72, 0.15, 0.25)
		style.shadow_size = 6
		style.shadow_offset = Vector2(0, 2)
	else:
		style.bg_color = MenuStyle.surface()
		style.border_color = Color(MenuStyle.border(), 0.5)
		style.set_border_width_all(2)
		style.shadow_color = Color(0, 0, 0, 0.05)
		style.shadow_size = 4
		style.shadow_offset = Vector2(0, 2)

	return style

func _center_selected_card() -> void:
	if _day_cards.has(_selected_date):
		var card: Control = _day_cards[_selected_date] as Control
		_smooth_scroll_to_card(card)

func _smooth_scroll_to_card(card: Control) -> void:
	if card == null or _scroll == null:
		return
	var card_center_x: float = card.position.x + card.size.x * 0.5
	var target: int = int(card_center_x - _scroll.size.x * 0.5)
	target = maxi(0, target)
	
	if _scroll_tween != null and _scroll_tween.is_valid():
		_scroll_tween.kill()
	
	_scroll_tween = create_tween()
	_scroll_tween.set_trans(Tween.TRANS_CUBIC)
	_scroll_tween.set_ease(Tween.EASE_OUT)
	_scroll_tween.tween_property(_scroll, "scroll_horizontal", target, 0.36)

func _select_date(date_key: String) -> void:
	if date_key == _selected_date:
		_animate_card_pop(_day_cards.get(date_key) as Button)
		return
	
	var old_date: String = _selected_date
	_selected_date = date_key
	DailyChallengeStateStore.set_selected_date(date_key)
	
	_animate_card_deselection(_day_cards.get(old_date) as Button, old_date)
	_animate_card_selection(_day_cards.get(date_key) as Button, date_key)
	
	var new_card: Control = _day_cards.get(date_key) as Control
	if new_card != null:
		_smooth_scroll_to_card(new_card)
		
	_summary.clear()
	_load_summary()

func _animate_card_selection(card: Button, date_key: String) -> void:
	if card == null:
		return
	var is_today: bool = _is_date_today(date_key)
	card.add_theme_stylebox_override("normal", _create_day_style(true, is_today, false))
	card.add_theme_stylebox_override("hover", _create_day_style(true, is_today, false))
	card.z_index = 2
	
	var day_num_lbl: Label = card.get_node_or_null("Box/DayNum") as Label
	if day_num_lbl != null:
		day_num_lbl.add_theme_color_override("font_color", MenuStyle.accent())
		
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", Vector2(1.10, 1.10), 0.30)
	tween.tween_property(card, "position:y", -18.0, 0.30)

func _animate_card_deselection(card: Button, date_key: String) -> void:
	if card == null:
		return
	var is_today: bool = _is_date_today(date_key)
	var is_future: bool = card.disabled
	card.add_theme_stylebox_override("normal", _create_day_style(false, is_today, is_future))
	card.add_theme_stylebox_override("hover", _create_day_style(false, is_today, is_future))
	card.z_index = 0
	
	var day_num_lbl: Label = card.get_node_or_null("Box/DayNum") as Label
	if day_num_lbl != null:
		day_num_lbl.remove_theme_color_override("font_color")
		
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", Vector2(1.0, 1.0), 0.22)
	tween.tween_property(card, "position:y", 0.0, 0.22)

func _animate_card_pop(card: Button) -> void:
	if card == null:
		return
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", Vector2(1.15, 1.15), 0.12)
	tween.tween_property(card, "scale", Vector2(1.10, 1.10), 0.18)

func _is_date_today(date_key: String) -> bool:
	for raw: Variant in _calendar_data.get("days", []):
		if raw is Dictionary and str(raw.get("date", "")) == date_key:
			return bool(raw.get("today", false))
	return false

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

func _on_summary_loaded(ok: bool, data: Dictionary) -> void:
	if _summary_request_date != _selected_date:
		return
	if not ok:
		return
	
	_summary = data
	var day_total: int = int(data.get("dayTotal", 0))
	var lifetime_total: int = int(data.get("lifetimeTotal", 0))
	var streak: int = int(data.get("streak", 5))

	_day_score_label.text = "%s امتیاز" % JalaliCalendar.persian_digits(str(day_total))
	_lifetime_score_label.text = "%s امتیاز" % JalaliCalendar.persian_digits(str(lifetime_total))
	_streak_label.text = "%s روز" % JalaliCalendar.persian_digits(str(streak))

	var games: Dictionary = data.get("games", {})
	var completed_games_count: int = 0
	var is_today: bool = _date_is_today()

	for game_type: String in GAME_TYPES:
		var game: Dictionary = games.get(game_type, {})
		var button: Button = _game_buttons[game_type] as Button
		var pill: Label = _game_status_pills[game_type] as Label
		
		var completed: bool = bool(game.get("completed", false))
		var in_progress: bool = bool(game.get("inProgress", false))

		if completed:
			completed_games_count += 1
			button.text = "✔ تکمیل شد"
			button.disabled = true
			pill.text = "ثبت شده (۱۰۰ امتیاز)"
			pill.add_theme_color_override("font_color", Color(0.2, 0.75, 0.45, 1.0))
		elif in_progress:
			button.text = "⚡ ادامه چالش"
			button.disabled = not is_today
			pill.text = "در حال انجام"
			pill.add_theme_color_override("font_color", Color(0.95, 0.65, 0.15, 1.0))
		else:
			button.text = "شروع بازی ▶"
			button.disabled = not is_today
			pill.text = "آماده چالش" if is_today else "روزهای گذشته (فقط مشاهده)"
			pill.add_theme_color_override("font_color", MenuStyle.text_dim())

	_progress_bar.value = float(completed_games_count)
	_progress_label.text = "%s از ۳ بازی تکمیل شده" % JalaliCalendar.persian_digits(str(completed_games_count))

func _date_is_today() -> bool:
	return _is_date_today(_selected_date)

func _on_game_pressed(game_type: String) -> void:
	if _busy or _summary.is_empty() or _selected_date.is_empty():
		return
	if not _date_is_today():
		return
	var game: Dictionary = _summary.get("games", {}).get(game_type, {})
	if bool(game.get("completed", false)):
		return
	
	DailyChallengeStateStore.return_scene = scene_file_path
	DailyChallengeStateStore.set_selected_date(_selected_date)
	DailyChallengeStateStore.selected_game = game_type
	
	_busy = true
	var existing_attempt: bool = bool(game.get("inProgress", false))
	var key: String = "%s:%s:%s" % [API.get_user_id(), _selected_date, game_type]
	if existing_attempt:
		key = ""
	
	API.start_challenge_attempt(_selected_date, game_type, key, func(ok: bool, data: Dictionary) -> void:
		_busy = false
		if ok:
			var attempt: Dictionary = data.get("attempt", {})
			var reserved_id: String = str(attempt.get("id", ""))
			DailyChallengeStateStore.begin_attempt(
				game_type,
				reserved_id,
				bool(attempt.get("counted", true)),
				data.get("publicContent", {}),
				str(attempt.get("startedAt", "")),
				attempt.get("state", {}),
				str(attempt.get("status", "in_progress"))
			)
		var dest_scene: String = GAME_SCENES.get(game_type, "")
		if dest_scene != "":
			TransitionManager.change_scene(dest_scene)
	)

func _on_leaderboard_pressed() -> void:
	TransitionManager.change_scene(LEADERBOARD_SCENE)

func _make_label(text_value: String, font_size: int, bold: bool) -> Label:
	var label: Label = Label.new()
	label.text = text_value
	label.layout_direction = Control.LAYOUT_DIRECTION_LTR
	label.text_direction = Control.TEXT_DIRECTION_RTL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", MenuStyle.vazir() if not bold else MenuStyle.vazir_bold())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", MenuStyle.text())
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _go_back() -> void:
	TransitionManager.change_scene(HUB_SCENE)

func _on_android_back_pressed() -> void:
	_go_back()
