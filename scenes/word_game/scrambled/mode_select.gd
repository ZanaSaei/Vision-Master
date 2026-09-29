extends Control
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
	column.add_child(_make_mode_card(
		"LearningCard", "یادگیری", "تمرین با آرامش", "بدون زمان‌سنج و بدون امتیاز", "📚",
		COLOR_LEARNING, false))
	var competition_description: String = "۵ کلمه · امتیاز تا ۵۰۰ · یک‌بار در روز"
	competition_description += "\nبه‌روزرسانی روزانه تا %s دیگر" % ScrambledDailyPicker.time_left_text()
	column.add_child(_make_mode_card(
		"CompetitionCard", "مسابقه روزانه", "چالش زمان‌دار", competition_description, "🏆",
		COLOR_COMPETITION, ScrambledScoreManager.today_played()))
	_record_card = PanelContainer.new()
	_record_card.name = "RecordCard"
	_record_card.add_theme_stylebox_override("panel", MenuStyle.card_style(COLOR_RECORD, 26, false, true))
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
	column.add_child(MenuStyle.make_tip_card("کلمه‌های مسابقه برای همه یکسان است و هر روز تازه می‌شود."))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	column.add_child(spacer)
func _make_mode_card(node_name: String, title_text: String, tag_text: String,
		description_text: String, icon_text: String, accent: Color, locked: bool) -> Button:
	var button := Button.new()
	button.name = node_name
	button.custom_minimum_size = Vector2(0, 300)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.disabled = locked
	button.add_theme_stylebox_override("normal", _mode_card_style(accent, false, locked))
	button.add_theme_stylebox_override("hover", _mode_card_style(accent, true, locked))
	button.add_theme_stylebox_override("pressed", _mode_card_style(accent, false, locked))
	button.add_theme_stylebox_override("disabled", _mode_card_style(accent, false, true))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", MenuStyle.text())
	button.add_theme_color_override("font_hover_color", MenuStyle.text())
	button.add_theme_color_override("font_pressed_color", MenuStyle.text())
	button.add_theme_color_override("font_disabled_color", MenuStyle.text())
	button.add_theme_font_override("font", MenuStyle.vazir())
	button.add_theme_font_size_override("font_size", 1)
	button.add_theme_constant_override("h_separation", 0)
	button.add_theme_constant_override("icon_max_width", 0)
	button.alignment = HORIZONTAL_ALIGNMENT_FILL
	if not locked:
		button.pressed.connect(_on_mode_card_pressed.bind(node_name))

	var margin := MarginContainer.new()
	margin.name = "ModeCardContent"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	button.add_child(margin)

	var layout := HBoxContainer.new()
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_theme_constant_override("separation", 22)
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(layout)

	var icon_panel := PanelContainer.new()
	icon_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_panel.custom_minimum_size = Vector2(140, 140)
	icon_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_panel.add_theme_stylebox_override("panel", _mode_icon_style(accent, locked))
	layout.add_child(icon_panel)
	var icon := Label.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.text = icon_text
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 68)
	icon_panel.add_child(icon)

	var copy := VBoxContainer.new()
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 5)
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_child(copy)
	if not locked:
		var tag := Label.new()
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.text = tag_text
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		tag.text_direction = Control.TEXT_DIRECTION_RTL
		tag.add_theme_font_size_override("font_size", 22)
		tag.add_theme_color_override("font_color", accent.darkened(0.08))
		copy.add_child(tag)
	var title := Label.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title.text_direction = Control.TEXT_DIRECTION_RTL
	title.add_theme_font_override("font", MenuStyle.vazir())
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", MenuStyle.text())
	copy.add_child(title)
	var description := Label.new()
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	description.text = description_text
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	description.text_direction = Control.TEXT_DIRECTION_RTL
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_override("font", MenuStyle.vazir())
	description.add_theme_font_size_override("font_size", 26)
	description.add_theme_color_override("font_color", MenuStyle.subtitle_color())
	copy.add_child(description)

	if locked:
		button.disabled = false
		button.add_child(_make_completed_overlay())
	return button


