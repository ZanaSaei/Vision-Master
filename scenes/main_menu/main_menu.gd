extends "res://autoload/BackButtonHandler.gd"

############################################################
# MAIN MENU — Modern Learning Dashboard (Godot 4.7)
# Header greeting + Hero Continue/Start CTA + Bento study stats +
# Quick access grid + Segmented Leaderboard + Study tip.
############################################################

const SCENE_MAIN_MENU := "res://scenes/main_menu/MainMenu.tscn"
const SCENE_BOOK_SELECTION := "res://scenes/book_menu/BookSelection.tscn"
const SCENE_WORD_REVIEW := "res://scenes/review/WordReview.tscn"
const SCENE_SAVED_WORDS := "res://scenes/saved_words/SavedWords.tscn"
const SCENE_FLASHCARDS := "res://scenes/vocabulary/VocabFlashcards.tscn"
const SCENE_FLASHCARD_HUB := "res://scenes/vocabulary/FlashcardHub.tscn"
const SCENE_DAILY_GAME := "res://scenes/word_game/DailyWordGame.tscn"
const SCENE_WORD_GAME_LEARNING := "res://scenes/word_game/WordGameLearning.tscn"
const SCENE_FINAL_EXAMS := "res://scenes/exam/FinalExams.tscn"
const SCENE_AUTH := "res://scenes/auth/Auth.tscn"

const GlossSheenScript := preload("res://ui/widgets/gloss_sheen.gd")

const COLOR_BLUE := Color("#2F6FD8")
const COLOR_GOLD := Color("#A87C24")
const COLOR_PURPLE := Color("#7C3AED")
const COLOR_EMERALD := Color("#2E8B57")

const COLLAPSED_LEADERBOARD_LIMIT := 8

const STUDY_TIPS: Array[String] = [
	"مرور روزانه ۵ تا ۱۰ کارت لایتنر، ماندگاری لغات را چند برابر می‌کند.",
	"قبل از خواندن متن هر درس، لغات جدید آن را با تلفظ صوتی مرور کن.",
	"چالش روزانه واژگان هم دایره لغاتت را قوی‌تر می‌کند و هم امتیاز رسمی می‌دهد.",
	"تمرین کوتاه اما پیوسته هر روز بهتر از مطالعه طولانی در یک شب است.",
	"بعد از هر درس گرامر، حتماً بخش «کتاب کار» و «آنچه آموختید» را حل کن.",
]

enum BoardAction { NONE, LOGIN, RETRY }

var _navigating: bool = false
var _back_message_nodes: Array[Node] = []
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

# Header references
@onready var _brand_mark: TextureRect = $HeaderBar/HeaderMargin/HeaderRow/BrandBox/BrandChip/BrandMark
@onready var _greeting_label: Label = $HeaderBar/HeaderMargin/HeaderRow/GreetingBox/GreetingLabel
@onready var _tier_label: Label = $HeaderBar/HeaderMargin/HeaderRow/GreetingBox/BadgeRow/TierPill/TierLabel
@onready var _grade_label: Label = $HeaderBar/HeaderMargin/HeaderRow/GreetingBox/BadgeRow/GradePill/GradeLabel

# Main column & Hero CTA
@onready var _main_col: VBoxContainer = $RootScroll/OuterMargin/MainColumn
@onready var _continue_button: Button = $RootScroll/OuterMargin/MainColumn/HeroContinueCard
@onready var _continue_badge: Label = $RootScroll/OuterMargin/MainColumn/HeroContinueCard/Margin/Row/TextColumn/TopTagRow/ContextBadge/BadgeLabel
@onready var _continue_title: Label = $RootScroll/OuterMargin/MainColumn/HeroContinueCard/Margin/Row/TextColumn/TitleLabel
@onready var _continue_sub: Label = $RootScroll/OuterMargin/MainColumn/HeroContinueCard/Margin/Row/TextColumn/SubLabel

