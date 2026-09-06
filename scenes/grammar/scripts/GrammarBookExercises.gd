class_name GrammarBookExercises
extends "res://autoload/BackButtonHandler.gd"
# ============================================================
#  BOOK EXERCISES — تمرینات کتاب
#  Reached from the Grammar Hub's "تمرینات کتاب" button.
#  ------------------------------------------------------------
#  Content is authored in a JSON file and rendered with the
#  shared ExerciseEngine. Each exercise keeps its own "بررسی
#  پاسخ" button (normal engine behavior).
#
#  Content is loaded per book/lesson from a JSON file named
#  v{book}_l{lesson}_book_exercises.json inside res://data/grammar/,
#  e.g. res://data/grammar/v1_l1_book_exercises.json.
# ============================================================

const SCENE_HUB: String = "res://scenes/grammar/GrammarHub.tscn"
const DATA_DIR: String = "res://data/grammar/"

var _navigating: bool = false
var _engines: Array = []


func _ready() -> void:
	super._ready()
	MenuBackground.enter_background()
	_build_ui()


# ============================================================
# DATA
# ============================================================
# Builds the per-book/lesson JSON path, e.g. v1_l1_book_exercises.json
# or v3_l2_book_exercises.json based on the current Global state.
func _data_path() -> String:
	return "%sv%d_l%d_book_exercises.json" % [DATA_DIR, Global.current_book, Global.current_lesson]


func _load_data() -> Dictionary:
	var path := _data_path()
	if not FileAccess.file_exists(path):
		push_error("Book exercises JSON not found: " + path)
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var text: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		push_error("Book exercises JSON parse error: " + json.get_error_message())
		return {}
	var data: Variant = json.data
	if data is Dictionary and (data as Dictionary).has("book_exercises"):
		return (data as Dictionary)["book_exercises"]
	return {}


# ============================================================
# SHELL UI
# ============================================================
func _build_ui() -> void:
	var data: Dictionary = _load_data()
	var sections: Array = data.get("sections", [])

	var root_margin: MarginContainer = MarginContainer.new()
	root_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_margin.mouse_filter = Control.MOUSE_FILTER_STOP
	root_margin.add_theme_constant_override("margin_left", GrammarTheme.SAFE_MARGIN)
	root_margin.add_theme_constant_override("margin_top", GrammarTheme.SAFE_MARGIN)
	root_margin.add_theme_constant_override("margin_right", GrammarTheme.SAFE_MARGIN)
	root_margin.add_theme_constant_override("margin_bottom", GrammarTheme.SAFE_MARGIN)
	add_child(root_margin)

	var main: VBoxContainer = VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 24)
	root_margin.add_child(main)

	_build_header(main, data)

	var content_box: PanelContainer = PanelContainer.new()
	GrammarTheme.style_card(content_box)
	content_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(content_box)

	var content_margin: MarginContainer = MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", GrammarTheme.CONTENT_MARGIN)
	content_margin.add_theme_constant_override("margin_top", GrammarTheme.CONTENT_MARGIN)
	content_margin.add_theme_constant_override("margin_right", GrammarTheme.CONTENT_MARGIN)
	content_margin.add_theme_constant_override("margin_bottom", GrammarTheme.CONTENT_MARGIN)
	content_box.add_child(content_margin)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_margin.add_child(scroll)

	var content: VBoxContainer = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", GrammarTheme.SPACING_LG)
	scroll.add_child(content)

	if sections.is_empty():
		_show_empty_message(content)
	else:
		_build_content(content, data, sections)


# ============================================================
# HEADER
# ============================================================
func _build_header(main: VBoxContainer, data: Dictionary) -> void:
	var header_box: PanelContainer = PanelContainer.new()
	GrammarTheme.style_header_box(header_box)
	main.add_child(header_box)

	var header_margin: MarginContainer = MarginContainer.new()
	header_margin.add_theme_constant_override("margin_left", 18)
	header_margin.add_theme_constant_override("margin_top", 14)
	header_margin.add_theme_constant_override("margin_right", 18)
	header_margin.add_theme_constant_override("margin_bottom", 14)
	header_box.add_child(header_margin)

	var header_row: HBoxContainer = HBoxContainer.new()
	header_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_theme_constant_override("separation", 16)
	header_margin.add_child(header_row)

	var back_button: Button = GrammarTheme.make_header_icon_button("res://images/Back.png", Callable(self, "_on_back_pressed"))
	header_row.add_child(back_button)

	var font: Font = GrammarTheme.get_fa_bold()
	var title_label: Label = Label.new()
	GrammarTheme.set_bidi_text(title_label, str(data.get("title_fa", "تمرینات کتاب")))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if font != null:
		title_label.add_theme_font_override("font", font)
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.add_theme_color_override("font_color", GrammarTheme.text_color())
	header_row.add_child(title_label)


# ============================================================
# CONTENT
# ============================================================
func _build_content(content: VBoxContainer, data: Dictionary, sections: Array) -> void:
	var subtitle: Label = Label.new()
	GrammarTheme.set_bidi_text(subtitle, str(data.get("subtitle_fa", "تمرین‌های این بخش را کامل کنید.")))
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var body_font: Font = GrammarTheme.get_fa_regular()
	if body_font != null:
		subtitle.add_theme_font_override("font", body_font)
	subtitle.add_theme_font_size_override("font_size", 28)
	subtitle.add_theme_color_override("font_color", GrammarTheme.text_muted_color())
	content.add_child(subtitle)

	for section in sections:
		var engine: ExerciseEngine = ExerciseEngine.new()
		content.add_child(engine)
		engine.build(section)
		_engines.append(engine)

	# Bottom spacer.
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 80)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(spacer)


func _show_empty_message(content: VBoxContainer) -> void:
	var empty: Label = Label.new()
	empty.text = "📘\nهنوز تمرینی در این بخش برای این درس نیست.\n\nلطفاً فایل زیر را با تمرین پر کنید:\n" + _data_path()
	empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
	empty.add_theme_font_size_override("font_size", 28)
	empty.add_theme_color_override("font_color", GrammarTheme.text_muted_color())
	var font: Font = GrammarTheme.get_fa_regular()
	if font != null:
		empty.add_theme_font_override("font", font)
	content.add_child(empty)


# ============================================================
# NAVIGATION
# ============================================================
func _on_back_pressed() -> void:
	if _navigating:
		return
	_navigating = true
	TransitionManager.change_scene(SCENE_HUB)


func _on_android_back_pressed() -> void:
	_on_back_pressed()
