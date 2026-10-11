class_name GrammarExam
extends "res://autoload/BackButtonHandler.gd"
# ============================================================
#  GRAMMAR EXAM — امتحان گرامر
#  Reached from the Grammar Hub's "امتحان گرامر" button.
#  ------------------------------------------------------------
#  Content is authored in a JSON file and rendered with the
#  shared ExerciseEngine. Each section of the JSON becomes one
#  engine with its own per-item "Check" hidden (hide_footer_buttons),
#  and the scene exposes a single global "بررسی پاسخ‌ها" button.
#  When pressed, every engine is graded and the total score is
#  shown out of 100 in a centered popup.
#
#  Content is loaded per book/lesson from a JSON file named
#  v{book}_l{lesson}_grammar_exam.json inside res://data/grammar/,
#  e.g. res://data/grammar/v1_l1_grammar_exam.json or
#  res://data/grammar/v3_l2_grammar_exam.json.
# ============================================================

const SCENE_HUB: String = "res://scenes/grammar/GrammarHub.tscn"
const DATA_DIR: String = "res://data/grammar/"

var _navigating: bool = false
var _engines: Array = []          # ExerciseEngine instances (one per section)
var _correct_total: int = 0       # accumulated correct answers
var _items_total: int = 0         # accumulated question count
var _check_btn: Button = null
var _score_overlay: Control = null
var _manual_writing_total: int = 0
var _writing_score_input: SpinBox = null
var _page_view: PageView = null


func _ready() -> void:
	super._ready()
	MenuBackground.enter_background()
	_build_ui()


# ============================================================
# DATA
# ============================================================
# Builds the per-book/lesson JSON path, e.g. v1_l1_grammar_exam.json
# or v3_l2_grammar_exam.json based on the current Global state.
func _data_path() -> String:
	return "%sv%d_l%d_grammar_exam.json" % [DATA_DIR, Global.current_book, Global.current_lesson]


func _load_data() -> Dictionary:
	var path := _data_path()
	if not FileAccess.file_exists(path):
		push_error("Grammar exam JSON not found: " + path)
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var text: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		push_error("Grammar exam JSON parse error: " + json.get_error_message())
		return {}
	var data: Variant = json.data
	if data is Dictionary:
		return data
	return {}


# Flattens the exam file into an ordered list of content blocks, supporting
# both the newer "lessons -> exam_exercises" layout (with "h4" heading blocks)
# and the older "exam -> sections" layout.
func _extract_blocks(data: Dictionary) -> Array:
	if data.has("lessons"):
		var blocks: Array = []
		var lessons: Array = data["lessons"]
		for lesson in lessons:
			if lesson is Dictionary:
				var exam_exercises: Array = lesson.get("exam_exercises", [])
				for b in exam_exercises:
					blocks.append(b)
		return blocks
	if data.has("exam"):
		var exam: Dictionary = data["exam"]
		return exam.get("sections", [])
	return []


func _build_ui() -> void:
	var data: Dictionary = _load_data()
	var blocks: Array = _extract_blocks(data)

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

	var page_host: Control = Control.new()
	page_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(page_host)

	_page_view = PageView.new()
	_page_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_page_view.tab_font_size = 28
	_page_view.tab_font_min = 20
	page_host.add_child(_page_view)

	if blocks.is_empty():
		var empty_page: VBoxContainer = VBoxContainer.new()
		_show_empty_message(empty_page)
		_page_view.add_page("empty", "آزمون", "📄", empty_page)
	else:
		_build_exam_pages(data, blocks)


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

	var back_button: Button = GrammarTheme.make_header_icon_button("res://assets/images/ui/Back.png", Callable(self, "_on_back_pressed"))
	header_row.add_child(back_button)

	var font: Font = GrammarTheme.get_fa_bold()
	var title_label: Label = Label.new()
	GrammarTheme.set_bidi_text(title_label, str(data.get("title_fa", "امتحان گرامر")))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if font != null:
		title_label.add_theme_font_override("font", font)
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.add_theme_color_override("font_color", GrammarTheme.text_color())
	header_row.add_child(title_label)

	# Same item grid as every other header in the app.
	GrammarTheme.unify_header_row(header_row)


# ============================================================
# CONTENT
# ============================================================
func _build_exam_pages(data: Dictionary, blocks: Array) -> void:
	var section_pages: Array[Dictionary] = []
	var current: Dictionary = {"title": "آزمون", "blocks": []}

	for block_value in blocks:
		if not block_value is Dictionary:
			continue
		var block: Dictionary = block_value
		if str(block.get("type", "")) == "h4":
			if not (current["blocks"] as Array).is_empty():
				section_pages.append(current)
			current = {"title": str(block.get("text", "بخش")), "blocks": []}
		else:
			(current["blocks"] as Array).append(block)

	if not (current["blocks"] as Array).is_empty():
		section_pages.append(current)

	var next_letter_index: int = 0
	for index in section_pages.size():
		var section: Dictionary = section_pages[index]
		var content: VBoxContainer = VBoxContainer.new()
		content.add_theme_constant_override("separation", GrammarTheme.SPACING_LG)
		next_letter_index = _build_exam_content(
			content,
			data,
			section["blocks"] as Array,
			index == 0,
			index == section_pages.size() - 1,
			next_letter_index
		)
		_page_view.add_page("section_%d" % index, _page_title(str(section["title"])), "", content)


