extends "res://autoload/BackButtonHandler.gd"

############################################################
# BOOK MENU — modern, friendly lesson picker.
# Reads Global.current_book to build lesson cards.
# Navigation uses the SLIDE transition (book -> lesson spine).
# Background uses handover unblur from BookSelection.
############################################################

const SCENE_BOOK_SELECTION := "res://scenes/book_menu/BookSelection.tscn"
const SCENE_LESSON_MENU    := "res://scenes/lesson_menu/LessonMenu.tscn"
const BACK_ICON            := "res://ui/images/Back.png"

const LESSON_TITLES_EN := {
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

const LESSON_TITLES_FA := {
	1: [
		"نجات طبیعت",
		"شگفتی‌های آفرینش",
		"ارزش دانش",
		"سفر به دور دنیا",
	],
	2: [
		"درک مردم",
		"سبک زندگی سالم",
		"هنر و فرهنگ",
	],
	3: [
		"حس قدردانی",
		"جستجو کن!",
		"انرژی تجدیدپذیر",
	],
}

const BOOK_COLORS := {
	1: Color("#3B82F6"),   # Vision 1 — solid light blue
	2: Color("#22C55E"),   # Vision 2 — solid green
	3: Color("#EF4444"),   # Vision 3 — solid red
}

const PERSIAN_DIGITS := ["۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹", "۱۰"]

const BG_UNBLUR_TIME := 0.55
const CONTENT_FADE_TIME := 0.40

const HEADER_HEIGHT := 240.0
const HEADER_RADIUS := 35
const HEADER_PAD_X := 60
const HEADER_LABEL_HEIGHT := 70
const HEADER_LABEL_SIZE := 40
const HEADER_GAP := 48
const HEADER_TEXT := "یک درس را انتخاب کنید 👇"
const CARD_RADIUS := 26

var _navigating: bool = false
var _book: int = 1
var _accent: Color = Color("#3B82F6")

# Built UI state.
var _scroll: ScrollContainer = null
var _col: VBoxContainer = null
var _header: PanelContainer = null
var _title_label: Label = null
var _back_button: Button = null
var _card_buttons: Array[Button] = []
var _bg_blur: TextureRect = null
var _bg_clear: TextureRect = null


func _ready() -> void:
	_book = Global.current_book
	_accent = BOOK_COLORS.get(_book, Color("#2563EB"))

	_build_ui()
	_animate_background_in()

	var current := get_tree().current_scene
	Global.set_last_scene(current.scene_file_path if current != null else scene_file_path)

	Global.on_theme_changed(_on_theme_changed)
	_apply_theme()

	# Gentle entrance: header and content fade in together
	_scroll.modulate.a = 0.0
	_header.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_scroll, "modulate:a", 1.0, CONTENT_FADE_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_header, "modulate:a", 1.0, CONTENT_FADE_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _animate_background_in() -> void:
	if _bg_clear == null:
		return
	_bg_clear.modulate.a = 0.0
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_bg_clear, "modulate:a", 1.0, BG_UNBLUR_TIME)
	tw.tween_callback(_on_background_sharpened)


func _on_background_sharpened() -> void:
	if is_instance_valid(_bg_blur):
		_bg_blur.visible = false
		_bg_blur.texture = null


func _make_background_still(still_name: String, texture_path: String) -> TextureRect:
	var still := TextureRect.new()
	still.name = still_name
	still.set_anchors_preset(Control.PRESET_FULL_RECT)
	still.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	still.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	still.mouse_filter = Control.MOUSE_FILTER_IGNORE
	still.texture = load(texture_path)
	return still