func _make_completed_overlay() -> Control:
	var overlay := Control.new()
	overlay.name = "CompletedOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 10
	var wash := Panel.new()
	wash.name = "MutedWash"
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash.offset_left = 8
	wash.offset_top = 8
	wash.offset_right = -8
	wash.offset_bottom = -8
	var wash_style := StyleBoxFlat.new()
	wash_style.bg_color = Color(0.39, 0.43, 0.49, 0.62)
	wash_style.set_corner_radius_all(24)
	wash_style.set_border_width_all(0)
	wash.add_theme_stylebox_override("panel", wash_style)
	overlay.add_child(wash)
	var completed := Label.new()
	completed.name = "CompletedLabel"
	completed.text = "انجام شده"
	completed.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	completed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	completed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	completed.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	completed.add_theme_font_override("font", MenuStyle.vazir())
	completed.add_theme_font_size_override("font_size", 54)
	completed.add_theme_color_override("font_color", Color.WHITE)
	overlay.add_child(completed)
	return overlay


func _on_mode_card_pressed(card_name: String) -> void:
	Sfx.click()
	if card_name == "LearningCard":
		learning_requested.emit()
	else:
		competition_requested.emit()


func _mode_card_style(accent: Color, hovered: bool, locked: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var dark := MenuStyle.is_dark()
	style.bg_color = MenuStyle.paper() if not dark else DesignTokens.color_of(true, "surface")
	if hovered and not locked:
		style.bg_color = style.bg_color.lightened(0.035)
	style.set_corner_radius_all(28)
	style.set_border_width_all(3 if not locked else 1)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.82 if not locked else 0.24)
	style.shadow_color = Color(0.02, 0.08, 0.18, 0.20 if hovered and not locked else 0.09)
	style.shadow_size = 14 if hovered and not locked else 7
	style.shadow_offset = Vector2(0, 5)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _mode_icon_style(accent: Color, locked: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r, accent.g, accent.b, 0.13 if not locked else 0.06)
	style.set_corner_radius_all(28)
	style.set_border_width_all(2)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.32 if not locked else 0.14)
	return style


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
	headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	headline.add_theme_font_override("font", MenuStyle.vazir())
	headline.add_theme_font_size_override("font_size", 38)
	if played:
		var rating := ScrambledScoreManager.rating_for(today)
		headline.text = "%s  %s امروز — امتیاز %s از %s" % [str(rating.get("emoji", "")), str(rating.get("label", "")), digits(today), digits(ScrambledScoreManager.MAX_DAILY_SCORE)]
		headline.text += "\nچالش امروز کامل شده؛ فردا دوباره برگرد!"
		headline.add_theme_color_override("font_color", COLOR_LEARNING)
	else:
		headline.text = "امروز هنوز مسابقه را بازی نکرده‌ای — ۵ کلمه منتظر توست"
		headline.add_theme_color_override("font_color", COLOR_COMPETITION)
	_record_rows.add_child(headline)
	_record_rows.add_child(HSeparator.new())
	_record_rows.add_child(_make_stat_row("بهترین امتیاز", digits(ScrambledScoreManager.best_score())))
	_record_rows.add_child(_make_stat_row("روزهای مسابقه", digits(ScrambledScoreManager.played_days())))
	_record_rows.add_child(_make_stat_row("کلمه‌های تمرین‌شده", digits(int(practice["words"]))))
	_record_rows.add_child(_make_stat_row("درس‌های تمرینشده", digits(int(practice["lessons"]))))
	_record_rows.add_child(_make_stat_row("مسابقه‌ی بعدی", ScrambledDailyPicker.time_left_text()))
func _make_stat_row(label_text: String, value_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 60)
	row.add_theme_constant_override("separation", 14)
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", MenuStyle.vazir())
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", MenuStyle.subtitle_color())
	row.add_child(label)
	var value := Label.new()
	value.text = value_text
	value.custom_minimum_size = Vector2(130, 54)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.add_theme_font_override("font", MenuStyle.vazir())
	value.add_theme_font_size_override("font_size", 28)
	value.add_theme_color_override("font_color", MenuStyle.text())
	row.add_child(value)
	return row
func digits(value: int) -> String:
	return MenuStyle.persian_digits(str(value))