func _page_title(source: String) -> String:
	var title: String = source.strip_edges()
	var separator_index: int = title.find("—")
	if separator_index >= 0:
		title = title.substr(0, separator_index).strip_edges()
	if title.is_empty():
		return "آزمون"
	return title


func _build_exam_content(
	content: VBoxContainer,
	data: Dictionary,
	blocks: Array,
	show_exam_instruction: bool,
	is_last_page: bool,
	letter_index: int
) -> int:
	if show_exam_instruction:
		var instruction: Label = Label.new()
		instruction.text = "لطفاً به همهٔ سؤال‌ها پاسخ دهید. برای مشاهدهٔ نمره و بازخورد، در صفحهٔ آخر روی دکمهٔ «بررسی پاسخ‌ها» بزنید."
		instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		instruction.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		instruction.add_theme_font_size_override("font_size", 28)
		instruction.add_theme_color_override("font_color", GrammarTheme.text_muted_color())
		var instruction_font: Font = GrammarTheme.get_fa_regular()
		if instruction_font != null:
			instruction.add_theme_font_override("font", instruction_font)
		content.add_child(instruction)

	var subtitle: Label = Label.new()
	GrammarTheme.set_bidi_text(subtitle, str(data.get("subtitle_fa", "")))
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var body_font: Font = GrammarTheme.get_fa_regular()
	if body_font != null:
		subtitle.add_theme_font_override("font", body_font)
	subtitle.add_theme_font_size_override("font_size", 28)
	subtitle.add_theme_color_override("font_color", GrammarTheme.text_muted_color())
	if not str(data.get("subtitle_fa", "")).is_empty():
		content.add_child(subtitle)

	for block_value in blocks:
		if not block_value is Dictionary:
			continue
		var block: Dictionary = block_value
		var type: String = str(block.get("type", ""))
		var exercise_block: Dictionary = block.duplicate(true)
		if bool(exercise_block.get("show_letter", true)) and _has_instruction_text(block):
			exercise_block["letter_index"] = letter_index
			letter_index += 1

		var engine: ExerciseEngine = ExerciseEngine.new()
		engine.hide_footer_buttons = true
		engine.size_flags_horizontal = Control.SIZE_EXPAND_FILL | Control.SIZE_SHRINK_BEGIN
		engine.custom_minimum_size.x = 0
		content.add_child(engine)
		engine.build(exercise_block)
		var points_per_item: int = int(block.get("points_per_item", 1))
		engine.exercise_checked.connect(_on_exercise_checked.bind(points_per_item))
		if type in ["open_ended", "pronunciation", "writing"]:
			_manual_writing_total += int(block.get("score_points", 0))
		elif not type in ["passage", "reading"]:
			_engines.append(engine)

	if not is_last_page or _engines.is_empty():
		return letter_index

	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	content.add_child(spacer)

	_check_btn = Button.new()
	_check_btn.text = "بررسی پاسخ‌ها"
	_check_btn.custom_minimum_size = Vector2(0, 112)
	_check_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GrammarTheme.style_primary_button(_check_btn)
	_check_btn.add_theme_font_size_override("font_size", 46)
	_check_btn.pressed.connect(_on_check_pressed)
	content.add_child(_check_btn)

	if _manual_writing_total <= 0:
		return letter_index
	var grading_note: Label = Label.new()
	grading_note.text = "Writing score (self-assessment / teacher) — 0–%d" % _manual_writing_total
	grading_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grading_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	grading_note.custom_minimum_size = Vector2(0, 64)
	grading_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grading_note.add_theme_font_size_override("font_size", 24)
	grading_note.add_theme_color_override("font_color", GrammarTheme.text_muted_color())
	content.add_child(grading_note)

	_writing_score_input = SpinBox.new()
	_writing_score_input.min_value = 0
	_writing_score_input.max_value = _manual_writing_total
	_writing_score_input.step = 1
	_writing_score_input.value = 0
	_writing_score_input.custom_minimum_size = Vector2(240, 72)
	_writing_score_input.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_writing_score_input.add_theme_font_size_override("font_size", 24)
	content.add_child(_writing_score_input)

	var score_hint: Label = Label.new()
	score_hint.text = "Enter a manual score here. It is not included in the automatic result."
	score_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	score_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score_hint.add_theme_font_size_override("font_size", 21)
	score_hint.add_theme_color_override("font_color", GrammarTheme.text_muted_color())
	content.add_child(score_hint)

	var score_notice: Label = Label.new()
	score_notice.text = "Manual score is not included in the automatic result."
	score_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	score_notice.add_theme_font_size_override("font_size", 21)
	score_notice.add_theme_color_override("font_color", GrammarTheme.text_muted_color())
	content.add_child(score_notice)
	return letter_index