func _build_ui() -> void:
	var bg_layer := CanvasLayer.new()
	bg_layer.name = "BackgroundLayer"
	bg_layer.layer = -1

	_bg_blur = _make_background_still(
		"BackgroundBlur",
		"res://ui/images/book_scene/Vision%d_blur.png" % _book
	)
	bg_layer.add_child(_bg_blur)

	_bg_clear = _make_background_still(
		"BackgroundClear",
		"res://ui/images/book_scene/Vision%d.png" % _book
	)
	bg_layer.add_child(_bg_clear)

	add_child(bg_layer)

	# ---- Scrollable content ----
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_top = 0.0
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_scroll)

	var outer := MarginContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_theme_constant_override("margin_left", 40)
	outer.add_theme_constant_override("margin_right", 40)
	outer.add_theme_constant_override("margin_top", int(HEADER_HEIGHT) + HEADER_GAP)
	outer.add_theme_constant_override("margin_bottom", 170)
	_scroll.add_child(outer)

	_col = VBoxContainer.new()
	_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_col.add_theme_constant_override("separation", 18)
	outer.add_child(_col)

	var lessons_en: Array = LESSON_TITLES_EN.get(_book, [])
	var lessons_fa: Array = LESSON_TITLES_FA.get(_book, [])
	for i in lessons_en.size():
		var lesson_title_en: String = lessons_en[i]
		var lesson_title_fa: String = lessons_fa[i] if i < lessons_fa.size() else ""
		var digit: String = PERSIAN_DIGITS[i] if i < PERSIAN_DIGITS.size() else str(i + 1)

		var card: Button = MenuStyle.make_card(
			lesson_title_en,
			"درس %s: %s" % [digit, lesson_title_fa],
			digit,
			_accent,
			150
		)
		card.pressed.connect(_on_lesson_pressed.bind(i + 1))
		MenuStyle.wire_microinteractions(card)
		MenuStyle.style_gloss_card(card, _accent, CARD_RADIUS)
		_col.add_child(card)
		_card_buttons.append(card)

	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.custom_minimum_size = Vector2(0, 40)
	_col.add_child(spacer)

	_col.add_child(MenuStyle.make_tip_card("درس مورد نظرت را انتخاب کن و یادگیری را شروع کن ✨", "💡"))

	_build_header()


func _build_header() -> void:
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = MenuStyle.surface()
	bar_style.corner_radius_bottom_left = HEADER_RADIUS
	bar_style.corner_radius_bottom_right = HEADER_RADIUS

	_header = PanelContainer.new()
	_header.name = "HeaderBar"
	_header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_header.offset_bottom = HEADER_HEIGHT
	_header.mouse_filter = Control.MOUSE_FILTER_PASS
	_header.add_theme_stylebox_override("panel", bar_style)
	add_child(_header)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_theme_constant_override("margin_left", HEADER_PAD_X)
	margin.add_theme_constant_override("margin_right", HEADER_PAD_X)
	margin.add_theme_constant_override("margin_top", 60)
	margin.add_theme_constant_override("margin_bottom", 24)
	_header.add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(row)

	_back_button = MenuStyle.make_back_button(BACK_ICON, 100)
	_back_button.pressed.connect(_on_android_back_pressed)
	MenuStyle.wire_microinteractions(_back_button)
	row.add_child(_back_button)

	var title_col := VBoxContainer.new()
	title_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(title_col)

	_title_label = Label.new()
	_title_label.text = HEADER_TEXT
	_title_label.add_theme_font_override("font", MenuStyle.vazir())
	_title_label.add_theme_font_size_override("font_size", HEADER_LABEL_SIZE)
	_title_label.add_theme_color_override("font_color", _accent)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.custom_minimum_size = Vector2(0, HEADER_LABEL_HEIGHT)
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_col.add_child(_title_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(100, 1)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)


func _on_theme_changed(_mode: int) -> void:
	if not is_inside_tree():
		return
	_apply_theme()


func _apply_theme() -> void:
	if not is_inside_tree():
		return
	_accent = BOOK_COLORS.get(_book, MenuStyle.accent())
	if _title_label:
		_title_label.add_theme_color_override("font_color", _accent)
	for btn: Button in _card_buttons:
		MenuStyle.style_gloss_card(btn, _accent, CARD_RADIUS)
		var tl: Label = btn.get_node_or_null("Margin/Row/TextColumn/TitleLabel") as Label
		if tl:
			tl.add_theme_color_override("font_color", MenuStyle.text())
		var sl: Label = btn.get_node_or_null("Margin/Row/TextColumn/SubLabel") as Label
		if sl:
			sl.add_theme_color_override("font_color", MenuStyle.subtitle_color())


func _on_lesson_pressed(lesson_number: int) -> void:
	if _navigating:
		return
	_navigating = true
	Global.current_lesson = lesson_number
	Content.ensure_lesson(_book, lesson_number)
	await get_tree().create_timer(0.10).timeout
	if not is_inside_tree():
		return
	TransitionManager.slide_change_scene(SCENE_LESSON_MENU, TransitionManager.Slide.FORWARD)


func _on_android_back_pressed() -> void:
	if _navigating:
		return
	_navigating = true
	await get_tree().create_timer(0.10).timeout
	if not is_inside_tree():
		return
	TransitionManager.slide_change_scene(SCENE_BOOK_SELECTION, TransitionManager.Slide.BACK)