# Bento stats
@onready var _leitner_card: Button = $RootScroll/OuterMargin/MainColumn/StatsBento/LeitnerStatCard
@onready var _leitner_value: Label = $RootScroll/OuterMargin/MainColumn/StatsBento/LeitnerStatCard/Margin/VBox/TopRow/ValueLabel
@onready var _leitner_sub: Label = $RootScroll/OuterMargin/MainColumn/StatsBento/LeitnerStatCard/Margin/VBox/SubLabel
@onready var _saved_card: Button = $RootScroll/OuterMargin/MainColumn/StatsBento/SavedStatCard
@onready var _saved_value: Label = $RootScroll/OuterMargin/MainColumn/StatsBento/SavedStatCard/Margin/VBox/TopRow/ValueLabel

# Quick access grid
@onready var _books_card: Button = $RootScroll/OuterMargin/MainColumn/QuickGrid/BooksCard
@onready var _daily_card: Button = $RootScroll/OuterMargin/MainColumn/QuickGrid/DailyCard
@onready var _games_card: Button = $RootScroll/OuterMargin/MainColumn/QuickGrid/GamesCard
@onready var _exams_card: Button = $RootScroll/OuterMargin/MainColumn/QuickGrid/ExamsCard

# Leaderboard
@onready var _rank_pill_label: Label = $RootScroll/OuterMargin/MainColumn/LeaderboardCard/BoardMargin/BoardVBox/BoardHeader/RankPill/RankPillLabel
@onready var _daily_tab: Button = $RootScroll/OuterMargin/MainColumn/LeaderboardCard/BoardMargin/BoardVBox/SegmentedTrack/BoardTabs/DailyBoardButton
@onready var _lifetime_tab: Button = $RootScroll/OuterMargin/MainColumn/LeaderboardCard/BoardMargin/BoardVBox/SegmentedTrack/BoardTabs/LifetimeBoardButton
@onready var _board_status_label: Label = $RootScroll/OuterMargin/MainColumn/LeaderboardCard/BoardMargin/BoardVBox/StatusBanner/StatusVBox/BoardStatusLabel
@onready var _board_action_button: Button = $RootScroll/OuterMargin/MainColumn/LeaderboardCard/BoardMargin/BoardVBox/StatusBanner/StatusVBox/BoardActionButton
@onready var _daily_entries: VBoxContainer = $RootScroll/OuterMargin/MainColumn/LeaderboardCard/BoardMargin/BoardVBox/DailyEntries
@onready var _lifetime_entries: VBoxContainer = $RootScroll/OuterMargin/MainColumn/LeaderboardCard/BoardMargin/BoardVBox/LifetimeEntries
@onready var _show_more_button: Button = $RootScroll/OuterMargin/MainColumn/LeaderboardCard/BoardMargin/BoardVBox/ShowMoreButton

# Study tip
@onready var _tip_body: Label = $RootScroll/OuterMargin/MainColumn/TipCard/TipMargin/TipRow/TipTextCol/TipBody


############################################################
# LIFECYCLE
############################################################
func _ready() -> void:
	super._ready()
	_wire_cards_and_buttons()
	_attach_gloss_accents()
	_refresh_header()
	_refresh_continue_state()
	_refresh_stats_bento()
	_refresh_tip_card()

	_apply_panels_visibility()
	_update_tab_selection()
	_sync_active_board_chrome()
	_load_daily_board()
	_load_lifetime_board()

	_connect_autoload_signals()

	if not Global.intro_animation_played:
		Global.intro_animation_played = true
		_play_intro_animation()
	else:
		_start_ambient()


func _exit_tree() -> void:
	if _ambient_tween != null and _ambient_tween.is_valid():
		_ambient_tween.kill()
	_disconnect_autoload_signals()


func _connect_autoload_signals() -> void:
	if not Global.review_words_changed.is_connected(_on_review_words_changed):
		Global.review_words_changed.connect(_on_review_words_changed)
	if not API.logged_in.is_connected(_on_auth_state_changed):
		API.logged_in.connect(_on_auth_state_changed)
	if not API.logged_out.is_connected(_on_logged_out):
		API.logged_out.connect(_on_logged_out)
	if not API.subscription_updated.is_connected(_on_auth_state_changed):
		API.subscription_updated.connect(_on_auth_state_changed)
	Global.on_theme_changed(_on_theme_changed)


