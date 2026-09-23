extends Control
## ============================================================
##  RESULTS — what the session that just ended was worth.
##
##  Reads ScrambledGameManager, which still holds the finished session, so it
##  can report both modes honestly:
##    COMPETITION — the daily total out of 500, its rating, the record and the
##                  points of every word.
##    LEARNING    — how many words of the lesson were spelled, how long it took
##                  and how often the meaning was revealed.
##
##  "بازی دوباره" replays the very same mode; the host screen does the dealing.
## ============================================================

signal replay_requested()
signal home_requested()

const COLOR_SCORE := Color("#31C463")
const COLOR_LEARNING := DesignTokens.ACCENT
const COLOR_HINT := Color("#FFB703")
const COLOR_RECORD := Color("#C77DFF")

var _content: VBoxContainer = null
var _score_label: Label = null
var _shown_score := 0.0:
	set(value):
		_shown_score = value
		if _score_label != null:
			_score_label.text = MenuStyle.persian_digits(str(int(round(value))))


func _ready() -> void:
	_build_ui()
	_apply_theme()
	Global.on_theme_changed(_on_theme_changed)
	_play_score_animation()


func screen_title() -> String:
	return "مسابقه روزانه" if ScrambledGameManager.is_competition() else "نتیجه تمرین"


func handle_back() -> void:
	home_requested.emit()


func _on_theme_changed(_mode: int) -> void:
	_apply_theme()


func _apply_theme() -> void:
	var background := get_node_or_null("Background") as ColorRect
	if background != null:
		background.color = ScrambledTheme.page_tint()
	if _content != null:
		_fill_content()


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
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 60)
	scroll.add_child(margin)

	_content = VBoxContainer.new()
	_content.name = "Content"
	_content.add_theme_constant_override("separation", 18)
	margin.add_child(_content)
	_fill_content()


## The whole card set, rebuilt from the session (and on a theme change, since
## the colours of the labels come from the palette).
func _fill_content() -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_score_label = null

	if ScrambledGameManager.is_competition():
		_fill_competition()
	else:
		_fill_learning()

	_content.add_child(_make_summary_card())
	_content.add_child(_make_word_list_card())
	_content.add_child(_make_action_row())


## --------------------------------------------------------------- the hero --
func _fill_competition() -> void:
	var total := ScrambledGameManager.total_score()
	var rating := ScrambledScoreManager.rating_for(total)
	_content.add_child(_make_hero(str(rating.get("emoji", "🏆")),
		str(rating.get("label", "")), "امتیاز امروز", COLOR_SCORE))

	var score_row := _make_score_row(COLOR_SCORE, str(ScrambledScoreManager.MAX_DAILY_SCORE))
	_content.add_child(score_row)
	if ScrambledGameManager.last_run_new_best:
		_content.add_child(_make_note("رکورد امروز بهتر شد!", COLOR_RECORD))


func _fill_learning() -> void:
	var book := ScrambledGameManager.book
	var lesson := ScrambledGameManager.lesson
	var lesson_title := ScrambledData.lesson_title_fa(book, lesson)
	var subtitle := "%s · درس %s" % [ScrambledData.book_label(book),
		MenuStyle.persian_digits(str(lesson))]
	if not lesson_title.is_empty():
		subtitle += " · %s" % lesson_title
	_content.add_child(_make_hero("📚", "تمرین کامل شد", subtitle, COLOR_LEARNING))
	_content.add_child(_make_score_row(COLOR_LEARNING,
		str(ScrambledData.word_count(book, lesson))))


