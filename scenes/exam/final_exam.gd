class_name FinalExam
extends "res://autoload/BackButtonHandler.gd"
## ============================================================
##  FINAL EXAM — اجرای یک امتحان نهایی
##
##  Renders one exam JSON (loaded from the path passed via the
##  AppRouter arg "exam_json") with the shared ExerciseEngine,
##  exactly like the grammar exam: per-item Check buttons are
##  hidden and a single global "بررسی پاسخ‌ها" button grades
##  everything at once.
##
##  SCORING (/40)
##  -------------
##  Every gradable block carries a "points" weight (its official
##  mark). A block's contribution is
##      points * (correct_items / total_items)
##  The raw earned total is scaled so the exam is out of 40:
##      score = round(40 * earned / gradable_points)
##  Blocks that cannot be auto-graded (writing paragraphs /
##  open-ended items) carry points 0 and are shown for practice
##  only, so they never affect the auto-score.
## ============================================================

const BACK_ICON: String = "res://images/Back.png"
const HOME_ICON: String = "res://images/Main_Menu.png"
const SCORE_MAX: float = 40.0

var _navigating: bool = false
var _exam: Dictionary = {}
var _engines: Array = []                 # gradable ExerciseEngine instances
var _points_by_id: Dictionary = {}       # exercise_id -> points weight
var _results: Dictionary = {}            # exercise_id -> {correct, total}
var _check_btn: Button = null
var _score_overlay: Control = null
var _audio_panel: PanelContainer = null
var _audio_button: Button = null
var _audio_path: String = ""
var _page_view: PageView = null


func _ready() -> void:
	super._ready()
	MenuBackground.enter_background()
	_exam = ExamData.load_exam(str(AppRouter.get_arg("exam_json", "")))
	_build_ui()


func _build_ui() -> void:
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

	_build_header(main)

	var page_host: Control = Control.new()
	page_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(page_host)

	_page_view = PageView.new()
	_page_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_page_view.tab_font_size = 26
	_page_view.tab_font_min = 18
	page_host.add_child(_page_view)

	var blocks: Array = _exam.get("blocks", [])
	if blocks.is_empty():
		var empty_page: VBoxContainer = VBoxContainer.new()
		_show_empty_message(empty_page)
		_page_view.add_page("empty", "آزمون", "📄", empty_page)
		return

	_build_exam_pages(blocks)


func _build_header(main: VBoxContainer) -> void:
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

	var back_button: Button = GrammarTheme.make_header_icon_button(BACK_ICON, Callable(self, "_on_back_pressed"))
	header_row.add_child(back_button)

	var home_button: Button = GrammarTheme.make_header_icon_button(HOME_ICON, Callable(self, "_on_main_menu_pressed"))
	header_row.add_child(home_button)

	var title_label: Label = Label.new()
	var title: String = str(_exam.get("title_fa", AppRouter.get_arg("title_fa", "امتحان نهایی")))
	GrammarTheme.set_bidi_text(title_label, title)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var title_font: Font = GrammarTheme.get_fa_bold()
	if title_font != null:
		title_label.add_theme_font_override("font", title_font)
	title_label.add_theme_font_size_override("font_size", 34)
	title_label.add_theme_color_override("font_color", GrammarTheme.text_color())
	header_row.add_child(title_label)

	GrammarTheme.unify_header_row(header_row)


func _build_audio_button(content: VBoxContainer) -> void:
	if _audio_path.is_empty():
		return
	_audio_button = Button.new()
	_audio_button.text = "▶  Play Audio"
	_audio_button.custom_minimum_size = Vector2(0, 96)
	_audio_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GrammarTheme.style_primary_button(_audio_button)
	_audio_button.add_theme_font_size_override("font_size", 38)
	_audio_button.pressed.connect(_on_audio_pressed)
	content.add_child(_audio_button)

	var packed_audio: PackedScene = load("res://scenes/shared/AudioPanel.tscn") as PackedScene
	if packed_audio == null:
		push_error("FinalExam: AudioPanel scene could not be loaded")
		_audio_button.disabled = true
		return
	_audio_panel = packed_audio.instantiate() as PanelContainer
	if _audio_panel == null:
		_audio_button.disabled = true
		return
	add_child(_audio_panel)
	_page_view.add_swipe_blocker(_audio_panel)
	_audio_panel.audio_closed.connect(_on_audio_closed)
	_audio_panel.audio_finished.connect(_on_audio_closed)


func _on_audio_pressed() -> void:
	if _audio_panel == null or _audio_path.is_empty():
		return
	_audio_panel.load_and_play(_audio_path)
	_audio_button.text = "⏸  Pause Audio"


func _on_audio_closed() -> void:
	if _audio_button != null and is_instance_valid(_audio_button):
		_audio_button.text = "▶  Play Audio"