func _disconnect_autoload_signals() -> void:
	if Global.review_words_changed.is_connected(_on_review_words_changed):
		Global.review_words_changed.disconnect(_on_review_words_changed)
	if API.logged_in.is_connected(_on_auth_state_changed):
		API.logged_in.disconnect(_on_auth_state_changed)
	if API.logged_out.is_connected(_on_logged_out):
		API.logged_out.disconnect(_on_logged_out)
	if API.subscription_updated.is_connected(_on_auth_state_changed):
		API.subscription_updated.disconnect(_on_auth_state_changed)


func _on_review_words_changed() -> void:
	_refresh_stats_bento()


func _on_auth_state_changed(_payload: Dictionary) -> void:
	_refresh_header()
	_load_daily_board()
	_load_lifetime_board()


func _on_logged_out() -> void:
	_refresh_header()
	_load_daily_board()
	_load_lifetime_board()


############################################################
# WIRING & SPRING MICRO-INTERACTIONS
############################################################
func _wire_cards_and_buttons() -> void:
	_continue_button.pressed.connect(_on_continue_pressed)
	_leitner_card.pressed.connect(_on_leitner_stat_pressed)
	_saved_card.pressed.connect(_on_saved_stat_pressed)

	_books_card.pressed.connect(_navigate_forward.bind(SCENE_BOOK_SELECTION))
	_daily_card.pressed.connect(_navigate_forward.bind(SCENE_DAILY_GAME))
	_games_card.pressed.connect(_navigate_forward.bind(SCENE_WORD_GAME_LEARNING))
	_exams_card.pressed.connect(_navigate_forward.bind(SCENE_FINAL_EXAMS))

	_daily_tab.pressed.connect(_on_daily_tab_pressed)
	_lifetime_tab.pressed.connect(_on_lifetime_tab_pressed)
	_board_action_button.pressed.connect(_on_board_action_pressed)
	_show_more_button.pressed.connect(_on_show_more_pressed)

	var spring_buttons: Array[Button] = [
		_continue_button,
		_leitner_card,
		_saved_card,
		_books_card,
		_daily_card,
		_games_card,
		_exams_card,
		_board_action_button,
		_show_more_button,
	]
	for btn: Button in spring_buttons:
		_wire_spring(btn)

	for tab: Button in [_daily_tab, _lifetime_tab]:
		_wire_press_only_spring(tab)


func _attach_gloss_accents() -> void:
	GlossSheenScript.attach(_continue_button, COLOR_BLUE, 30.0)
	GlossSheenScript.attach(_books_card, COLOR_BLUE, 24.0)
	GlossSheenScript.attach(_daily_card, COLOR_GOLD, 24.0)
	GlossSheenScript.attach(_games_card, COLOR_PURPLE, 24.0)
	GlossSheenScript.attach(_exams_card, COLOR_EMERALD, 24.0)


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
# HEADER, CONTINUE & BENTO STATS
############################################################
func _refresh_header() -> void:
	if API.is_logged_in():
		var username: String = API.get_username().strip_edges()
		if username.is_empty():
			_greeting_label.text = "سلام! خوش برگشتی 👋"
		else:
			_greeting_label.text = "سلام، %s 👋" % username

		var grade: int = API.get_grade()
		match grade:
			10:
				_grade_label.text = "پایه دهم"
			11:
				_grade_label.text = "پایه یازدهم"
			12:
				_grade_label.text = "پایه دوازدهم"
			_:
				_grade_label.text = "متوسطه دوم"

		var tier: String = str(API.get_subscription().get("tier", "free"))
		_tier_label.text = "اشتراک ویژه ✨" if tier != "free" and tier != "" else "حساب کاربری فعال"
	else:
		_greeting_label.text = "به ویژن مستر خوش آمدید 👋"
		_grade_label.text = "متوسطه دوم"
		_tier_label.text = "حساب مهمان"