## The big number, out of the day's maximum (competition) or the lesson's size.
func _make_score_row(accent: Color, maximum: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "ScoreRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	_score_label = Label.new()
	_score_label.name = "ScoreLabel"
	_score_label.text = MenuStyle.persian_digits(str(int(round(_shown_score))))
	_score_label.add_theme_font_override("font", MenuStyle.nunito())
	_score_label.add_theme_font_size_override("font_size", 150)
	_score_label.add_theme_color_override("font_color", accent)
	row.add_child(_score_label)
	var of_label := Label.new()
	of_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	of_label.text = "/ %s" % MenuStyle.persian_digits(maximum)
	of_label.add_theme_font_override("font", MenuStyle.vazir())
	of_label.add_theme_font_size_override("font_size", 56)
	of_label.add_theme_color_override("font_color", MenuStyle.subtitle_color())
	of_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	row.add_child(of_label)
	return row


func _make_hero(emoji: String, headline: String, subtitle: String, accent: Color) -> VBoxContainer:
	var hero := VBoxContainer.new()
	hero.add_theme_constant_override("separation", 8)
	var emoji_label := Label.new()
	emoji_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emoji_label.text = emoji
	emoji_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji_label.add_theme_font_size_override("font_size", 96)
	hero.add_child(emoji_label)
	var title := Label.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.text = headline
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_override("font", MenuStyle.vazir())
	title.add_theme_font_size_override("font_size", 58)
	title.add_theme_color_override("font_color", accent)
	hero.add_child(title)
	var sub := Label.new()
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub.text = subtitle
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_override("font", MenuStyle.vazir())
	sub.add_theme_font_size_override("font_size", 34)
	sub.add_theme_color_override("font_color", MenuStyle.subtitle_color())
	hero.add_child(sub)
	return hero


func _make_note(text: String, accent: Color) -> Label:
	var note := Label.new()
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note.text = text
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_override("font", MenuStyle.vazir())
	note.add_theme_font_size_override("font_size", 36)
	note.add_theme_color_override("font_color", accent)
	return note


## The count-up: the score rolls from zero to its value once the card appears.
func _play_score_animation() -> void:
	if _score_label == null:
		return
	var target := _target_score()
	_shown_score = 0.0
	var tw := create_tween()
	tw.tween_method(_set_shown_score, 0.0, float(target), 0.9) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _set_shown_score(value: float) -> void:
	_shown_score = value


func _target_score() -> int:
	if ScrambledGameManager.is_competition():
		return ScrambledGameManager.total_score()
	return ScrambledGameManager.correct_count()


## -------------------------------------------------------------- the cards --
## A plain card that the caller fills. Returns the column INSIDE the card; the
## caller is responsible for parenting the returned PanelContainer (reachable
## through `column.get_parent().get_parent()`).
##
## WHY the caller parents it: this used to add the panel to `_content` itself
## AND hand it back, so `_fill_content` parented the same node a second time
## and Godot raised "already has a parent" on every Results load.
func _make_card(accent: Color) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.name = "Card"
	panel.add_theme_stylebox_override("panel", MenuStyle.card_style(accent, 28, false, true))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	return column


func _make_card_title(text: String, accent: Color) -> Label:
	var title := Label.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.text = text
	title.add_theme_font_override("font", MenuStyle.vazir())
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", accent)
	return title


## The numbers behind the run, one line each.
func _make_summary_card() -> PanelContainer:
	var competition := ScrambledGameManager.is_competition()
	var accent := COLOR_SCORE if competition else COLOR_LEARNING
	var column := _make_card(accent)
	column.add_child(_make_card_title("خلاصه", accent))
	var counts := ScrambledGameManager.score_band_counts()
	if competition:
		column.add_child(_make_stat_row("کلمه‌های درست",
			"%s از %s" % [digits(ScrambledGameManager.correct_count()),
				digits(ScrambledDailyPicker.WORDS_PER_DAY)], accent))
		column.add_child(_make_stat_row("بهترین امتیاز",
			digits(ScrambledScoreManager.best_score()), COLOR_RECORD))
		column.add_child(_make_stat_row("روزهای مسابقه",
			digits(ScrambledScoreManager.played_days()), COLOR_RECORD))
		column.add_child(_make_stat_row("۱۰۰ امتیازی (زیر ۱۰ ثانیه)",
			digits(int(counts["fast"])), COLOR_SCORE))
		column.add_child(_make_stat_row("۶۰ امتیازی (زیر ۳۰ ثانیه)",
			digits(int(counts["quick"])), COLOR_SCORE))
	else:
		var lesson := ScrambledGameManager.lesson
		var practice := ScrambledScoreManager.practice_stats(ScrambledGameManager.book, lesson)
		column.add_child(_make_stat_row("کلمه‌های درس %s" % digits(lesson),
			digits(ScrambledGameManager.correct_count()), accent))
		column.add_child(_make_stat_row("مجموع تمرین این درس",
			digits(int(practice["words"])), COLOR_RECORD))
	column.add_child(_make_stat_row("با راهنما",
		digits(ScrambledGameManager.hints_used()), COLOR_HINT))
	column.add_child(_make_stat_row("زمان کل",
		_format_seconds(ScrambledGameManager.session_seconds()), COLOR_RECORD))
	column.add_child(_make_stat_row("میانگین هر کلمه",
		_format_seconds(ScrambledGameManager.average_seconds()), COLOR_RECORD))
	return column.get_parent().get_parent() as PanelContainer


## Word by word: what was spelled, how long it took and what it was worth.
func _make_word_list_card() -> PanelContainer:
	var accent := COLOR_SCORE if ScrambledGameManager.is_competition() else COLOR_LEARNING
	var column := _make_card(accent)
	column.add_child(_make_card_title("کلمه به کلمه", accent))
	var results := ScrambledGameManager.results()
	if results.is_empty():
		column.add_child(_make_note("این بازی بدون پاسخ درست تمام شد.",
			MenuStyle.subtitle_color()))
	for i in results.size():
		column.add_child(_make_word_row(results[i] as Dictionary, i + 1))
	return column.get_parent().get_parent() as PanelContainer


## ---------------------------------------------------------------- buttons --
func _make_action_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "ActionRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)

	var accent := COLOR_SCORE if ScrambledGameManager.is_competition() else COLOR_LEARNING
	var again := Button.new()
	again.name = "ReplayButton"
	again.text = "بازی دوباره"
	again.custom_minimum_size = Vector2(0, 132)
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.add_theme_font_override("font", MenuStyle.vazir())
	again.add_theme_font_size_override("font_size", 42)
	again.add_theme_color_override("font_color", MenuStyle.on_accent(accent))
	again.add_theme_stylebox_override("normal", _filled_style(accent, false))
	again.add_theme_stylebox_override("hover", _filled_style(accent, true))
	again.add_theme_stylebox_override("pressed", _filled_style(accent, true))
	again.pressed.connect(func() -> void:
		Sfx.click()
		replay_requested.emit())
	MenuStyle.wire_microinteractions(again)
	row.add_child(again)

	var home := Button.new()
	home.name = "HomeButton"
	home.text = "بازگشت به منو"
	home.custom_minimum_size = Vector2(0, 132)
	home.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	home.add_theme_font_override("font", MenuStyle.vazir())
	home.add_theme_font_size_override("font_size", 42)
	home.pressed.connect(func() -> void:
		Sfx.click()
		home_requested.emit())
	MenuStyle.wire_microinteractions(home)
	row.add_child(home)
	return row


## --------------------------------------------------------------- helpers --
func _filled_style(accent: Color, hover: bool) -> StyleBoxFlat:
	var fill := accent.lightened(0.10) if hover else accent
	var style := ScrambledTheme.chip_style(fill, 30, ScrambledTheme.tile_edge(accent), 3)
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	style.shadow_color = Color(0.06, 0.09, 0.18, 0.28 if hover else 0.20)
	style.shadow_size = 24 if hover else 16
	style.shadow_offset = Vector2(0.0, 10.0 if hover else 6.0)
	return style


func _make_stat_row(label_text: String, value_text: String, accent: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var name_label := Label.new()
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.text = label_text
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_override("font", MenuStyle.vazir())
	name_label.add_theme_font_size_override("font_size", 30)
	name_label.add_theme_color_override("font_color", MenuStyle.subtitle_color())
	row.add_child(name_label)
	var value_label: Label = MenuStyle.pill_label(value_text, accent, 28)
	value_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(value_label)
	return row


## "۰:۱۲" — the same mm:ss shape the gameplay timer uses.
func _format_seconds(seconds: float) -> String:
	var total := int(round(seconds))
	return MenuStyle.persian_digits("%d:%02d" % [int(floor(float(total) / 60.0)), total % 60])


func digits(value: int) -> String:
	return MenuStyle.persian_digits(str(value))


func _make_word_row(entry: Dictionary, word_index: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var word := Label.new()
	word.mouse_filter = Control.MOUSE_FILTER_IGNORE
	word.text = "%s. %s" % [MenuStyle.persian_digits(str(word_index)), str(entry.get("word", ""))]
	word.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	word.add_theme_font_override("font", MenuStyle.nunito())
	word.add_theme_font_size_override("font_size", 38)
	word.add_theme_color_override("font_color", MenuStyle.text())
	row.add_child(word)
	if bool(entry.get("hint_used", false)):
		var hint: Label = MenuStyle.pill_label("با راهنما", COLOR_HINT, 26)
		hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(hint)
	var time: Label = MenuStyle.pill_label(_format_seconds(float(entry.get("seconds", 0.0))),
		COLOR_RECORD, 26)
	time.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(time)
	if ScrambledGameManager.is_competition():
		var points: Label = MenuStyle.pill_label("%s+" % digits(int(entry.get("points", 0))),
			COLOR_SCORE, 26)
		points.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(points)
	return row