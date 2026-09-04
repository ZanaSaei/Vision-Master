extends "res://autoload/BackButtonHandler.gd"

############################################################
# BOOK MENU — modern, friendly lesson picker.
# Reads Global.current_book to build lesson cards.
# Navigation uses the SLIDE transition (book -> lesson spine).
# The animated background lives in the MenuBackground autoload.
############################################################

const SCENE_MAIN_MENU   := "res://scenes/main_menu/MainMenu.tscn"
const SCENE_LESSON_MENU := "res://scenes/lesson_menu/LessonMenu.tscn"
const BACK_ICON         := "res://images/Back.png"

# Persian + English lesson titles per book.
const LESSON_DATA := {
	1: [
		"Saving Nature",
		"Wonders of Creation",
		"The Value of Knowledge",
		"Traveling the World",
	],
	2: [
		"Understanding People",
		"A Healthy Lifestyle",
		"Art and Culture",
	],
	3: [
		"Sense of Appreciation",
		"Look It Up!",
		"Renewable Energy",
	],
}

const BOOK_COLORS := {
	1: Color("#2563EB"),   # Vision 1 — blue
	2: Color("#16A34A"),   # Vision 2 — green
	3: Color("#EA580C"),   # Vision 3 — orange
}

const PERSIAN_DIGITS := ["۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]

var _navigating: bool = false
var _book: int = 1
var _accent: Color = Color("#2563EB")

# Built UI state.
var _scroll: ScrollContainer = null
var _col: VBoxContainer = null
var _title_label: Label = null
var _count_badge: Label = null
var _back_button: Button = null
var _card_buttons: Array[Button] = []


func _ready() -> void:
	_book = Global.current_book
	_accent = BOOK_COLORS.get(_book, Color("#2563EB"))

	_build_ui()

	Global.on_theme_changed(_on_theme_changed)
	_apply_theme()

	# Gentle entrance.
	var tw := create_tween()
	tw.tween_property(_scroll, "modulate:a", 1.0, 0.30) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_scroll.modulate.a = 0.0


func _build_ui() -> void:
	# ---- Scrollable content (behind the fixed header) ----
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_top = 0.0
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_scroll)

	# ---- Header bar (fixed on top, renders OVER the scroll) ----
	var header := PanelContainer.new()
	header.name = "HeaderBar"
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.offset_bottom = 260.0
	header.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(header)

	var h_margin := MarginContainer.new()
	h_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h_margin.add_theme_constant_override("margin_left", 36)
	h_margin.add_theme_constant_override("margin_right", 36)
	h_margin.add_theme_constant_override("margin_top", 60)
	h_margin.add_theme_constant_override("margin_bottom", 24)
	header.add_child(h_margin)

	var h_row := HBoxContainer.new()
	h_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h_row.add_theme_constant_override("separation", 20)
	h_margin.add_child(h_row)

	# Back button sits on the LEFT; the title column is centred between it
	# and a right-hand spacer that mirrors the button's width.
	_back_button = MenuStyle.make_back_button(BACK_ICON, 132)
	_back_button.pressed.connect(_on_back_button_pressed)
	MenuStyle.wire_microinteractions(_back_button)
	h_row.add_child(_back_button)

	var title_col := VBoxContainer.new()
	title_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_col.add_theme_constant_override("separation", 4)
	title_col.alignment = BoxContainer.ALIGNMENT_CENTER

	_title_label = Label.new()
	_title_label.text = MenuStyle.persian_digits("ویژن %d" % _book)
	_title_label.add_theme_font_override("font", MenuStyle.vazir())
	_title_label.add_theme_font_size_override("font_size", 72)
	_title_label.add_theme_color_override("font_color", _accent)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_col.add_child(_title_label)

	_count_badge = MenuStyle.pill_label(
		MenuStyle.persian_digits("%d درس" % LESSON_DATA.get(_book, []).size()),
		_accent, 30
	)
	_count_badge.custom_minimum_size = Vector2(0, 56)
	_count_badge.add_theme_stylebox_override("normal", MenuStyle.icon_chip(_accent, 26))
	_count_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_col.add_child(_count_badge)

	h_row.add_child(title_col)

	# A right-hand spacer mirrors the back button's width so the title
	# column stays perfectly centred in the header.
	var right_pad := Control.new()
	right_pad.custom_minimum_size = Vector2(132, 1)
	h_row.add_child(right_pad)

	# ---- Scrollable content (starts below the fixed header) ----
	var outer := MarginContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_theme_constant_override("margin_left", 40)
	outer.add_theme_constant_override("margin_right", 40)
	outer.add_theme_constant_override("margin_top", 260)
	outer.add_theme_constant_override("margin_bottom", 72)
	_scroll.add_child(outer)

	_col = VBoxContainer.new()
	_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_col.add_theme_constant_override("separation", 20)
	outer.add_child(_col)

	var hero := Label.new()
	hero.text = "یک درس را انتخاب کنید 👇"
	hero.add_theme_font_override("font", MenuStyle.vazir())
	hero.add_theme_font_size_override("font_size", 40)
	hero.add_theme_color_override("font_color", MenuStyle.text_dim())
	hero.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero.custom_minimum_size = Vector2(0, 72)
	_col.add_child(hero)

	var lessons: Array = LESSON_DATA.get(_book, [])
	for i in lessons.size():
		var lesson_title: String = lessons[i]
		var digit: String = PERSIAN_DIGITS[i] if i < PERSIAN_DIGITS.size() else str(i + 1)
		var card: Button = MenuStyle.make_card(
			"درس %s" % digit,
			lesson_title,
			digit,
			_accent,
			150,
			"",
			true
		)
		card.pressed.connect(_on_lesson_pressed.bind(i + 1))
		MenuStyle.wire_microinteractions(card)
		_col.add_child(card)
		_card_buttons.append(card)

	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.custom_minimum_size = Vector2(0, 40)
	_col.add_child(spacer)

	_col.add_child(MenuStyle.make_tip_card("هر روز کمی یاد بگیر — موفق باشی ✨", "💡"))