func _refresh_continue_state() -> void:
	var last: String = Global.get_last_scene()
	if last.is_empty() or not ResourceLoader.exists(last):
		_continue_badge.text = "پیشنهاد شروع"
		_continue_title.text = "شروع مسیر یادگیری"
		_continue_sub.text = "کتاب خود را انتخاب کنید و اولین درس را شروع کنید"
		_continue_button.tooltip_text = "انتخاب کتاب و شروع یادگیری"
	else:
		_continue_badge.text = "آخرین فعالیت"
		_continue_title.text = "ادامه یادگیری"
		_continue_sub.text = _continue_destination_label(last)
		_continue_button.tooltip_text = "بازگشت به آخرین بخشی که باز کرده‌اید"


func _continue_destination_label(scene_path: String) -> String:
	var book_tag: String = "کتاب %s · درس %s" % [
		MenuStyle.persian_digits(str(Global.current_book)),
		MenuStyle.persian_digits(str(Global.current_lesson)),
	]
	var scene_names: Dictionary = {
		"res://scenes/book_menu/BookSelection.tscn": "بازگشت به انتخاب کتاب",
		"res://scenes/book_menu/BookMenu.tscn": "فهرست درس‌های کتاب %s" % MenuStyle.persian_digits(str(Global.current_book)),
		"res://scenes/lesson_menu/LessonMenu.tscn": "بخش‌های %s" % book_tag,
		"res://scenes/vocabulary/VocabFlashcards.tscn": "فلش‌کارت لغات · %s" % book_tag,
		"res://scenes/vocabulary/FlashcardHub.tscn": "بخش فلش‌کارت و مرور لایتنر",
		"res://scenes/conversation/Conversation.tscn": "مکالمه · %s" % book_tag,
		"res://scenes/reading/Reading.tscn": "درک مطلب · %s" % book_tag,
		"res://scenes/vocabulary_development/VocabularyDevelopment.tscn": "توسعه واژگان · %s" % book_tag,
		"res://scenes/listening_speaking/ListeningSpeaking.tscn": "شنیداری و گفتاری · %s" % book_tag,
		"res://scenes/pronunciation/Pronunciation.tscn": "تلفظ · %s" % book_tag,
		"res://scenes/writing/Writing.tscn": "نوشتن · %s" % book_tag,
		"res://scenes/what_you_learned/WhatYouLearned.tscn": "آنچه آموختید · %s" % book_tag,
		"res://scenes/workbook/Workbook.tscn": "کتاب کار · %s" % book_tag,
		"res://scenes/grammar/GrammarHub.tscn": "دستور زبان · %s" % book_tag,
		"res://scenes/grammar/GrammarUnits.tscn": "واحدهای گرامر · %s" % book_tag,
		"res://scenes/grammar/GrammarLesson.tscn": "درس گرامر · %s" % book_tag,
		"res://scenes/word_game/WordGameHub.tscn": "ادامه بازی با کلمات",
		"res://scenes/word_game/WordGameLearning.tscn": "تمرین آزاد واژگان",
		"res://scenes/word_game/DailyWordGame.tscn": "ادامه چالش روزانه",
		"res://scenes/exam/FinalExams.tscn": "آزمون‌های امتحان نهایی",
	}
	return str(scene_names.get(scene_path, "بازگشت به آخرین بخش بازشده"))


func _refresh_stats_bento() -> void:
	var due_count: int = Global.get_due_words().size()
	var saved_count: int = Global.get_saved_words().size()

	_leitner_value.text = MenuStyle.persian_digits(str(due_count))
	if due_count > 0:
		_leitner_sub.text = "کلمه آماده مرور"
	elif Global.get_review_words().is_empty():
		_leitner_sub.text = "هنوز کارتی نیست"
	else:
		_leitner_sub.text = "مرور امروز کامل ✓"

	_saved_value.text = MenuStyle.persian_digits(str(saved_count))


func _refresh_tip_card() -> void:
	var day_seed: int = int(Time.get_unix_time_from_system() / 86400.0)
	var index: int = posmod(day_seed, STUDY_TIPS.size())
	_tip_body.text = STUDY_TIPS[index]


