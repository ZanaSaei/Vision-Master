extends Control
## ============================================================
##  MODE SELECT — the home of «بازی املا».
##
##  Two ways in (learning a lesson, or the five words of the day) plus the
##  player's record, which is read from ScrambledScoreManager so the daily
##  card can say what today is worth, what the best score is and when the next
##  challenge arrives. Everything is a themed card built in code, which is why
##  the game opts out of the app-wide theme walk (see ScrambledWords).
## ============================================================

signal learning_requested()
signal competition_requested()
signal exit_requested()

const COLOR_LEARNING := Color("#22C55E")
const COLOR_COMPETITION := Color("#F59E0B")
const COLOR_RECORD := DesignTokens.ACCENT

var _record_card: PanelContainer = null
var _record_rows: VBoxContainer = null


func _ready() -> void:
	_build_ui()
	_apply_theme()
	Global.on_theme_changed(_on_theme_changed)


func screen_title() -> String:
	return "بازی املا"


func handle_back() -> void:
	exit_requested.emit()


func _on_theme_changed(_mode: int) -> void:
	_apply_theme()


func _apply_theme() -> void:
	var background := get_node_or_null("Background") as ColorRect
	if background != null:
		background.color = ScrambledTheme.page_tint()
	_refresh_record()


## ---------------------------------------------------------------- layout --
func _build_ui() -> void:
	var background := ColorRect.new()
	background.name = "Background"
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 60)
	scroll.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	margin.add_child(column)

	column.add_child(_make_hero())

	var learning_card: Button = MenuStyle.make_card(
		"یادگیری",
		"یک کتاب و درس را انتخاب کن — بدون امتیاز و بدون فشار زمان",
		"📚", COLOR_LEARNING, 176, "", true)
	learning_card.name = "LearningCard"
	learning_card.pressed.connect(func() -> void:
		Sfx.click()
		learning_requested.emit())
	MenuStyle.wire_microinteractions(learning_card)
	column.add_child(learning_card)

	var competition_card: Button = MenuStyle.make_card(
		"مسابقه روزانه",
		"۵ کلمه‌ی امروز — هر کلمه تا ۱۰۰ امتیاز، روزی یک رکورد",
		"🏆", COLOR_COMPETITION, 176, "", true)
	competition_card.name = "CompetitionCard"
	competition_card.pressed.connect(func() -> void:
		Sfx.click()
		competition_requested.emit())
	MenuStyle.wire_microinteractions(competition_card)
	column.add_child(competition_card)

	_record_card = PanelContainer.new()
	_record_card.name = "RecordCard"
	_record_card.add_theme_stylebox_override("panel",
		MenuStyle.card_style(COLOR_RECORD, 26, false, true))
	column.add_child(_record_card)
	var record_margin := MarginContainer.new()
	record_margin.add_theme_constant_override("margin_left", 28)
	record_margin.add_theme_constant_override("margin_right", 28)
	record_margin.add_theme_constant_override("margin_top", 22)
	record_margin.add_theme_constant_override("margin_bottom", 22)
	_record_card.add_child(record_margin)
	_record_rows = VBoxContainer.new()
	_record_rows.add_theme_constant_override("separation", 10)
	record_margin.add_child(_record_rows)

	column.add_child(MenuStyle.make_tip_card(
		"کلمه‌های مسابقه برای همه یکسان است و هر روز تازه می‌شود."))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	column.add_child(spacer)


## The line that explains the game once, under the header.
func _make_hero() -> VBoxContainer:
	var hero := VBoxContainer.new()
	hero.add_theme_constant_override("separation", 6)
	var title := Label.new()
	title.name = "HeroTitle"
	title.text = "حروف را درست بچین"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", MenuStyle.vazir())
	title.add_theme_font_size_override("font_size", 54)
	hero.add_child(title)
	var subtitle := Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "حرف‌های به‌هم‌ریخته‌ی هر کلمه را با انگشت جابه‌جا کن تا کلمه ساخته شود"
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_override("font", MenuStyle.vazir())
	subtitle.add_theme_font_size_override("font_size", 32)
	subtitle.add_theme_color_override("font_color", MenuStyle.subtitle_color())
	hero.add_child(subtitle)
	return hero


## ------------------------------------------------------------- the record --
## Rebuilt on entry and on a theme change, so the card always shows what the
## save file actually holds.
func _refresh_record() -> void:
	if _record_rows == null:
		return
	for child in _record_rows.get_children():
		_record_rows.remove_child(child)
		child.queue_free()

	var played := ScrambledScoreManager.today_played()
	var today := ScrambledScoreManager.today_score()
	var practice := ScrambledScoreManager.practice_summary()

	var headline := Label.new()
	headline.name = "RecordHeadline"
	headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	headline.add_theme_font_override("font", MenuStyle.vazir())
	headline.add_theme_font_size_override("font_size", 38)
	if played:
		var rating := ScrambledScoreManager.rating_for(today)
		headline.text = "%s  %s امروز — امتیاز %s از %s" % [
			str(rating.get("emoji", "")), str(rating.get("label", "")),
			digits(today), digits(ScrambledScoreManager.MAX_DAILY_SCORE)]
		headline.add_theme_color_override("font_color", COLOR_LEARNING)
	else:
		headline.text = "امروز هنوز مسابقه را بازی نکرده‌ای — ۵ کلمه منتظر توست"
		headline.add_theme_color_override("font_color", COLOR_COMPETITION)
	_record_rows.add_child(headline)

	var divider := HSeparator.new()
	_record_rows.add_child(divider)

	_record_rows.add_child(_make_stat_row("بهترین امتیاز",
		digits(ScrambledScoreManager.best_score()), COLOR_LEARNING))
	_record_rows.add_child(_make_stat_row("روزهای مسابقه",
		digits(ScrambledScoreManager.played_days()), COLOR_RECORD))
	_record_rows.add_child(_make_stat_row("کلمه‌های تمرین‌شده",
		digits(int(practice["words"])), COLOR_COMPETITION))
	_record_rows.add_child(_make_stat_row("درس‌های تمرینشده",
		digits(int(practice["lessons"])), COLOR_RECORD))
	_record_rows.add_child(_make_stat_row("مسابقهی بعدی",
		ScrambledDailyPicker.time_left_text(), COLOR_RECORD))


## One "label ...... [value]" line of the record card.
func _make_stat_row(label_text: String, value_text: String, accent: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var name_label := Label.new()
	name_label.text = label_text
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_override("font", MenuStyle.vazir())
	name_label.add_theme_font_size_override("font_size", 32)
	name_label.add_theme_color_override("font_color", MenuStyle.subtitle_color())
	row.add_child(name_label)
	var value_label: Label = MenuStyle.pill_label(value_text, accent, 30)
	value_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(value_label)
	return row


func digits(value: int) -> String:
	return MenuStyle.persian_digits(str(value))