# Renders a bold section divider (the JSON "h4" blocks, e.g. "Part 1 — ...").
func _has_instruction_text(block: Dictionary) -> bool:
	var instruction: Variant = block.get("instruction", "")
	if instruction is Dictionary:
		return not str(instruction.get("en", instruction.get("fa", ""))).is_empty()
	return not str(instruction).is_empty()


func _add_section_header(content: VBoxContainer, block: Dictionary) -> void:
	var header: Label = Label.new()
	GrammarTheme.set_bidi_text(header, str(block.get("text", "")))
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var bold: Font = GrammarTheme.get_fa_bold()
	if bold != null:
		header.add_theme_font_override("font", bold)
	header.add_theme_font_size_override("font_size", 34)
	header.add_theme_color_override("font_color", GrammarTheme.accent_color())
	content.add_child(header)


func _show_empty_message(content: VBoxContainer) -> void:
	var empty: Label = Label.new()
	empty.text = "🎓\nهنوز سوالی در امتحان این درس نیست.\n\nلطفاً فایل زیر را با سوال پر کنید:\n" + _data_path()
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
# GRADING
# ============================================================
func _on_exercise_checked(_id: String, correct: int, total: int, points_per_item: int = 1) -> void:
	_correct_total += correct * points_per_item
	_items_total += total * points_per_item


func _on_check_pressed() -> void:
	if _engines.is_empty():
		return
	_correct_total = 0
	_items_total = 0
	for engine in _engines:
		# Public API: grades every item in place (never enters the engine's
		# retry/rebuild path) and re-emits exercise_checked for scoring.
		engine.grade_all()
	_check_btn.disabled = true
	_check_btn.text = "پاسخ‌ها بررسی شد ✓"

	var score: int = 0
	var maximum_score: int = _items_total
	var earned_score: int = _correct_total
	if maximum_score > 0:
		score = int(round(float(earned_score) / float(maximum_score) * 100.0))
	_show_score_popup(score)


func _show_score_popup(score: int) -> void:
	if _score_overlay != null and is_instance_valid(_score_overlay):
		_score_overlay.queue_free()
	_score_overlay = Control.new()
	_score_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_score_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_score_overlay)

	# Dim background.
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_score_overlay.add_child(dim)

	# Centered popup card.
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_score_overlay.add_child(center)

	var card: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = GrammarTheme.card_style()
	style.set_content_margin_all(GrammarTheme.CONTENT_MARGIN)
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size = Vector2(560, 480)
	center.add_child(card)

	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 20)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vb)

	var icon: Label = Label.new()
	icon.text = "🎓"
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 84)
	vb.add_child(icon)

	var head: Label = Label.new()
	head.text = "نمرهٔ شما"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var bold: Font = GrammarTheme.get_fa_bold()
	if bold != null:
		head.add_theme_font_override("font", bold)
	head.add_theme_font_size_override("font_size", 40)
	head.add_theme_color_override("font_color", GrammarTheme.text_color())
	vb.add_child(head)

	var score_label: Label = Label.new()
	score_label.text = "%d / 100" % score
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if bold != null:
		score_label.add_theme_font_override("font", bold)
	score_label.add_theme_font_size_override("font_size", 96)
	score_label.add_theme_color_override(
		"font_color",
		GrammarTheme.success_color() if score >= 50 else GrammarTheme.error_color()
	)
	vb.add_child(score_label)

	# A short encouraging line.
	var note: Label = Label.new()
	if score >= 80:
		note.text = "عالی! 👏"
	elif score >= 50:
		note.text = "خوب بود، ادامه بده! 💪"
	else:
		note.text = "دوباره تمرین کن تا بهتر شوی! 📚"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if bold != null:
		note.add_theme_font_override("font", bold)
	note.add_theme_font_size_override("font_size", 30)
	note.add_theme_color_override("font_color", GrammarTheme.text_secondary_color())
	vb.add_child(note)

	var close_btn: Button = Button.new()
	close_btn.text = "بستن"
	close_btn.custom_minimum_size = Vector2(0, GrammarTheme.BUTTON_HEIGHT)
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GrammarTheme.style_primary_button(close_btn)
	close_btn.pressed.connect(func() -> void:
		if _score_overlay != null and is_instance_valid(_score_overlay):
			_score_overlay.queue_free()
			_score_overlay = null)
	vb.add_child(close_btn)


func _on_back_pressed() -> void:
	if _navigating:
		return
	_navigating = true
	TransitionManager.change_scene(SCENE_HUB)


func _on_android_back_pressed() -> void:
	_on_back_pressed()