############################################################
# NAVIGATION ACTIONS
############################################################
func _on_continue_pressed() -> void:
	if _navigating:
		return
	var last: String = Global.get_last_scene()
	var target: String = last
	if target.is_empty() or not ResourceLoader.exists(target):
		if not last.is_empty():
			Global.set_last_scene("")
		target = SCENE_BOOK_SELECTION
	_navigate_forward(target)


func _on_leitner_stat_pressed() -> void:
	if _navigating:
		return
	Sfx.click()
	_navigating = true
	AppRouter.set_args({"return_route": SCENE_MAIN_MENU})
	TransitionManager.slide_change_scene(SCENE_WORD_REVIEW, TransitionManager.Slide.FORWARD)


func _on_saved_stat_pressed() -> void:
	if _navigating:
		return
	Sfx.click()
	_navigating = true
	AppRouter.set_args({
		"mode": "saved",
		"return_route": SCENE_FLASHCARDS,
		"saved_back_route": SCENE_MAIN_MENU,
	})
	var target: String = SCENE_SAVED_WORDS if Global.get_saved_words().is_empty() else SCENE_FLASHCARDS
	TransitionManager.slide_change_scene(target, TransitionManager.Slide.FORWARD)


func _navigate_forward(scene_path: String) -> void:
	if _navigating:
		return
	_navigating = true
	Sfx.click()
	await get_tree().create_timer(0.08).timeout
	if not is_inside_tree():
		return
	TransitionManager.slide_change_scene(scene_path, TransitionManager.Slide.FORWARD)


############################################################
# LEADERBOARD TABS & DATA
############################################################
func _on_daily_tab_pressed() -> void:
	if _daily_selected:
		_update_tab_selection()
		return
	Sfx.click()
	_daily_selected = true
	_apply_panels_visibility()
	_update_tab_selection()
	_sync_active_board_chrome()
	_animate_board_switch(_daily_entries)


func _on_lifetime_tab_pressed() -> void:
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
	_daily_tab.button_pressed = _daily_selected
	_lifetime_tab.button_pressed = not _daily_selected


func _sync_active_board_chrome() -> void:
	_board_status_label.text = _daily_status_text if _daily_selected else _lifetime_status_text
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
		_navigate_forward(SCENE_AUTH)
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


func _load_daily_board() -> void:
	_daily_request_id += 1
	_daily_rows = []
	_clear_children(_daily_entries)
	if not API.is_configured() or not API.is_logged_in():
		_daily_status_text = "برای مشاهده رتبه‌بندی امروز و ثبت امتیاز رسمی، وارد حساب کاربری شوید."
		_daily_rank_badge = "رقابت روزانه 🌐"
		_daily_action = BoardAction.LOGIN
		_sync_active_board_chrome()
		return
	var request_id: int = _daily_request_id
	_daily_status_text = "در حال دریافت رتبه‌بندی امروز از سرور…"
	_daily_rank_badge = "در حال دریافت…"
	_daily_action = BoardAction.NONE
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
		_sync_active_board_chrome()
		return
	var request_id: int = _lifetime_request_id
	_lifetime_status_text = "در حال دریافت رتبه‌بندی کل از سرور…"
	_lifetime_rank_badge = "در حال دریافت…"
	_lifetime_action = BoardAction.NONE
	_sync_active_board_chrome()
	API.fetch_lifetime_leaderboard(50, 0, func(ok: bool, data: Dictionary) -> void: _on_lifetime_loaded(request_id, ok, data))


func _on_daily_loaded(request_id: int, ok: bool, data: Dictionary) -> void:
	if request_id != _daily_request_id:
		return
	if not ok:
		_daily_status_text = "اتصال به سرور برقرار نشد؛ اینترنت خود را بررسی کنید و دوباره تلاش کنید. 📡"
		_daily_rank_badge = "آفلاین 📡"
		_daily_action = BoardAction.RETRY
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
	else:
		_daily_status_text = "%s\nامروز هنوز بازی نکرده‌ای! چالش روزانه را بازی کن و اسمت را ثبت کن 🔥" % period
		_daily_rank_badge = "چالش امروز 🔥"
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
	else:
		_lifetime_status_text = "هنوز امتیازی ثبت نکرده‌ای! از چالش امروز شروع کن و به بالای جدول برس 🚀"
		_lifetime_rank_badge = "برترین‌ها 🏆"
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
		empty.add_theme_font_size_override("font_size", 29)
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

	# If collapsed and the player is outside top N, append their own row below a subtle separator
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
# THEME & MOTION
############################################################
func _on_theme_changed(_mode: int) -> void:
	_apply_theme()