func _build_exam_pages(blocks: Array) -> void:
	var sections: Array[Dictionary] = []
	var current: Dictionary = {"title": "آزمون", "blocks": []}
	for block_value in blocks:
		var block: Dictionary = block_value as Dictionary
		if str(block.get("type", "")) == "h4":
			if not (current["blocks"] as Array).is_empty():
				sections.append(current)
			current = {"title": str(block.get("text", "بخش")), "blocks": []}
		else:
			(current["blocks"] as Array).append(block)
	if not (current["blocks"] as Array).is_empty():
		sections.append(current)

	for index in sections.size():
		var section: Dictionary = sections[index]
		var content: VBoxContainer = VBoxContainer.new()
		content.add_theme_constant_override("separation", GrammarTheme.SPACING_LG)
		var section_title: String = _english_section_title(str(section["title"]))
		if section_title == "Listening":
			_audio_path = _find_section_audio(section["blocks"] as Array)
			_build_audio_button(content)
		for block_value in section["blocks"] as Array:
			var block: Dictionary = block_value as Dictionary
			var engine: ExerciseEngine = ExerciseEngine.new()
			engine.hide_footer_buttons = true
			engine.audio_allow_any_type = false
			content.add_child(engine)
			var engine_block: Dictionary = block.duplicate(true)
			engine_block["show_audio"] = false
			engine.build(engine_block)
			var points: float = float(block.get("points", 0))
			if points > 0.0:
				var ex_id: String = str(block.get("exercise_id", ""))
				if not ex_id.is_empty():
					_points_by_id[ex_id] = points
					engine.exercise_checked.connect(_on_exercise_checked)
					_engines.append(engine)
		if index == sections.size() - 1 and not _engines.is_empty():
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
		_page_view.add_page("section_%d" % index, section_title, "", content)


func _english_section_title(source: String) -> String:
	var text: String = source.split("—", true, 1)[0].strip_edges()
	if text.is_empty():
		return "Section"
	return text


func _find_section_audio(blocks: Array) -> String:
	for block_value in blocks:
		var block: Dictionary = block_value as Dictionary
		var path: String = str(block.get("audio", ""))
		if not path.is_empty():
			return path
	return ""


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
	empty.text = "📄\nاطلاعات این آزمون یافت نشد."
	empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
	empty.add_theme_font_size_override("font_size", 30)
	empty.add_theme_color_override("font_color", GrammarTheme.text_muted_color())
	content.add_child(empty)


# ============================================================
# GRADING
# ============================================================
func _on_exercise_checked(exercise_id: String, correct: int, total: int) -> void:
	_results[exercise_id] = {"correct": correct, "total": total}


func _on_check_pressed() -> void:
	if _engines.is_empty():
		return
	_results.clear()
	for engine in _engines:
		engine.grade_all()
	_check_btn.disabled = true
	_check_btn.text = "پاسخ‌ها بررسی شد ✓"

	var earned: float = 0.0
	var gradable: float = 0.0
	for ex_id in _points_by_id.keys():
		var points: float = float(_points_by_id[ex_id])
		gradable += points
		if _results.has(ex_id):
			var res: Dictionary = _results[ex_id]
			var total: int = int(res.get("total", 0))
			var correct: int = int(res.get("correct", 0))
			if total > 0:
				earned += points * (float(correct) / float(total))

	var score: float = 0.0
	if gradable > 0.0:
		score = SCORE_MAX * earned / gradable
	_show_score_popup(snappedf(score, 0.25))


func _show_score_popup(score: float) -> void:
	if _score_overlay != null and is_instance_valid(_score_overlay):
		_score_overlay.queue_free()
	_score_overlay = Control.new()
	_score_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_score_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_score_overlay)

	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_score_overlay.add_child(dim)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_score_overlay.add_child(center)

	var card: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = GrammarTheme.card_style()
	style.set_content_margin_all(GrammarTheme.CONTENT_MARGIN)
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size = Vector2(580, 500)
	center.add_child(card)

	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
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
	score_label.text = _format_number(score) + " / ۴۰"
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if bold != null:
		score_label.add_theme_font_override("font", bold)
	score_label.add_theme_font_size_override("font_size", 96)
	score_label.add_theme_color_override(
		"font_color",
		GrammarTheme.success_color() if score >= SCORE_MAX / 2.0 else GrammarTheme.error_color()
	)
	vb.add_child(score_label)

	var note: Label = Label.new()
	if score >= SCORE_MAX * 0.8:
		note.text = "عالی! 👏"
	elif score >= SCORE_MAX * 0.5:
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


# Formats a float score: whole numbers without decimals, else one decimal.
func _format_number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return "%.1f" % value


func _on_back_pressed() -> void:
	if _navigating:
		return
	_navigating = true
	AppRouter.back("final_exam_list", {"year": _year_id()})


func _on_main_menu_pressed() -> void:
	if _navigating:
		return
	_navigating = true
	TransitionManager.change_scene("res://scenes/main_menu/MainMenu.tscn")


func _year_id() -> String:
	var id: String = str(_exam.get("id", ""))
	# Exam ids look like "12_khordad_1404"; the leading token is the grade.
	var parts: PackedStringArray = id.split("_")
	if parts.size() > 0:
		return parts[0]
	return "12"


func _on_android_back_pressed() -> void:
	_on_back_pressed()