############################################################
# THEME
############################################################
func _on_theme_changed(_mode: int) -> void:
	if not is_inside_tree():
		return
	_apply_theme()


func _apply_theme() -> void:
	if not is_inside_tree():
		return
	if _title_label:
		_title_label.add_theme_color_override("font_color", _accent)
	if _count_badge:
		_count_badge.add_theme_stylebox_override("normal", MenuStyle.icon_chip(_accent, 26))
		_count_badge.add_theme_color_override("font_color", MenuStyle.pill_text(_accent))
	# Header bar background (flat — no drop shadow).
	var header: PanelContainer = get_node_or_null("HeaderBar") as PanelContainer
	if header:
		header.add_theme_stylebox_override("panel", MenuStyle.header_bar_style(44, true))
	# Cards (flat — no elevation).
	for btn in _card_buttons:
		btn.add_theme_stylebox_override("normal", MenuStyle.card_style(_accent, 26, false, true))
		btn.add_theme_stylebox_override("hover", MenuStyle.card_hover_style(_accent, 26, true))
		btn.add_theme_stylebox_override("pressed", MenuStyle.card_pressed_style(_accent, 26, true))
		btn.add_theme_stylebox_override("focus", MenuStyle.card_hover_style(_accent, 26, true))
		var tl: Label = btn.get_node_or_null("Margin/Row/TextColumn/TitleLabel") as Label
		if tl:
			tl.add_theme_color_override("font_color", MenuStyle.text())
		var sl: Label = btn.get_node_or_null("Margin/Row/TextColumn/SubLabel") as Label
		if sl:
			sl.add_theme_color_override("font_color", MenuStyle.subtitle_color())
		# Rebuild hover/press via a fresh wired pass is unnecessary — the
		# micro-interactions tween scale only, so styleboxes are enough.


############################################################
# NAVIGATION
############################################################
func _on_lesson_pressed(lesson_number: int) -> void:
	if _navigating:
		return
	_navigating = true
	Global.current_lesson = lesson_number
	await get_tree().create_timer(0.10).timeout
	if not is_inside_tree():
		return
	TransitionManager.slide_change_scene(SCENE_LESSON_MENU, TransitionManager.Slide.FORWARD)


func _on_back_button_pressed() -> void:
	if _navigating:
		return
	_navigating = true
	await get_tree().create_timer(0.10).timeout
	if not is_inside_tree():
		return
	TransitionManager.slide_change_scene(SCENE_MAIN_MENU, TransitionManager.Slide.BACK)


func _on_android_back_pressed() -> void:
	_on_back_button_pressed()