func _apply_theme() -> void:
	if not is_inside_tree():
		return
	_refresh_header()
	_refresh_continue_state()
	_refresh_stats_bento()


func _start_ambient() -> void:
	if _brand_mark == null:
		return
	_brand_mark.pivot_offset = _brand_mark.size / 2.0
	if _ambient_tween != null and _ambient_tween.is_valid():
		_ambient_tween.kill()
	_ambient_tween = create_tween().set_loops()
	_ambient_tween.tween_property(_brand_mark, "scale", Vector2(1.04, 1.04), 2.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_ambient_tween.tween_property(_brand_mark, "scale", Vector2.ONE, 2.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _play_intro_animation() -> void:
	var targets: Array[Control] = []
	for child: Node in _main_col.get_children():
		if child is Control and not child.is_queued_for_deletion():
			var ctrl := child as Control
			ctrl.modulate.a = 0.0
			ctrl.pivot_offset = ctrl.size / 2.0
			ctrl.scale = Vector2(0.96, 0.96)
			targets.append(ctrl)

	await get_tree().process_frame
	if not is_inside_tree():
		return

	var tw := create_tween()
	tw.set_parallel(true)
	for i: int in range(targets.size()):
		var target: Control = targets[i]
		target.pivot_offset = target.size / 2.0
		var delay: float = 0.04 * float(i)
		tw.tween_property(target, "modulate:a", 1.0, 0.28).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(target, "scale", Vector2.ONE, 0.34).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await tw.finished
	if not is_inside_tree():
		return
	_start_ambient()


############################################################
# ANDROID BACK (double-tap to exit)
############################################################
func _on_android_back_pressed() -> void:
	var current_time: float = Time.get_unix_time_from_system()
	if back_pressed_time > 0.0 and current_time - back_pressed_time < double_back_timeout:
		get_tree().quit()
	else:
		back_pressed_time = current_time
		_show_back_message()


func _show_back_message() -> void:
	if not _back_message_nodes.is_empty():
		return

	# Navigation bar top is at offset_top = -144 from screen bottom.
	# Sit 50 pixels above the navigation bar: -144 - 50 = -194.
	var toast := PanelContainer.new()
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.anchor_left = 0.5
	toast.anchor_right = 0.5
	toast.anchor_top = 1.0
	toast.anchor_bottom = 1.0
	toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast.grow_vertical = Control.GROW_DIRECTION_BEGIN
	toast.offset_bottom = -194.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.18, 0.92)
	style.set_corner_radius_all(24)
	style.content_margin_left = 36.0
	style.content_margin_right = 36.0
	style.content_margin_top = 16.0
	style.content_margin_bottom = 16.0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.25)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 4)
	toast.add_theme_stylebox_override("panel", style)

	var message := Label.new()
	message.text = "برای خروج دوباره دکمه برگشت را بزنید"
	message.add_theme_font_override("font", MenuStyle.vazir())
	message.add_theme_font_size_override("font_size", 30)
	message.add_theme_color_override("font_color", Color.WHITE)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.add_child(message)

	toast.modulate.a = 0.0
	add_child(toast)
	_back_message_nodes = [toast]

	var in_tw := create_tween()
	in_tw.tween_property(toast, "modulate:a", 1.0, 0.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(1.8).timeout
	if not is_inside_tree() or toast == null or not is_instance_valid(toast):
		_back_message_nodes.clear()
		return

	var out_tw := create_tween()
	out_tw.tween_property(toast, "modulate:a", 0.0, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await out_tw.finished
	if is_instance_valid(toast):
		toast.queue_free()
	_back_message_nodes.clear()
