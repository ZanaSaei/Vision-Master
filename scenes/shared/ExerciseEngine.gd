class_name ExerciseEngine
extends VBoxContainer

# ============================================================
# Universal interactive exercise renderer for Godot 4.7
# ============================================================
# Feed it any exercise Dictionary from JSON.
# It builds the UI, collects answers, and grades via "Check Answer".
#
# Supported types:
# - multiple_choice
# - true_false
# - matching
# - fill_blank
# - cloze
# - ordering
# - categorize
# - open_ended
# - pronunciation      alias for open_ended
# - writing            alias for open_ended
# - passage            non-interactive reading block
# - reading            alias for passage
# - word_bank
# - sentence_ordering
# - sentence_unscramble alias for sentence_ordering
# - letter_scramble
# - table_fill
# - table_fill_advanced
# - text_highlight
# - text_highlight_multi
# - transformation
# - error_correction
# - word_building
# - word_search
# - word_find          alias for word_search
# - chart_fill
# - odd_one_out
# - grammar_choice
# - passive_transformation
# - grammar_identification
# - question_formation
# - token_label
# - image_choice
# - image_match
# - image_hotspot
# ============================================================

signal exercise_checked(exercise_id: String, correct: int, total: int)

# ---------- Theme ----------
const C_PRIMARY := Color("#22D3EE")
const C_SUCCESS := Color("#34D399")
const C_ERROR   := Color("#F87171")
const C_TEXT    := Color("#F1F5F9")
const C_MUTED   := Color("#94A3B8")
const C_TINT    := Color("#1a2f5c")
const C_WARNING := Color("#FBBF24")
const C_INFO    := Color("#22D3EE")
const C_PURPLE  := Color("#A78BFA")

const FONT_REGULAR_PATH := "res://assets/fonts/PlusJakartaSans-Regular.ttf"
const FONT_BOLD_PATH    := "res://assets/fonts/PlusJakartaSans-Bold.ttf"

const TYPE_META := {
	"multiple_choice": { "badge": "Multiple Choice", "color": Color("#2563EB") },
	"true_false": { "badge": "True / False", "color": Color("#7C3AED") },
	"matching": { "badge": "Matching", "color": Color("#0891B2") },
	"fill_blank": { "badge": "Fill in the Blank", "color": Color("#EA580C") },
	"cloze": { "badge": "Choose the Best Form", "color": Color("#DB2777") },
	"ordering": { "badge": "Put in Order", "color": Color("#CA8A04") },
	"categorize": { "badge": "Categorize", "color": Color("#059669") },
	"open_ended": { "badge": "Your Turn", "color": Color("#64748B") },
	"pronunciation": { "badge": "Pronunciation", "color": Color("#64748B") },
	"writing": { "badge": "Writing", "color": Color("#64748B") },
	"passage": { "badge": "Reading", "color": Color("#334155") },
	"reading": { "badge": "Reading", "color": Color("#334155") },
	"word_bank": { "badge": "Word Bank", "color": Color("#0D9488") },
	"sentence_ordering": { "badge": "Unscramble the Sentence", "color": Color("#9333EA") },
	"sentence_unscramble": { "badge": "Unscramble the Sentence", "color": Color("#9333EA") },
	"letter_scramble": { "badge": "Unscramble the Word", "color": Color("#F59E0B") },
	"table_fill": { "badge": "Complete the Table", "color": Color("#4338CA") },
	"table_fill_advanced": { "badge": "Complete the Table", "color": Color("#4338CA") },
	"text_highlight": { "badge": "Find & Mark", "color": Color("#0EA5E9") },
	"text_highlight_multi": { "badge": "Find & Mark", "color": Color("#0EA5E9") },
	"transformation": { "badge": "Rewrite the Sentence", "color": Color("#BE123C") },
	"error_correction": { "badge": "Find the Mistake", "color": Color("#B91C1C") },
	"word_building": { "badge": "Build the Word", "color": Color("#65A30D") },
	"word_search": { "badge": "Word Search", "color": Color("#7C2D12") },
	"word_find": { "badge": "Word Search", "color": Color("#7C2D12") },
	"chart_fill": { "badge": "Complete the Chart", "color": Color("#1E40AF") },
	"odd_one_out": { "badge": "Odd One Out", "color": Color("#F97316") },
	"grammar_choice": { "badge": "Grammar Choice", "color": Color("#06B6D4") },
	"passive_transformation": { "badge": "Passive Transformation", "color": Color("#8B5CF6") },
	"grammar_identification": { "badge": "Grammar Identification", "color": Color("#EC4899") },
	"question_formation": { "badge": "Question Formation", "color": Color("#14B8A6") },
	"token_label": { "badge": "Label the Sentence", "color": Color("#7C3AED") },
	"image_choice": { "badge": "Choose the Picture", "color": Color("#0284C7") },
	"image_match": { "badge": "Match Pictures", "color": Color("#0891B2") },
	"image_hotspot": { "badge": "Mark the Image", "color": Color("#B45309") },
}

var _exercise: Dictionary = {}
var _items: Array = []

var _score_banner: Label = null
var _check_btn: Button = null
var _reveal_btn: Button = null
var _done_btn: Button = null
var _note_label: Label = null

var _is_graded := false
var _is_open_ended := false
var _is_non_interactive := false

var _font_regular: FontFile
var _font_bold: FontFile

var _active_vbox: VBoxContainer

static var _group_counter := 0


func _ready() -> void:
	var regular := load(FONT_REGULAR_PATH)
	if regular is FontFile:
		_font_regular = regular

	var bold := load(FONT_BOLD_PATH)
	if bold is FontFile:
		_font_bold = bold

	add_theme_constant_override("separation", 18)


# ============================================================
# MAIN ENTRY
# ============================================================
func build(exercise: Dictionary, increment_group := true) -> void:
	_exercise = exercise
	_items.clear()

	_is_graded = false
	_note_label = null
	_score_banner = null
	_check_btn = null
	_reveal_btn = null
	_done_btn = null

	var type := str(exercise.get("type", "open_ended"))

	_is_open_ended = type == "open_ended" or type == "pronunciation" or type == "writing"
	_is_non_interactive = type == "passage" or type == "reading"

	for child in get_children():
		remove_child(child)
		child.queue_free()

	_add_badge()
	_create_master_panel()

	# Types that render their own passage should not duplicate it.
	if type != "cloze" and type != "text_highlight" and type != "text_highlight_multi":
		_add_common_passage()

	_add_instruction()

	# image_hotspot renders its own interactive image.
	if type != "image_hotspot":
		_add_images()

	match type:
		"multiple_choice":
			_build_multiple_choice()
		"true_false":
			_build_true_false()
		"matching":
			_build_matching()
		"fill_blank":
			_build_fill_blank()
		"cloze":
			_build_cloze()
		"ordering":
			_build_ordering()
		"categorize":
			_build_categorize()
		"open_ended", "pronunciation", "writing":
			_build_open_ended()
		"passage", "reading":
			pass
		"word_bank":
			_build_word_bank()
		"sentence_ordering", "sentence_unscramble":
			_build_sentence_ordering()
		"letter_scramble":
			_build_letter_scramble()
		"table_fill":
			_build_table_fill()
		"table_fill_advanced":
			_build_table_fill_advanced()
		"text_highlight":
			_build_text_highlight()
		"text_highlight_multi":
			_build_text_highlight_multi()
		"transformation":
			_build_transformation()
		"error_correction":
			_build_error_correction()
		"word_building":
			_build_word_building()
		"word_search", "word_find":
			_build_word_search()
		"chart_fill":
			_build_chart_fill()
		"odd_one_out":
			_build_odd_one_out()
		"grammar_choice":
			_build_grammar_choice()
		"passive_transformation":
			_build_passive_transformation()
		"grammar_identification":
			_build_grammar_identification()
		"question_formation":
			_build_question_formation()
		"token_label":
			_build_token_label()
		"image_choice":
			_build_image_choice()
		"image_match":
			_build_image_match()
		"image_hotspot":
			_build_image_hotspot()
		_:
			_build_open_ended()

	_add_note()
	_add_footer_buttons()

	if increment_group:
		_group_counter += 1


# ============================================================
# TEXT HELPERS
# ============================================================
func _get_en_text(val: Variant) -> String:
	if val is Dictionary:
		return str(val.get("en", ""))
	return str(val)


func _get_fa_text(val: Variant) -> String:
	if val is Dictionary:
		return str(val.get("fa", ""))
	return ""


func _get_item_main_text(item: Dictionary) -> String:
	for key in ["question", "prompt", "text", "statement", "sentence", "title", "word", "active"]:
		if item.has(key):
			var val := _get_en_text(item.get(key))
			if val != "":
				return val
	return ""


func _get_option_text(opt: Variant) -> String:
	if opt is Dictionary:
		if opt.has("en") or opt.has("fa"):
			return _get_en_text(opt)

		for key in ["label", "text", "title", "name", "id"]:
			if opt.has(key):
				return _get_en_text(opt.get(key))

		return ""

	return str(opt)


func _find_option_index(options: Array, value: Variant) -> int:
	var s := str(value)

	for i in options.size():
		var opt = options[i]

		if opt is Dictionary and str(opt.get("id", "")) == s:
			return i

		if _normalize(_get_option_text(opt)) == _normalize(s):
			return i

	return -1


func _join_words(arr: Array) -> String:
	var parts: Array = []
	for a in arr:
		parts.append(str(a))
	return " ".join(parts)


func _join_string_array(arr: Array, sep: String) -> String:
	var out := ""
	for i in arr.size():
		out += str(arr[i])
		if i < arr.size() - 1:
			out += sep
	return out


# ============================================================
# HEADER / PANEL / COMMON BLOCKS
# ============================================================
func _add_badge() -> void:
	var type := str(_exercise.get("type", "open_ended"))
	var meta: Dictionary = TYPE_META.get(type, TYPE_META["open_ended"])
	var accent: Color = meta["color"]

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 12)

	var badge := Label.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.text = str(meta["badge"])
	badge.add_theme_font_size_override("font_size", 28)
	badge.add_theme_color_override("font_color", accent)

	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(accent.r, accent.g, accent.b, 0.12)
	badge_style.set_corner_radius_all(20)
	badge_style.set_content_margin_all(10)
	badge.add_theme_stylebox_override("normal", badge_style)

	if _font_bold:
		badge.add_theme_font_override("font", _font_bold)

	header.add_child(badge)
	add_child(header)


func _create_master_panel() -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#1a2f5c")  # Dark bg
	style.set_corner_radius_all(16)
	
	var type := str(_exercise.get("type", "open_ended"))
	var meta: Dictionary = TYPE_META.get(type, TYPE_META["open_ended"])
	style.border_width_left = 8
	style.border_color = meta["color"]
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 4)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	
	_active_vbox = VBoxContainer.new()
	_active_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_active_vbox.add_theme_constant_override("separation", 32)
	panel.add_child(_active_vbox)
	add_child(panel)

func _add_common_passage() -> void:
	var passage_raw: Variant = _exercise.get("passage", _exercise.get("reading", ""))

	if passage_raw == null:
		return

	var text := ""

	if passage_raw is Array:
		var paras: Array = []
		for p in passage_raw:
			var s := _get_en_text(p)
			if s != "":
				paras.append(s)
		text = "\n\n".join(paras)
	else:
		text = _get_en_text(passage_raw)

	if text.strip_edges() == "":
		return

	var title := _get_en_text(_exercise.get("passage_title", ""))
	if title != "":
		var title_label := _make_label(title, 36, C_PRIMARY, true)
		_active_vbox.add_child(title_label)

	var rtl := RichTextLabel.new()
	rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = true
	rtl.custom_minimum_size.y = 240
	rtl.add_theme_font_size_override("normal_font_size", 36)
	rtl.add_theme_color_override("default_color", Color("#F1F5F9"))

	if _font_regular:
		rtl.add_theme_font_override("normal_font", _font_regular)

	rtl.text = text

	if passage_raw is Dictionary:
		rtl.set_meta("text_fa", _get_fa_text(passage_raw))

	_active_vbox.add_child(rtl)


func _add_instruction() -> void:
	var text_raw = _exercise.get("instruction", "")
	var text_val := _get_en_text(text_raw)

	if text_val == "":
		return

	var show_letter := bool(_exercise.get("show_letter", true))
	var final_text := text_val

	if show_letter:
		var letter_code := char(65 + (_group_counter % 26))
		final_text = letter_code + ". " + text_val

	var instruction := Label.new()
	instruction.mouse_filter = Control.MOUSE_FILTER_IGNORE
	instruction.text = final_text
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD
	instruction.add_theme_font_size_override("font_size", 40)
	instruction.add_theme_color_override("font_color", C_TEXT)
	instruction.set_meta("text_fa", _get_fa_text(text_raw))

	if _font_bold:
		instruction.add_theme_font_override("font", _font_bold)

	_active_vbox.add_child(instruction)

	var sep := HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sep_style := StyleBoxLine.new()
	sep_style.color = C_MUTED.lightened(0.7)
	sep_style.thickness = 2
	sep.add_theme_stylebox_override("separator", sep_style)

	_active_vbox.add_child(sep)


func _add_note() -> void:
	var note_raw = _exercise.get("note", "")
	var note := _get_en_text(note_raw)

	if note == "":
		return

	_note_label = _make_label("Info: " + note, 32, C_MUTED, false)
	_note_label.set_meta("text_fa", _get_fa_text(note_raw))
	_note_label.visible = false

	if _is_open_ended or _is_non_interactive:
		_note_label.visible = true

	_active_vbox.add_child(_note_label)


# ============================================================
# IMAGE / MEDIA HELPERS
# ============================================================
func _add_images() -> void:
	var images: Array = _exercise.get("images", [])

	if images.is_empty():
		var single_img = _exercise.get("image", "")
		if single_img != "":
			images = [single_img]

	for img_data in images:
		_active_vbox.add_child(_make_media_control(img_data))


func _add_item_media(item: Dictionary, parent: Control) -> void:
	if item.has("images"):
		for img in item.get("images", []):
			parent.add_child(_make_media_control(img))
	elif item.has("image"):
		parent.add_child(_make_media_control(item.get("image")))


func _get_first_image_path(data: Dictionary) -> String:
	if data.has("image"):
		var img = data["image"]
		if img is Dictionary:
			return str(img.get("path", img.get("image", "")))
		return str(img)

	var imgs: Array = data.get("images", [])
	if imgs.size() > 0:
		var img = imgs[0]
		if img is Dictionary:
			return str(img.get("path", img.get("image", "")))
		return str(img)

	return ""


func _make_media_control(img_data: Variant) -> Control:
	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 6)

	var path := ""
	var caption := ""

	var max_width := int(_exercise.get("image_max_width", 360))
	var min_height := int(_exercise.get("image_min_height", 180))

	if img_data is Dictionary:
		path = str(img_data.get("path", img_data.get("image", "")))
		caption = _get_en_text(img_data.get("caption", ""))
		max_width = int(img_data.get("max_width", max_width))
		min_height = int(img_data.get("min_height", min_height))
	else:
		path = str(img_data)

	if path == "":
		var ph := _make_label("Image placeholder", 28, C_MUTED, false)
		vbox.add_child(ph)
		return vbox

	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D

		if tex:
			var img := TextureRect.new()
			img.texture = tex
			img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			img.mouse_filter = Control.MOUSE_FILTER_IGNORE
			img.custom_minimum_size = Vector2(max_width, min_height)
			img.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

			var center := HBoxContainer.new()
			center.mouse_filter = Control.MOUSE_FILTER_IGNORE
			center.alignment = BoxContainer.ALIGNMENT_CENTER
			center.add_child(img)

			vbox.add_child(center)

			if caption != "":
				var cap := _make_label(caption, 28, C_MUTED, false)
				cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				vbox.add_child(cap)

			return vbox

	var missing := _make_label("Image not found: " + path.get_file(), 28, C_MUTED, false)
	vbox.add_child(missing)

	return vbox


# ============================================================
# FOOTER BUTTONS
# ============================================================
func _add_footer_buttons() -> void:
	if _is_non_interactive:
		return

	var graded_count := 0
	var has_sample := false

	for it in _items:
		if it.has("get"):
			graded_count += 1

		if it.get("sample_label", null) != null:
			has_sample = true

	if graded_count > 0:
		_score_banner = Label.new()
		_score_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_score_banner.autowrap_mode = TextServer.AUTOWRAP_WORD
		_score_banner.add_theme_font_size_override("font_size", 36)
		_score_banner.visible = false

		if _font_bold:
			_score_banner.add_theme_font_override("font", _font_bold)

		add_child(_score_banner)

	var btn_row := HBoxContainer.new()
	btn_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn_row.add_theme_constant_override("separation", 14)

	if _is_open_ended:
		if has_sample:
			_reveal_btn = _make_button("Show Sample Answer", C_MUTED)
			_reveal_btn.pressed.connect(_on_reveal_sample)
			btn_row.add_child(_reveal_btn)

		_done_btn = _make_button("Done", C_SUCCESS)
		_done_btn.pressed.connect(_on_open_ended_done)
		btn_row.add_child(_done_btn)

	elif graded_count > 0:
		_check_btn = _make_button("Check Answer", C_PRIMARY)
		_check_btn.pressed.connect(_on_check_pressed)
		btn_row.add_child(_check_btn)

	if btn_row.get_child_count() > 0:
		add_child(btn_row)


func _make_button(text: String, color: Color) -> Button:
	var btn := Button.new()
	btn.mouse_filter = Control.MOUSE_FILTER_PASS
	btn.text = text
	btn.add_theme_font_size_override("font_size", 34)
	btn.add_theme_color_override("font_color", Color.WHITE)
	
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(12)
	style.set_content_margin_all(16)
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 3)
	btn.add_theme_stylebox_override("normal", style)
	
	var hover := style.duplicate()
	hover.bg_color = color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	
	if _font_bold:
		btn.add_theme_font_override("font", _font_bold)
	return btn

# ============================================================
# BUILDERS
# ============================================================

# ------------------------------------------------------------
# MULTIPLE CHOICE
# ------------------------------------------------------------
func _build_multiple_choice() -> void:
	for item in _exercise.get("items", []):
		var item_vbox := VBoxContainer.new()
		item_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_vbox.add_theme_constant_override("separation", 12)
		_active_vbox.add_child(item_vbox)

		_add_item_media(item, item_vbox)

		var q_label := _make_label(_get_item_main_text(item), 40, C_TEXT, true)
		item_vbox.add_child(q_label)

		var group := ButtonGroup.new()
		var option_btns: Array[Button] = []
		var options: Array = item.get("options", [])

		for opt in options:
			var b := _make_option_button(_get_option_text(opt), group)
			option_btns.append(b)
			item_vbox.add_child(b)

		var answer: Variant = item.get("answer", -1)
		if answer is String:
			answer = _find_option_index(options, answer)

		_items.append({
			"type": "multiple_choice",
			"get": func():
				for idx in option_btns.size():
					if option_btns[idx].button_pressed:
						return idx
				return -1,
			"answer": answer,
			"feedback": _make_feedback(item_vbox),
			"explanation_en": _get_en_text(item.get("explanation", "")),
			"explanation_fa": _get_fa_text(item.get("explanation", "")),
		})


# ------------------------------------------------------------
# TRUE / FALSE
# ------------------------------------------------------------
func _build_true_false() -> void:
	for item in _exercise.get("items", []):
		var item_vbox := VBoxContainer.new()
		item_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_vbox.add_theme_constant_override("separation", 12)
		_active_vbox.add_child(item_vbox)

		_add_item_media(item, item_vbox)

		var statement := _make_label(_get_item_main_text(item), 40, C_TEXT, false)
		item_vbox.add_child(statement)

		var group := ButtonGroup.new()
		var t_btn := _make_option_button("True", group)
		var f_btn := _make_option_button("False", group)

		item_vbox.add_child(t_btn)
		item_vbox.add_child(f_btn)

		var ans: Variant = item.get("answer", true)
		if ans is String:
			var s := _normalize(str(ans))
			ans = (s == "true" or s == "t" or s == "yes" or s == "y")

		var corr_raw = item.get("correction", item.get("explanation", ""))

		_items.append({
			"type": "true_false",
			"get": func():
				if t_btn.button_pressed:
					return true
				if f_btn.button_pressed:
					return false
				return null,
			"answer": ans,
			"feedback": _make_feedback(item_vbox),
			"explanation_en": _get_en_text(corr_raw),
			"explanation_fa": _get_fa_text(corr_raw),
		})


# ------------------------------------------------------------
# MATCHING
# ------------------------------------------------------------
func _build_matching() -> void:
	var exercise_options: Array = _exercise.get("options", [])

	for item in _exercise.get("items", []):
		var item_vbox := VBoxContainer.new()
		item_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_vbox.add_theme_constant_override("separation", 12)
		_active_vbox.add_child(item_vbox)

		_add_item_media(item, item_vbox)

		var text := _make_label(_get_item_main_text(item), 38, C_TEXT, false)
		item_vbox.add_child(text)

		var options: Array = item.get("options", exercise_options)
		var option_texts: Array = []

		for opt in options:
			option_texts.append(_get_option_text(opt))

		var ob := _make_option_dropdown(option_texts)
		item_vbox.add_child(ob)

		var answer: Variant = item.get("answer", "")

		if answer is int and answer >= 0 and answer < option_texts.size():
			answer = option_texts[answer]
		elif answer is String:
			for opt in options:
				if opt is Dictionary and str(opt.get("id", "")) == str(answer):
					answer = _get_option_text(opt)
					break

		_items.append({
			"type": "matching",
			"get": func():
				if ob.selected > 0:
					return ob.get_item_text(ob.selected)
				return "",
			"answer": answer,
			"feedback": _make_feedback(item_vbox),
			"explanation_en": "",
			"explanation_fa": "",
		})


# ------------------------------------------------------------
# FILL IN THE BLANK
# ------------------------------------------------------------
func _build_fill_blank() -> void:
	for item in _exercise.get("items", []):
		var item_vbox := VBoxContainer.new()
		item_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_vbox.add_theme_constant_override("separation", 12)
		_active_vbox.add_child(item_vbox)

		_add_item_media(item, item_vbox)

		var text := _make_label(_get_item_main_text(item), 38, C_TEXT, false)
		item_vbox.add_child(text)

		var hint := _get_en_text(item.get("hint", ""))
		if hint != "":
			item_vbox.add_child(_make_label("Hint: " + hint, 30, C_MUTED, false))

		var le := _make_line_edit("Type your answer...")
		item_vbox.add_child(le)

		_items.append({
			"type": "fill_blank",
			"get": func(): return le.text,
			"answer": item.get("answer", []),
			"feedback": _make_feedback(item_vbox),
			"explanation_en": _get_en_text(item.get("explanation", "")),
			"explanation_fa": _get_fa_text(item.get("explanation", "")),
			"answer_patterns": item.get("answer_patterns", []),
			"required_words": item.get("required_words", []),
			"forbidden_words": item.get("forbidden_words", []),
		})


# ------------------------------------------------------------
# CLOZE
# ------------------------------------------------------------
func _build_cloze() -> void:
	var p_raw = _exercise.get("passage", "")
	var passage := _make_label(_get_en_text(p_raw), 38, C_MUTED, false)
	passage.set_meta("text_fa", _get_fa_text(p_raw))
	_active_vbox.add_child(passage)

	for i in _exercise.get("blanks", []).size():
		var blank: Dictionary = _exercise["blanks"][i]

		var item_vbox := VBoxContainer.new()
		item_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_vbox.add_theme_constant_override("separation", 12)
		_active_vbox.add_child(item_vbox)

		var label := _make_label("(%d) ______" % (i + 1), 38, C_TEXT, true)
		item_vbox.add_child(label)

		var options: Array = blank.get("options", [])
		var option_texts: Array = []

		for opt in options:
			option_texts.append(_get_option_text(opt))

		var ob := _make_option_dropdown(option_texts)
		item_vbox.add_child(ob)

		var answer: Variant = blank.get("answer", "")

		if answer is int and answer >= 0 and answer < option_texts.size():
			answer = option_texts[answer]
		elif answer is String:
			for opt in options:
				if opt is Dictionary and str(opt.get("id", "")) == str(answer):
					answer = _get_option_text(opt)
					break

		_items.append({
			"type": "cloze",
			"get": func():
				if ob.selected > 0:
					return ob.get_item_text(ob.selected)
				return "",
			"answer": answer,
			"feedback": _make_feedback(item_vbox),
			"explanation_en": _get_en_text(blank.get("explanation", "")),
			"explanation_fa": _get_fa_text(blank.get("explanation", "")),
		})


# ------------------------------------------------------------
# ORDERING WITH UP/DOWN BUTTONS
# JSON:
# {
#   "type": "ordering",
#   "items": ["mouse", "sheep", "wolf", "lion"],
#   "answer_order": [0, 2, 3, 1]
# }
# ------------------------------------------------------------
func _build_ordering() -> void:
	var raw_items: Array = _exercise.get("items", [])

	var item_texts: Array = []
	for it in raw_items:
		item_texts.append(_get_option_text(it))

	var answer_order: Array = _exercise.get("answer_order", [])

	if answer_order.is_empty():
		var ans: Array = _exercise.get("answer", [])

		if ans.size() == raw_items.size():
			var pairs: Array = []

			for i in ans.size():
				pairs.append({
					"pos": int(ans[i]),
					"idx": i,
				})

			pairs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return a["pos"] < b["pos"]
			)

			for p in pairs:
				answer_order.append(p["idx"])

	if answer_order.is_empty():
		for i in raw_items.size():
			answer_order.append(i)

	var current_order: Array = []
	for i in raw_items.size():
		current_order.append(i)

	var container := VBoxContainer.new()
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_theme_constant_override("separation", 12)
	_active_vbox.add_child(container)

	var list_vbox := VBoxContainer.new()
	list_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list_vbox.add_theme_constant_override("separation", 10)
	container.add_child(list_vbox)

	var fb := _make_feedback(container)

	_rebuild_ordering_list(list_vbox, current_order, item_texts)

	var ordered_texts: Array = []
	for idx in answer_order:
		var i := int(idx)
		if i >= 0 and i < item_texts.size():
			ordered_texts.append(str(item_texts[i]))

	_items.append({
		"type": "ordering",
		"get": func(): return current_order.duplicate(),
		"answer": answer_order.duplicate(),
		"feedback": fb,
		"answer_display": _join_string_array(ordered_texts, " → "),
		"explanation_en": "",
		"explanation_fa": "",
	})


func _rebuild_ordering_list(list_vbox: VBoxContainer, current_order: Array, item_texts: Array) -> void:
	for c in list_vbox.get_children():
		list_vbox.remove_child(c)
		c.queue_free()

	for pos in current_order.size():
		var idx := int(current_order[pos])

		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 10)
		list_vbox.add_child(row)

		var num := _make_label("%d." % (pos + 1), 34, C_MUTED, true)
		num.custom_minimum_size.x = 60
		row.add_child(num)

		var txt := _make_label(str(item_texts[idx]), 36, C_TEXT, false)
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(txt)

		var up := _make_button("Up", C_MUTED)
		up.custom_minimum_size = Vector2(110, 60)
		up.disabled = (pos == 0)
		up.pressed.connect(_on_order_move.bind(list_vbox, current_order, item_texts, pos, -1))
		row.add_child(up)

		var down := _make_button("Down", C_MUTED)
		down.custom_minimum_size = Vector2(110, 60)
		down.disabled = (pos == current_order.size() - 1)
		down.pressed.connect(_on_order_move.bind(list_vbox, current_order, item_texts, pos, 1))
		row.add_child(down)


func _on_order_move(list_vbox: VBoxContainer, current_order: Array, item_texts: Array, pos: int, delta: int) -> void:
	var new_pos := pos + delta

	if new_pos < 0 or new_pos >= current_order.size():
		return

	var tmp: int = int(current_order[pos])
	current_order[pos] = current_order[new_pos]
	current_order[new_pos] = tmp

	_rebuild_ordering_list(list_vbox, current_order, item_texts)


# ------------------------------------------------------------
# CATEGORIZE
# ------------------------------------------------------------
func _build_categorize() -> void:
	var categories: Array = _exercise.get("categories", [])

	var category_texts: Array = []
	for cat in categories:
		category_texts.append(_get_option_text(cat))

	for item in _exercise.get("items", []):
		var item_vbox := VBoxContainer.new()
		item_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_vbox.add_theme_constant_override("separation", 12)
		_active_vbox.add_child(item_vbox)

		_add_item_media(item, item_vbox)

		var text := _make_label(_get_item_main_text(item), 38, C_TEXT, false)
		item_vbox.add_child(text)

		var ob := _make_option_dropdown(category_texts, "Category")
		item_vbox.add_child(ob)

		var answer: Variant = item.get("answer", "")

		if answer is int and answer >= 0 and answer < category_texts.size():
			answer = category_texts[answer]
		elif answer is String:
			for cat in categories:
				if cat is Dictionary and str(cat.get("id", "")) == str(answer):
					answer = _get_option_text(cat)
					break

		_items.append({
			"type": "categorize",
			"get": func():
				if ob.selected > 0:
					return ob.get_item_text(ob.selected)
				return "",
			"answer": answer,
			"feedback": _make_feedback(item_vbox),
			"explanation_en": "",
			"explanation_fa": "",
		})


# ------------------------------------------------------------
# OPEN ENDED / PRONUNCIATION / WRITING
# ------------------------------------------------------------
func _build_open_ended() -> void:
	for item in _exercise.get("items", []):
		var item_vbox := VBoxContainer.new()
		item_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_vbox.add_theme_constant_override("separation", 12)
		_active_vbox.add_child(item_vbox)

		_add_item_media(item, item_vbox)

		var q := _get_item_main_text(item)
		if q != "":
			var q_label := _make_label(q, 38, C_TEXT, false)
			item_vbox.add_child(q_label)

		var te := TextEdit.new()
		te.mouse_filter = Control.MOUSE_FILTER_PASS
		te.placeholder_text = "Write your answer here..."
		te.custom_minimum_size = Vector2(0, 180)
		te.add_theme_font_size_override("font_size", 36)
		te.add_theme_color_override("font_color", Color.BLACK)

		if _font_regular:
			te.add_theme_font_override("font", _font_regular)

		var te_style := StyleBoxFlat.new()
		te_style.bg_color = Color.WHITE
		te_style.set_corner_radius_all(10)
		te_style.border_width_bottom = 2
		te_style.border_color = Color("#64748B").lightened(0.4)
		te_style.set_content_margin_all(14)
		te.add_theme_stylebox_override("normal", te_style)

		var te_focus: StyleBoxFlat = te_style.duplicate()
		te_focus.border_color = C_PRIMARY
		te.add_theme_stylebox_override("focus", te_focus)

		te.add_theme_color_override("caret_color", C_PRIMARY)
		item_vbox.add_child(te)

		var rubric: Array = item.get("rubric", _exercise.get("rubric", []))

		for r in rubric:
			var cb := CheckBox.new()
			cb.mouse_filter = Control.MOUSE_FILTER_PASS
			cb.text = _get_en_text(r)
			cb.add_theme_font_size_override("font_size", 32)

			if _font_regular:
				cb.add_theme_font_override("font", _font_regular)

			item_vbox.add_child(cb)

		var default_self_check := str(_exercise.get("type", "")) == "pronunciation"
		var self_check := bool(item.get("self_check", _exercise.get("self_check", default_self_check)))

		if self_check:
			var done_check := CheckBox.new()
			done_check.mouse_filter = Control.MOUSE_FILTER_PASS
			done_check.text = "I practiced this aloud / I completed this."
			done_check.add_theme_font_size_override("font_size", 32)

			if _font_regular:
				done_check.add_theme_font_override("font", _font_regular)

			item_vbox.add_child(done_check)

		var sample_text := _get_en_text(item.get("sample_answer", ""))
		var sample: Label = null

		if sample_text != "":
			sample = _make_label("Sample answer: " + sample_text, 34, C_SUCCESS, false)
			sample.set_meta("text_fa", _get_fa_text(item.get("sample_answer", "")))
			sample.visible = false
			item_vbox.add_child(sample)

		_items.append({
			"sample_label": sample,
		})


# ------------------------------------------------------------
# WORD BANK
# ------------------------------------------------------------
func _build_word_bank() -> void:
	var bank: Array = _exercise.get("word_bank", [])

	var bank_texts: Array = []
	for w in bank:
		bank_texts.append(_get_option_text(w))

	for item in _exercise.get("items", []):
		var item_vbox := VBoxContainer.new()
		item_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_vbox.add_theme_constant_override("separation", 12)
		_active_vbox.add_child(item_vbox)

		_add_item_media(item, item_vbox)

		var text := _make_label(_get_item_main_text(item), 38, C_TEXT, false)
		item_vbox.add_child(text)

		var ob := _make_option_dropdown(bank_texts, "Choose a word")
		item_vbox.add_child(ob)

		var answer: Variant = item.get("answer", "")

		if answer is int and answer >= 0 and answer < bank_texts.size():
			answer = bank_texts[answer]
		elif answer is String:
			for w in bank:
				if w is Dictionary and str(w.get("id", "")) == str(answer):
					answer = _get_option_text(w)
					break

		_items.append({
			"type": "word_bank",
			"get": func():
				if ob.selected > 0:
					return ob.get_item_text(ob.selected)
				return "",
			"answer": answer,
			"feedback": _make_feedback(item_vbox),
			"explanation_en": "",
			"explanation_fa": "",
		})


# ------------------------------------------------------------
# SENTENCE ORDERING / UNSCRAMBLE
# ------------------------------------------------------------
func _build_sentence_ordering() -> void:
	for item in _exercise.get("items", []):
		var item_vbox := VBoxContainer.new()
		item_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_vbox.add_theme_constant_override("separation", 14)
		_active_vbox.add_child(item_vbox)

		_add_item_media(item, item_vbox)

		var words: Array = item.get("words", [])

		var word_texts: Array = []
		for w in words:
			word_texts.append(_get_option_text(w))

		var answer_words_raw: Array = item.get("answer", word_texts)
		var answer_words: Array = []

		var all_int := true
		for x in answer_words_raw:
			if not (x is int or x is float):
				all_int = false
				break

		if all_int and answer_words_raw.size() == word_texts.size():
			for x in answer_words_raw:
				var idx := int(x)
				if idx >= 0 and idx < word_texts.size():
					answer_words.append(word_texts[idx])
				else:
					answer_words.append(str(x))
		else:
			for w in answer_words_raw:
				answer_words.append(_get_option_text(w))

		var built_row := HFlowContainer.new()
		built_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		built_row.add_theme_constant_override("h_separation", 8)
		built_row.add_theme_constant_override("v_separation", 8)
		built_row.custom_minimum_size = Vector2(0, 64)
		item_vbox.add_child(built_row)

		var sep := HSeparator.new()
		sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_vbox.add_child(sep)

		var bank_row := HFlowContainer.new()
		bank_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bank_row.add_theme_constant_override("h_separation", 8)
		bank_row.add_theme_constant_override("v_separation", 8)
		item_vbox.add_child(bank_row)

		var order: Array = []
		var word_btns: Array = []

		for i in word_texts.size():
			var wb := _make_chip_button(str(word_texts[i]))
			word_btns.append(wb)
			bank_row.add_child(wb)

		for i in word_texts.size():
			word_btns[i].pressed.connect(
				_on_bank_word_pressed.bind(i, order, word_btns, built_row, word_texts)
			)

		_items.append({
			"type": "sentence_ordering",
			"get": func():
				var chosen: Array = []
				for idx in order:
					chosen.append(word_texts[idx])
				return _join_words(chosen),
			"answer": _join_words(answer_words),
			"feedback": _make_feedback(item_vbox),
			"explanation_en": "",
			"explanation_fa": "",
		})


func _on_bank_word_pressed(idx: int, order: Array, word_btns: Array, built_row: HFlowContainer, words: Array) -> void:
	var btn: Button = word_btns[idx]

	if btn.disabled:
		return

	btn.disabled = true
	btn.modulate.a = 0.3

	order.append(idx)
	_rebuild_order_row(order, word_btns, built_row, words)


func _rebuild_order_row(order: Array, word_btns: Array, built_row: HFlowContainer, words: Array) -> void:
	for c in built_row.get_children():
		built_row.remove_child(c)
		c.queue_free()

	for pos in order.size():
		var idx: int = order[pos]

		var chip := _make_chip_button(str(words[idx]), true)
		chip.pressed.connect(_on_built_word_pressed.bind(pos, order, word_btns, built_row, words))

		built_row.add_child(chip)


func _on_built_word_pressed(pos: int, order: Array, word_btns: Array, built_row: HFlowContainer, words: Array) -> void:
	var idx: int = order[pos]
	order.remove_at(pos)

	var btn: Button = word_btns[idx]
	btn.disabled = false
	btn.modulate.a = 1.0

	_rebuild_order_row(order, word_btns, built_row, words)


# ------------------------------------------------------------
# LETTER SCRAMBLE
# ------------------------------------------------------------
func _build_letter_scramble() -> void:
	for item in _exercise.get("items", []):
		var item_vbox := VBoxContainer.new()
		item_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_vbox.add_theme_constant_override("separation", 12)
		_active_vbox.add_child(item_vbox)

		_add_item_media(item, item_vbox)

		var scrambled: String = str(item.get("scrambled", ""))

		var spaced := ""
		for i in scrambled.length():
			spaced += scrambled[i].to_upper()
			if i < scrambled.length() - 1:
				spaced += "  "

		var label := _make_label(spaced, 44, C_PRIMARY, true)
		item_vbox.add_child(label)

		var hint_raw = item.get("hint", "")
		if _get_en_text(hint_raw) != "":
			var hint := _make_label("Hint: " + _get_en_text(hint_raw), 32, C_MUTED, false)
			hint.set_meta("text_fa", _get_fa_text(hint_raw))
			item_vbox.add_child(hint)

		var le := _make_line_edit("Type the word...")
		item_vbox.add_child(le)

		_items.append({
			"type": "letter_scramble",
			"get": func(): return le.text,
			"answer": item.get("answer", ""),
			"feedback": _make_feedback(item_vbox),
			"explanation_en": "",
			"explanation_fa": "",
		})


# ------------------------------------------------------------
# SIMPLE TABLE FILL
# ------------------------------------------------------------
func _build_table_fill() -> void:
	var columns: Array = _exercise.get("columns", [])

	var grid := GridContainer.new()
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.columns = maxi(columns.size(), 1)
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 16)
	_active_vbox.add_child(grid)

	for col in columns:
		var h := _make_label(_get_en_text(col), 34, C_MUTED, true)
		grid.add_child(h)

	for row in _exercise.get("rows", []):
		for cell in row.get("cells", []):
			var cell_box := VBoxContainer.new()
			cell_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell_box.add_theme_constant_override("separation", 6)
			grid.add_child(cell_box)

			if cell.get("editable", false):
				var le := _make_line_edit("...")
				cell_box.add_child(le)

				_items.append({
					"type": "fill_blank",
					"get": func(): return le.text,
					"answer": cell.get("answer", []),
					"feedback": _make_feedback(cell_box),
					"explanation_en": "",
					"explanation_fa": "",
				})
			else:
				var lbl := _make_label(_get_en_text(cell.get("text", "")), 36, C_TEXT, false)
				cell_box.add_child(lbl)


# ------------------------------------------------------------
# ADVANCED TABLE FILL
# Cell types:
# - label
# - line
# - dropdown
# - true_false
# - yes_no
# - checkbox
# ------------------------------------------------------------
func _build_table_fill_advanced() -> void:
	var columns: Array = _exercise.get("columns", [])

	var grid := GridContainer.new()
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.columns = maxi(columns.size(), 1)
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 16)
	_active_vbox.add_child(grid)

	for col in columns:
		var h := _make_label(_get_en_text(col), 34, C_PRIMARY, true)
		grid.add_child(h)

	for row in _exercise.get("rows", []):
		var cells: Array = []

		if row is Dictionary:
			cells = row.get("cells", [])
		elif row is Array:
			cells = row

		for cell in cells:
			var cell_box := VBoxContainer.new()
			cell_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell_box.add_theme_constant_override("separation", 6)
			grid.add_child(cell_box)

			if not cell is Dictionary:
				cell_box.add_child(_make_label(str(cell), 34, C_TEXT, false))
				continue

			var ctype := str(cell.get("type", cell.get("editor", "label")))

			match ctype:
				"line", "fill_blank", "text":
					var le := _make_line_edit(str(cell.get("placeholder", "...")))
					cell_box.add_child(le)

					_items.append({
						"type": "fill_blank",
						"get": func(): return le.text,
						"answer": cell.get("answer", []),
						"feedback": _make_feedback(cell_box),
						"explanation_en": _get_en_text(cell.get("explanation", "")),
						"explanation_fa": _get_fa_text(cell.get("explanation", "")),
					})

				"dropdown", "select":
					var options: Array = cell.get("options", [])
					var option_texts: Array = []

					for opt in options:
						option_texts.append(_get_option_text(opt))

					var ob := _make_option_dropdown(option_texts, str(cell.get("placeholder", "Choose")))
					cell_box.add_child(ob)

					var ans: Variant = cell.get("answer", "")

					if ans is int and ans >= 0 and ans < option_texts.size():
						ans = option_texts[ans]
					elif ans is String:
						for opt in options:
							if opt is Dictionary and str(opt.get("id", "")) == str(ans):
								ans = _get_option_text(opt)
								break

					_items.append({
						"type": "dropdown",
						"get": func():
							if ob.selected > 0:
								return ob.get_item_text(ob.selected)
							return "",
						"answer": ans,
						"feedback": _make_feedback(cell_box),
						"explanation_en": _get_en_text(cell.get("explanation", "")),
						"explanation_fa": _get_fa_text(cell.get("explanation", "")),
					})

				"true_false", "yes_no":
					var group := ButtonGroup.new()

					var yes_text := "Yes" if ctype == "yes_no" else "True"
					var no_text := "No" if ctype == "yes_no" else "False"

					var hbox := HBoxContainer.new()
					hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
					hbox.add_theme_constant_override("separation", 10)
					cell_box.add_child(hbox)

					var b_yes := _make_select_button(yes_text, group, C_SUCCESS)
					var b_no := _make_select_button(no_text, group, C_ERROR)

					hbox.add_child(b_yes)
					hbox.add_child(b_no)

					var ans_tf: Variant = cell.get("answer", true)

					if ans_tf is String:
						var s := _normalize(str(ans_tf))
						ans_tf = (s == "yes" or s == "true" or s == "y" or s == "t")

					_items.append({
						"type": ctype,
						"get": func():
							if b_yes.button_pressed:
								return true
							if b_no.button_pressed:
								return false
							return null,
						"answer": ans_tf,
						"feedback": _make_feedback(cell_box),
						"explanation_en": _get_en_text(cell.get("explanation", "")),
						"explanation_fa": _get_fa_text(cell.get("explanation", "")),
					})

				"checkbox", "check":
					var cb := CheckBox.new()
					cb.mouse_filter = Control.MOUSE_FILTER_PASS
					cb.text = _get_en_text(cell.get("text", ""))
					cb.add_theme_font_size_override("font_size", 32)

					if _font_regular:
						cb.add_theme_font_override("font", _font_regular)

					cell_box.add_child(cb)

					_items.append({
						"type": "checkbox",
						"get": func(): return cb.button_pressed,
						"answer": bool(cell.get("answer", false)),
						"feedback": _make_feedback(cell_box),
						"explanation_en": _get_en_text(cell.get("explanation", "")),
						"explanation_fa": _get_fa_text(cell.get("explanation", "")),
					})

				_:
					var lbl := _make_label(_get_en_text(cell.get("text", "")), 34, C_TEXT, false)
					cell_box.add_child(lbl)


# ------------------------------------------------------------
# SINGLE-CATEGORY TEXT HIGHLIGHT
# ------------------------------------------------------------
func _build_text_highlight() -> void:
	var p_raw = _exercise.get("passage", "")
	var passage_text := _get_en_text(p_raw)

	var words: PackedStringArray = passage_text.split(" ", false)
	var answer_indices: Array = _exercise.get("answer_indices", [])

	var hint := _make_label("Tap the words that match the instruction above.", 30, C_MUTED, false)
	_active_vbox.add_child(hint)

	var flow := HFlowContainer.new()
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flow.add_theme_constant_override("h_separation", 4)
	flow.add_theme_constant_override("v_separation", 12)
	_active_vbox.add_child(flow)

	for i in words.size():
		var pair := VBoxContainer.new()
		pair.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pair.add_theme_constant_override("separation", 0)
		flow.add_child(pair)

		var wb := _make_word_toggle(words[i])
		pair.add_child(wb)

		var fb := Label.new()
		fb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fb.add_theme_font_size_override("font_size", 22)
		fb.visible = false
		pair.add_child(fb)

		var is_target: bool = answer_indices.has(i)

		_items.append({
			"type": "text_highlight",
			"get": func(): return wb.button_pressed,
			"answer": is_target,
			"feedback": fb,
			"explanation_en": "",
			"explanation_fa": "",
		})


# ------------------------------------------------------------
# MULTI-CATEGORY TEXT HIGHLIGHT
# JSON:
# {
#   "type": "text_highlight_multi",
#   "passage": "The man is eating lunch quickly.",
#   "categories": [
#     {"id": "subject", "label": "S", "color": "#2563EB"},
#     {"id": "verb", "label": "V", "color": "#16A34A"},
#     {"id": "object", "label": "O", "color": "#DC2626"},
#     {"id": "adverb", "label": "Adv", "color": "#F59E0B"}
#   ],
#   "answer_indices": {
#     "1": "subject",
#     "2": "verb",
#     "4": "object",
#     "5": "adverb"
#   }
# }
# ------------------------------------------------------------
func _build_text_highlight_multi() -> void:
	var categories := _normalize_categories(_exercise.get("categories", []))

	if categories.is_empty():
		categories = _normalize_categories(["A", "B"])

	var passage_text := _get_en_text(_exercise.get("passage", _exercise.get("reading", "")))

	var tokens: Array = []

	if _exercise.has("tokens"):
		for t in _exercise.get("tokens", []):
			tokens.append(_get_option_text(t))
	else:
		tokens = Array(passage_text.split(" ", false))

	var legend := HFlowContainer.new()
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	legend.add_theme_constant_override("h_separation", 14)
	legend.add_theme_constant_override("v_separation", 8)
	_active_vbox.add_child(legend)

	for c in categories:
		var chip := _make_label(str(c["label"]), 28, c["color"], true)
		legend.add_child(chip)

	var hint := _make_label("Tap a word to change its label. Tap again to cycle.", 30, C_MUTED, false)
	_active_vbox.add_child(hint)

	var flow := HFlowContainer.new()
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flow.add_theme_constant_override("h_separation", 4)
	flow.add_theme_constant_override("v_separation", 12)
	_active_vbox.add_child(flow)

	var selected_cat: Array = []
	var buttons: Array = []

	for i in tokens.size():
		selected_cat.append("")

	var answer_map: Dictionary = {}
	var ans_raw: Variant = _exercise.get("answer_indices", _exercise.get("answers", {}))

	if ans_raw is Array:
		for i in ans_raw.size():
			var cat_id := _category_id_from_value(ans_raw[i], categories)
			if cat_id != "":
				answer_map[i] = cat_id

	elif ans_raw is Dictionary:
		for k in ans_raw:
			var idx := int(str(k))
			answer_map[idx] = _category_id_from_value(ans_raw[k], categories)

	for i in tokens.size():
		var idx := i

		var pair := VBoxContainer.new()
		pair.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pair.add_theme_constant_override("separation", 0)
		flow.add_child(pair)

		var wb := Button.new()
		wb.mouse_filter = Control.MOUSE_FILTER_PASS
		wb.text = str(tokens[idx])
		wb.add_theme_font_size_override("font_size", 34)

		if _font_regular:
			wb.add_theme_font_override("font", _font_regular)

		_update_multi_word_style(wb, "", categories)

		pair.add_child(wb)
		buttons.append(wb)

		wb.pressed.connect(_on_multi_word_pressed.bind(idx, buttons, selected_cat, categories))

		var fb := Label.new()
		fb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fb.add_theme_font_size_override("font_size", 20)
		fb.visible = false
		pair.add_child(fb)

		_items.append({
			"type": "text_highlight_multi",
			"get": func(): return str(selected_cat[idx]),
			"answer": str(answer_map.get(idx, "")),
			"feedback": fb,
			"explanation_en": "",
			"explanation_fa": "",
		})


func _on_multi_word_pressed(idx: int, buttons: Array, selected_cat: Array, categories: Array) -> void:
	if categories.is_empty():
		return

	var current := -1

	for i in categories.size():
		if str(categories[i]["id"]) == str(selected_cat[idx]):
			current = i
			break

	var next := current + 1

	if next >= categories.size():
		selected_cat[idx] = ""
	else:
		selected_cat[idx] = str(categories[next]["id"])

	_update_multi_word_style(buttons[idx], str(selected_cat[idx]), categories)


func _update_multi_word_style(btn: Button, cat_id: String, categories: Array) -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(6)
	style.set_content_margin_all(6)

	if cat_id == "":
		style.bg_color = Color(1, 1, 1, 0)
		style.border_width_bottom = 1
		style.border_color = Color("#CBD5E1")
	else:
		var col := _get_category_color(cat_id, categories)
		style.bg_color = Color(col.r, col.g, col.b, 0.22)
		style.border_width_bottom = 3
		style.border_color = col

	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)


func _normalize_categories(raw: Array) -> Array:
	var out: Array = []

	var default_colors := [
		Color("#2563EB"),
		Color("#16A34A"),
		Color("#DC2626"),
		Color("#F59E0B"),
		Color("#7C3AED"),
		Color("#0891B2"),
	]

	for i in raw.size():
		var c = raw[i]

		var id := ""
		var label := ""
		var color: Color = default_colors[i % default_colors.size()]

		if c is Dictionary:
			id = str(c.get("id", c.get("label", "cat_%d" % i)))
			label = _get_en_text(c.get("label", id))

			if c.has("color"):
				color = Color(str(c.get("color")))
		else:
			id = str(c)
			label = str(c)

		if label == "":
			label = id

		out.append({
			"id": id,
			"label": label,
			"color": color,
		})

	return out


func _category_id_from_value(val: Variant, categories: Array) -> String:
	var s := str(val)

	if s == "":
		return ""

	for c in categories:
		if s == str(c["id"]) or _normalize(s) == _normalize(str(c["label"])):
			return str(c["id"])

	return s


func _get_category_color(cat_id: String, categories: Array) -> Color:
	for c in categories:
		if str(c["id"]) == cat_id:
			return c["color"]

	return C_PRIMARY


# ------------------------------------------------------------
# TRANSFORMATION
# ------------------------------------------------------------
func _build_transformation() -> void:
	for item in _exercise.get("items", []):
		var item_vbox := VBoxContainer.new()
		item_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_vbox.add_theme_constant_override("separation", 10)
		_active_vbox.add_child(item_vbox)

		_add_item_media(item, item_vbox)

		var prompt := _make_label(_get_item_main_text(item), 38, C_TEXT, true)
		item_vbox.add_child(prompt)

		var task_raw = item.get("task", "")
		if _get_en_text(task_raw) != "":
			var task := _make_label("Task: " + _get_en_text(task_raw), 32, C_MUTED, false)
			task.set_meta("text_fa", _get_fa_text(task_raw))
			item_vbox.add_child(task)

		var le := _make_line_edit("Write your answer...")
		item_vbox.add_child(le)

		_items.append({
			"type": "transformation",
			"get": func(): return le.text,
			"answer": item.get("answer", []),
			"feedback": _make_feedback(item_vbox),
			"explanation_en": _get_en_text(item.get("explanation", "")),
			"explanation_fa": _get_fa_text(item.get("explanation", "")),
			"answer_patterns": item.get("answer_patterns", []),
			"required_words": item.get("required_words", []),
			"forbidden_words": item.get("forbidden_words", []),
		})


# ------------------------------------------------------------
# ERROR CORRECTION
# ------------------------------------------------------------
func _build_error_correction() -> void:
	for item in _exercise.get("items", []):
		var item_vbox := VBoxContainer.new()
		item_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_vbox.add_theme_constant_override("separation", 12)
		_active_vbox.add_child(item_vbox)

		_add_item_media(item, item_vbox)

		var s_raw = item.get("sentence", item.get("text", ""))
		var sentence_text := _get_en_text(s_raw)

		var wrong: String = str(item.get("wrong_word", item.get("target", "")))

		var rtl := RichTextLabel.new()
		rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rtl.bbcode_enabled = true
		rtl.fit_content = true
		rtl.scroll_active = false
		rtl.add_theme_font_size_override("normal_font_size", 38)
		rtl.add_theme_color_override("default_color", C_TEXT)

		if _font_regular:
			rtl.add_theme_font_override("normal_font", _font_regular)

		var marked := sentence_text

		if wrong != "":
			marked = sentence_text.replace(wrong, "[color=#DC2626][u]" + wrong + "[/u][/color]")

		rtl.text = marked
		item_vbox.add_child(rtl)

		var le := _make_line_edit("Type the correction...")
		item_vbox.add_child(le)

		_items.append({
			"type": "error_correction",
			"get": func(): return le.text,
			"answer": item.get("answer", ""),
			"feedback": _make_feedback(item_vbox),
			"explanation_en": _get_en_text(item.get("explanation", "")),
			"explanation_fa": _get_fa_text(item.get("explanation", "")),
		})


# ------------------------------------------------------------
# WORD BUILDING
# ------------------------------------------------------------
func _build_word_building() -> void:
	var options: Array = _exercise.get("options", [])

	var option_texts: Array = []
	for opt in options:
		option_texts.append(_get_option_text(opt))

	for item in _exercise.get("items", []):
		var item_vbox := VBoxContainer.new()
		item_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_vbox.add_theme_constant_override("separation", 12)
		_active_vbox.add_child(item_vbox)

		_add_item_media(item, item_vbox)

		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 10)
		item_vbox.add_child(row)

		var prefix_label := _make_label(_get_en_text(item.get("prefix", "")) + "  +", 40, C_TEXT, true)
		row.add_child(prefix_label)

		var ob := _make_option_dropdown(option_texts)
		row.add_child(ob)

		var answer: Variant = item.get("answer", "")

		if answer is int and answer >= 0 and answer < option_texts.size():
			answer = option_texts[answer]
		elif answer is String:
			for opt in options:
				if opt is Dictionary and str(opt.get("id", "")) == str(answer):
					answer = _get_option_text(opt)
					break

		_items.append({
			"type": "word_building",
			"get": func():
				if ob.selected > 0:
					return ob.get_item_text(ob.selected)
				return "",
			"answer": answer,
			"feedback": _make_feedback(item_vbox),
			"explanation_en": "",
			"explanation_fa": "",
		})


# ------------------------------------------------------------
# WORD SEARCH
# JSON:
# {
#   "type": "word_search",
#   "words": ["lion", "zebra"],
#   "grid": ["LIONX", "ZEBRA"],
#   "answer_cells": [[0,0],[0,1],[0,2],[0,3],[1,0],[1,1],[1,2],[1,3],[1,4]]
# }
# ------------------------------------------------------------
func _build_word_search() -> void:
	var grid_rows: Array = _exercise.get("grid", [])

	var answer_cells: Variant = _exercise.get("answer_cells", [])
	var answer_set: Dictionary = {}

	if answer_cells is Array:
		for cell in answer_cells:
			if cell is Array and cell.size() >= 2:
				answer_set["%d_%d" % [int(cell[0]), int(cell[1])]] = true
			else:
				answer_set[str(cell).replace(" ", "")] = true

	elif answer_cells is Dictionary:
		for key in answer_cells:
			answer_set[str(key).replace(" ", "")] = true

	var word_list: Array = _exercise.get("words", [])

	if word_list.size() > 0:
		var display_words: Array = []
		for w in word_list:
			display_words.append(_get_option_text(w))

		var wl := _make_label("Find: " + _join_string_array(display_words, ", "), 32, C_MUTED, false)
		_active_vbox.add_child(wl)

	var cols := 0
	if grid_rows.size() > 0:
		cols = str(grid_rows[0]).length()

	var grid := GridContainer.new()
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.columns = maxi(cols, 1)
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	_active_vbox.add_child(grid)

	for r in grid_rows.size():
		var row_text: String = str(grid_rows[r])

		for c in row_text.length():
			var letter: String = row_text[c]

			var cell_box := VBoxContainer.new()
			cell_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell_box.add_theme_constant_override("separation", 0)
			grid.add_child(cell_box)

			var wb := _make_word_toggle(letter)
			cell_box.add_child(wb)

			var fb := Label.new()
			fb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			fb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			fb.add_theme_font_size_override("font_size", 18)
			fb.visible = false
			cell_box.add_child(fb)

			var is_target: bool = answer_set.has("%d_%d" % [r, c])

			_items.append({
				"type": "word_search_cell",
				"get": func(): return wb.button_pressed,
				"answer": is_target,
				"feedback": fb,
				"explanation_en": "",
				"explanation_fa": "",
			})


# ------------------------------------------------------------
# CHART FILL
# ------------------------------------------------------------
func _build_chart_fill() -> void:
	var columns: int = _exercise.get("columns", 2)
	var headers: Array = _exercise.get("headers", [])
	var rows: Array = _exercise.get("rows", [])
	var show_labels: bool = _exercise.get("show_labels", true)

	var grid := GridContainer.new()
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 16)
	_active_vbox.add_child(grid)

	if show_labels and not headers.is_empty():
		for header in headers:
			var h := _make_label(_get_en_text(header), 34, C_PRIMARY, true)
			h.set_meta("text_fa", _get_fa_text(header))
			h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			grid.add_child(h)

	for row in rows:
		var cells: Array = row.get("cells", [])

		for cell in cells:
			var cell_box := VBoxContainer.new()
			cell_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell_box.add_theme_constant_override("separation", 4)
			cell_box.alignment = BoxContainer.ALIGNMENT_CENTER
			grid.add_child(cell_box)

			if cell.get("editable", false):
				var placeholder: String = _get_en_text(cell.get("placeholder", "..."))
				var le := _make_chart_input(placeholder)
				cell_box.add_child(le)

				_items.append({
					"type": "chart_fill",
					"get": func(): return le.text,
					"answer": cell.get("answer", []),
					"feedback": _make_feedback(cell_box),
					"explanation_en": _get_en_text(cell.get("explanation", {})),
					"explanation_fa": _get_fa_text(cell.get("explanation", {})),
				})
			else:
				var text_val: Dictionary = cell.get("text", {})
				var lbl := _make_label(_get_en_text(text_val), 34, C_TEXT, false)
				lbl.set_meta("text_fa", _get_fa_text(text_val))
				lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				cell_box.add_child(lbl)


# ------------------------------------------------------------
# ODD ONE OUT
# ------------------------------------------------------------
func _build_odd_one_out() -> void:
	for item in _exercise.get("items", []):
		var item_vbox := VBoxContainer.new()
		item_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_vbox.add_theme_constant_override("separation", 12)
		_active_vbox.add_child(item_vbox)

		_add_item_media(item, item_vbox)

		var words_raw: Array = item.get("words", item.get("options", []))

		var word_texts: Array = []
		for w in words_raw:
			word_texts.append(_get_option_text(w))

		var question_text := "Which word does not belong?"
		if item.has("question"):
			question_text = _get_en_text(item.get("question", ""))

		var q_label := _make_label(question_text, 34, C_TEXT, true)
		item_vbox.add_child(q_label)

		var group := ButtonGroup.new()
		var option_btns: Array[Button] = []

		var grid := GridContainer.new()
		grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.columns = maxi(mini(word_texts.size(), 3), 1)
		grid.add_theme_constant_override("h_separation", 16)
		grid.add_theme_constant_override("v_separation", 8)
		item_vbox.add_child(grid)

		for w in word_texts:
			var b := _make_select_button(str(w), group, C_WARNING)
			option_btns.append(b)
			grid.add_child(b)

		var answer: Variant = item.get("answer", -1)

		if answer is String:
			answer = _find_option_index(word_texts, answer)

		_items.append({
			"type": "odd_one_out",
			"get": func():
				for i in option_btns.size():
					if option_btns[i].button_pressed:
						return i
				return -1,
			"answer": answer,
			"feedback": _make_feedback(item_vbox),
			"explanation_en": _get_en_text(item.get("explanation", "")),
			"explanation_fa": _get_fa_text(item.get("explanation", "")),
		})


# ------------------------------------------------------------
# GRAMMAR CHOICE
# ------------------------------------------------------------
func _build_grammar_choice() -> void:
	for item in _exercise.get("items", []):
		var item_vbox := VBoxContainer.new()
		item_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_vbox.add_theme_constant_override("separation", 12)
		_active_vbox.add_child(item_vbox)

		_add_item_media(item, item_vbox)

		var sentence: String = _get_en_text(item.get("sentence", item.get("text", "")))

		var rtl := RichTextLabel.new()
		rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rtl.bbcode_enabled = true
		rtl.fit_content = true
		rtl.scroll_active = false
		rtl.add_theme_font_size_override("normal_font_size", 38)
		rtl.add_theme_color_override("default_color", C_TEXT)

		if _font_regular:
			rtl.add_theme_font_override("normal_font", _font_regular)

		var highlighted := sentence.replace("___", "[color=#2563EB][u]___[/u][/color]")
		rtl.text = highlighted
		item_vbox.add_child(rtl)

		var options: Array = item.get("options", [])

		var option_texts: Array = []
		for opt in options:
			option_texts.append(_get_option_text(opt))

		var group := ButtonGroup.new()
		var option_btns: Array[Button] = []

		var grid := GridContainer.new()
		grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.columns = maxi(mini(option_texts.size(), 2), 1)
		grid.add_theme_constant_override("h_separation", 16)
		grid.add_theme_constant_override("v_separation", 8)
		item_vbox.add_child(grid)

		for opt in option_texts:
			var b := _make_select_button(str(opt), group, C_INFO)
			option_btns.append(b)
			grid.add_child(b)

		var answer: Variant = item.get("answer", -1)

		if answer is String:
			answer = _find_option_index(options, answer)

		_items.append({
			"type": "grammar_choice",
			"get": func():
				for i in option_btns.size():
					if option_btns[i].button_pressed:
						return i
				return -1,
			"answer": answer,
			"feedback": _make_feedback(item_vbox),
			"explanation_en": _get_en_text(item.get("explanation", "")),
			"explanation_fa": _get_fa_text(item.get("explanation", "")),
		})


# ------------------------------------------------------------
# PASSIVE TRANSFORMATION
# ------------------------------------------------------------
func _build_passive_transformation() -> void:
	for item in _exercise.get("items", []):
		var item_vbox := VBoxContainer.new()
		item_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_vbox.add_theme_constant_override("separation", 12)
		_active_vbox.add_child(item_vbox)

		_add_item_media(item, item_vbox)

		var active_text: String = _get_en_text(item.get("active", item.get("prompt", "")))

		var label := _make_label("Active: " + active_text, 36, C_TEXT, true)
		item_vbox.add_child(label)

		var hint_text := _get_en_text(item.get("hint", "Rewrite in passive voice:"))
		var hint := _make_label("Task: " + hint_text, 32, C_MUTED, false)
		item_vbox.add_child(hint)

		var le := _make_line_edit("Type the passive sentence...")
		item_vbox.add_child(le)

		_items.append({
			"type": "passive_transformation",
			"get": func(): return le.text,
			"answer": item.get("answer", []),
			"feedback": _make_feedback(item_vbox),
			"explanation_en": _get_en_text(item.get("explanation", "")),
			"explanation_fa": _get_fa_text(item.get("explanation", "")),
			"answer_patterns": item.get("answer_patterns", []),
			"required_words": item.get("required_words", []),
			"forbidden_words": item.get("forbidden_words", []),
		})


# ------------------------------------------------------------
# GRAMMAR IDENTIFICATION
# ------------------------------------------------------------
func _build_grammar_identification() -> void:
	for item in _exercise.get("items", []):
		var item_vbox := VBoxContainer.new()
		item_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_vbox.add_theme_constant_override("separation", 12)
		_active_vbox.add_child(item_vbox)

		_add_item_media(item, item_vbox)

		var text_val: String = _get_en_text(item.get("text", item.get("sentence", "")))
		var target: String = str(item.get("target", ""))

		var rtl := RichTextLabel.new()
		rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rtl.bbcode_enabled = true
		rtl.fit_content = true
		rtl.scroll_active = false
		rtl.add_theme_font_size_override("normal_font_size", 36)
		rtl.add_theme_color_override("default_color", C_TEXT)

		if _font_regular:
			rtl.add_theme_font_override("normal_font", _font_regular)

		var highlighted := text_val

		if target != "":
			highlighted = text_val.replace(target, "[color=#DC2626][u]" + target + "[/u][/color]")

		rtl.text = highlighted
		item_vbox.add_child(rtl)

		var question := _make_label("What is the grammatical form of the underlined word or phrase?", 32, C_MUTED, false)
		item_vbox.add_child(question)

		var options: Array = item.get("options", [])

		var option_texts: Array = []
		for opt in options:
			option_texts.append(_get_option_text(opt))

		var group := ButtonGroup.new()
		var option_btns: Array[Button] = []

		for opt in option_texts:
			var b := _make_select_button(str(opt), group, C_PURPLE)
			option_btns.append(b)
			item_vbox.add_child(b)

		var answer: Variant = item.get("answer", -1)

		if answer is String:
			answer = _find_option_index(options, answer)

		_items.append({
			"type": "grammar_identification",
			"get": func():
				for i in option_btns.size():
					if option_btns[i].button_pressed:
						return i
				return -1,
			"answer": answer,
			"feedback": _make_feedback(item_vbox),
			"explanation_en": _get_en_text(item.get("explanation", "")),
			"explanation_fa": _get_fa_text(item.get("explanation", "")),
		})


# ------------------------------------------------------------
# QUESTION FORMATION
# ------------------------------------------------------------
func _build_question_formation() -> void:
	for item in _exercise.get("items", []):
		var item_vbox := VBoxContainer.new()
		item_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_vbox.add_theme_constant_override("separation", 12)
		_active_vbox.add_child(item_vbox)

		_add_item_media(item, item_vbox)

		var prompt_text: String = _get_en_text(item.get("prompt", "Form a question:"))

		var label := _make_label(prompt_text, 36, C_TEXT, true)
		label.set_meta("text_fa", _get_fa_text(item.get("prompt", "")))
		item_vbox.add_child(label)

		var le := _make_line_edit("Type your question...")
		item_vbox.add_child(le)

		_items.append({
			"type": "question_formation",
			"get": func(): return le.text,
			"answer": item.get("answer", []),
			"feedback": _make_feedback(item_vbox),
			"explanation_en": _get_en_text(item.get("explanation", "")),
			"explanation_fa": _get_fa_text(item.get("explanation", "")),
			"answer_patterns": item.get("answer_patterns", []),
			"required_words": item.get("required_words", []),
			"forbidden_words": item.get("forbidden_words", []),
		})


# ------------------------------------------------------------
# TOKEN LABEL
# For S / O / V / Adv labeling.
# JSON:
# {
#   "type": "token_label",
#   "labels": ["S", "O", "V", "Adv"],
#   "items": [
#     {
#       "tokens": [
#         {"text": "The man", "answer": "S"},
#         {"text": "is eating", "answer": "V"},
#         {"text": "lunch", "answer": "O"},
#         {"text": "quickly", "answer": "Adv"}
#       ]
#     }
#   ]
# }
# ------------------------------------------------------------
func _build_token_label() -> void:
	var default_labels: Array = _exercise.get("labels", [])

	if default_labels.is_empty():
		default_labels = ["S", "O", "V", "Adv"]

	for item in _exercise.get("items", []):
		var item_vbox := VBoxContainer.new()
		item_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_vbox.add_theme_constant_override("separation", 14)
		_active_vbox.add_child(item_vbox)

		_add_item_media(item, item_vbox)

		var inst := _get_en_text(item.get("instruction", ""))
		if inst != "":
			item_vbox.add_child(_make_label(inst, 32, C_MUTED, false))

		var labels_raw: Array = item.get("labels", default_labels)
		var categories := _normalize_categories(labels_raw)

		var label_ids: Array = []
		var label_names: Array = []

		for c in categories:
			label_ids.append(str(c["id"]))
			label_names.append(str(c["label"]))

		var flow := HFlowContainer.new()
		flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flow.add_theme_constant_override("h_separation", 14)
		flow.add_theme_constant_override("v_separation", 12)
		item_vbox.add_child(flow)

		var tokens: Array = item.get("tokens", [])
		var token_answers: Array = item.get("answers", [])

		for t_i in tokens.size():
			var token = tokens[t_i]

			var token_box := VBoxContainer.new()
			token_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			token_box.add_theme_constant_override("separation", 4)
			flow.add_child(token_box)

			var token_text := ""
			var ans := ""
			var expl_en := ""
			var expl_fa := ""

			if token is Dictionary:
				token_text = _get_en_text(token.get("text", token.get("word", "")))
				ans = _category_id_from_value(token.get("answer", ""), categories)
				expl_en = _get_en_text(token.get("explanation", ""))
				expl_fa = _get_fa_text(token.get("explanation", ""))
			else:
				token_text = _get_en_text(token)

				if t_i < token_answers.size():
					ans = _category_id_from_value(token_answers[t_i], categories)

			var word_label := _make_label(token_text, 36, C_TEXT, true)
			token_box.add_child(word_label)

			var ob := OptionButton.new()
			ob.mouse_filter = Control.MOUSE_FILTER_PASS
			ob.add_item("—")

			for lname in label_names:
				ob.add_item(lname)

			ob.selected = 0
			ob.add_theme_font_size_override("font_size", 28)

			if _font_regular:
				ob.add_theme_font_override("font", _font_regular)

			token_box.add_child(ob)

			var fb := _make_feedback(token_box)

			var ids := label_ids.duplicate()

			_items.append({
				"type": "token_label",
				"get": func():
					if ob.selected > 0 and ob.selected - 1 < ids.size():
						return ids[ob.selected - 1]
					return "",
				"answer": ans,
				"feedback": fb,
				"explanation_en": expl_en,
				"explanation_fa": expl_fa,
			})


# ------------------------------------------------------------
# IMAGE CHOICE
# JSON:
# {
#   "type": "image_choice",
#   "question": "Which picture shows a zoo?",
#   "options": [
#     {"id": "zoo", "image": "res://assets/images/zoo.png", "label": "Zoo"},
#     {"id": "school", "image": "res://assets/images/school.png", "label": "School"}
#   ],
#   "answer": "zoo"
# }
# ------------------------------------------------------------
func _build_image_choice() -> void:
	var question := _get_en_text(_exercise.get("question", _exercise.get("prompt", "")))

	if question != "":
		_active_vbox.add_child(_make_label(question, 38, C_TEXT, true))

	var options: Array = _exercise.get("options", [])

	var flow := HFlowContainer.new()
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flow.add_theme_constant_override("h_separation", 14)
	flow.add_theme_constant_override("v_separation", 12)
	_active_vbox.add_child(flow)

	var group := ButtonGroup.new()
	var option_btns: Array[Button] = []

	for opt in options:
		var b := _make_image_option_button(opt, group)
		option_btns.append(b)
		flow.add_child(b)

	var answer: Variant = _exercise.get("answer", -1)

	if answer is String:
		answer = _find_option_index(options, answer)

	var fb := _make_feedback(_active_vbox)

	_items.append({
		"type": "image_choice",
		"get": func():
			for i in option_btns.size():
				if option_btns[i].button_pressed:
					return i
			return -1,
		"answer": answer,
		"feedback": fb,
		"explanation_en": _get_en_text(_exercise.get("explanation", "")),
		"explanation_fa": _get_fa_text(_exercise.get("explanation", "")),
	})


# ------------------------------------------------------------
# IMAGE MATCH
# JSON:
# {
#   "type": "image_match",
#   "options": [
#     {"id": "germany", "image": "res://assets/images/germany.png", "label": "Germany"},
#     {"id": "japan", "image": "res://assets/images/japan.png", "label": "Japan"}
#   ],
#   "items": [
#     {"text": "Hallo", "answer": "germany"},
#     {"text": "Konnichiwa", "answer": "japan"}
#   ]
# }
# ------------------------------------------------------------
func _build_image_match() -> void:
	var options: Array = _exercise.get("options", [])

	for item in _exercise.get("items", []):
		var item_vbox := VBoxContainer.new()
		item_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_vbox.add_theme_constant_override("separation", 12)
		_active_vbox.add_child(item_vbox)

		_add_item_media(item, item_vbox)

		var text := _get_item_main_text(item)

		if text != "":
			item_vbox.add_child(_make_label(text, 38, C_TEXT, true))

		var flow := HFlowContainer.new()
		flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flow.add_theme_constant_override("h_separation", 14)
		flow.add_theme_constant_override("v_separation", 12)
		item_vbox.add_child(flow)

		var group := ButtonGroup.new()
		var option_btns: Array[Button] = []

		for opt in options:
			var b := _make_image_option_button(opt, group)
			option_btns.append(b)
			flow.add_child(b)

		var answer: Variant = item.get("answer", -1)

		if answer is String:
			answer = _find_option_index(options, answer)

		_items.append({
			"type": "image_match",
			"get": func():
				for i in option_btns.size():
					if option_btns[i].button_pressed:
						return i
				return -1,
			"answer": answer,
			"feedback": _make_feedback(item_vbox),
			"explanation_en": _get_en_text(item.get("explanation", "")),
			"explanation_fa": _get_fa_text(item.get("explanation", "")),
		})


# ------------------------------------------------------------
# IMAGE HOTSPOT / MAP MARKING
# JSON:
# {
#   "type": "image_hotspot",
#   "image": "res://assets/images/world_map.png",
#   "multi": true,
#   "hotspots": [
#     {"id": "china", "label": "China", "rect": [0.55, 0.35, 0.12, 0.12]},
#     {"id": "egypt", "label": "Egypt", "rect": [0.42, 0.40, 0.08, 0.08]}
#   ],
#   "answer": ["china", "egypt"]
# }
# ------------------------------------------------------------
func _build_image_hotspot() -> void:
	var img_path := _get_first_image_path(_exercise)

	if img_path == "" or not ResourceLoader.exists(img_path):
		_active_vbox.add_child(_make_label("Image not found: " + img_path, 32, C_ERROR, false))
		return

	var tex := load(img_path) as Texture2D

	if tex == null:
		_active_vbox.add_child(_make_label("Could not load image: " + img_path, 32, C_ERROR, false))
		return

	var base_size: Vector2 = tex.get_size()

	if base_size.x <= 0:
		base_size.x = 900
	if base_size.y <= 0:
		base_size.y = 600

	var max_width := float(_exercise.get("max_width", 900))
	var ratio := max_width / base_size.x

	var ctrl := Control.new()
	ctrl.custom_minimum_size = Vector2(max_width, base_size.y * ratio)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_active_vbox.add_child(ctrl)

	var img := TextureRect.new()
	img.texture = tex
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE

	img.anchor_left = 0.0
	img.anchor_top = 0.0
	img.anchor_right = 1.0
	img.anchor_bottom = 1.0

	img.offset_left = 0.0
	img.offset_top = 0.0
	img.offset_right = 0.0
	img.offset_bottom = 0.0

	ctrl.add_child(img)

	var overlay := HotspotOverlay.new()

	overlay.anchor_left = 0.0
	overlay.anchor_top = 0.0
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0

	overlay.offset_left = 0.0
	overlay.offset_top = 0.0
	overlay.offset_right = 0.0
	overlay.offset_bottom = 0.0

	overlay.base_size = base_size
	overlay.hotspots = _exercise.get("hotspots", [])

	var answer_ids: Array = []
	var ans_raw: Variant = _exercise.get("answer", [])

	if ans_raw is Array:
		for a in ans_raw:
			answer_ids.append(str(a))
	else:
		answer_ids.append(str(ans_raw))

	overlay.multi = bool(_exercise.get("multi", answer_ids.size() != 1))

	ctrl.add_child(overlay)

	var fb := _make_feedback(_active_vbox)

	_items.append({
		"type": "image_hotspot",
		"get": func(): return overlay.selected.duplicate(),
		"answer": answer_ids,
		"feedback": fb,
		"answer_display": _join_string_array(answer_ids, ", "),
		"explanation_en": _get_en_text(_exercise.get("explanation", "")),
		"explanation_fa": _get_fa_text(_exercise.get("explanation", "")),
	})


# ============================================================
# WIDGET HELPERS
# ============================================================
func _make_label(text: String, size: int, color: Color, bold: bool) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)

	if bold and _font_bold:
		l.add_theme_font_override("font", _font_bold)
	elif not bold and _font_regular:
		l.add_theme_font_override("font", _font_regular)

	return l


func _make_option_button(text: String, group: ButtonGroup) -> Button:
	return _make_select_button(text, group, C_PRIMARY)


func _make_select_button(text: String, group: ButtonGroup, accent: Color) -> Button:
	var b := Button.new()
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.text = "    " + text
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.toggle_mode = true
	b.button_group = group
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 36)
	b.add_theme_color_override("font_color", Color("#F1F5F9"))
	b.add_theme_color_override("font_hover_color", accent)
	b.add_theme_color_override("font_pressed_color", accent)
	
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#0f1b3d")  # Dark bg
	normal.set_corner_radius_all(10)
	normal.border_width_left = 1
	normal.border_width_right = 1
	normal.border_width_top = 1
	normal.border_width_bottom = 1
	normal.border_color = Color("#3d4a7a")
	normal.set_content_margin_all(14)
	b.add_theme_stylebox_override("normal", normal)
	
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(accent.r, accent.g, accent.b, 0.15)
	hover.border_color = accent.lightened(0.35)
	b.add_theme_stylebox_override("hover", hover)
	
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color(accent.r, accent.g, accent.b, 0.25)
	pressed.border_color = accent
	pressed.border_width_left = 2
	pressed.border_width_right = 2
	pressed.border_width_top = 2
	pressed.border_width_bottom = 2
	b.add_theme_stylebox_override("pressed", pressed)
	
	if _font_regular:
		b.add_theme_font_override("font", _font_regular)
	return b

func _make_image_option_button(opt: Variant, group: ButtonGroup) -> Button:
	var b := Button.new()
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.toggle_mode = true
	b.button_group = group
	b.custom_minimum_size = Vector2(220, 180)
	b.text = _get_option_text(opt)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", 30)

	if opt is Dictionary:
		var path := str(opt.get("image", opt.get("path", "")))

		if path != "" and ResourceLoader.exists(path):
			var tex := load(path) as Texture2D

			if tex:
				b.icon = tex
				b.expand_icon = true
				b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color.WHITE
	normal.set_corner_radius_all(12)
	normal.border_width_left = 1
	normal.border_width_right = 1
	normal.border_width_top = 1
	normal.border_width_bottom = 1
	normal.border_color = Color("#CBD5E1")
	normal.set_content_margin_all(12)
	b.add_theme_stylebox_override("normal", normal)

	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(C_PRIMARY.r, C_PRIMARY.g, C_PRIMARY.b, 0.07)
	hover.border_color = C_PRIMARY.lightened(0.35)
	b.add_theme_stylebox_override("hover", hover)

	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color(C_PRIMARY.r, C_PRIMARY.g, C_PRIMARY.b, 0.14)
	pressed.border_color = C_PRIMARY
	pressed.border_width_left = 2
	pressed.border_width_right = 2
	pressed.border_width_top = 2
	pressed.border_width_bottom = 2
	b.add_theme_stylebox_override("pressed", pressed)

	if _font_regular:
		b.add_theme_font_override("font", _font_regular)

	return b


func _make_option_dropdown(options: Array, placeholder := "Choose") -> Dropdown:
	var dd := Dropdown.new()
	dd.mouse_filter = Control.MOUSE_FILTER_PASS
	dd.placeholder = placeholder
	dd.set_font(_font_regular)

	for opt in options:
		dd.add_item(str(opt))

	dd.selected = 0
	dd.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	return dd


func _make_line_edit(placeholder: String) -> LineEdit:
	var le := LineEdit.new()
	le.mouse_filter = Control.MOUSE_FILTER_PASS
	le.placeholder_text = placeholder
	le.add_theme_font_size_override("font_size", 36)
	le.add_theme_color_override("font_color", Color("#F1F5F9"))
	le.add_theme_color_override("font_placeholder_color", Color("#64748B"))
	if _font_regular:
		le.add_theme_font_override("font", _font_regular)
	
	var le_style := StyleBoxFlat.new()
	le_style.bg_color = Color("#0f1b3d")  # Dark input bg
	le_style.set_corner_radius_all(10)
	le_style.border_width_bottom = 2
	le_style.border_color = C_PRIMARY.lightened(0.3)
	le_style.set_content_margin_all(14)
	le.add_theme_stylebox_override("normal", le_style)
	
	var le_hover: StyleBoxFlat = le_style.duplicate()
	le_hover.border_color = C_PRIMARY
	le.add_theme_stylebox_override("hover", le_hover)
	
	var le_focus: StyleBoxFlat = le_style.duplicate()
	le_focus.border_color = C_PRIMARY
	le.add_theme_stylebox_override("focus", le_focus)
	le.add_theme_color_override("caret_color", C_PRIMARY)
	return le

func _make_chart_input(placeholder: String) -> LineEdit:
	var le := LineEdit.new()
	le.mouse_filter = Control.MOUSE_FILTER_PASS
	le.placeholder_text = placeholder
	le.add_theme_font_size_override("font_size", 34)
	le.add_theme_color_override("font_color", Color.BLACK)

	if _font_regular:
		le.add_theme_font_override("font", _font_regular)

	var le_style := StyleBoxFlat.new()
	le_style.bg_color = Color.WHITE
	le_style.set_corner_radius_all(8)
	le_style.border_width_bottom = 2
	le_style.border_color = C_PRIMARY.lightened(0.4)
	le_style.set_content_margin_all(10)
	le.add_theme_stylebox_override("normal", le_style)

	var le_focus: StyleBoxFlat = le_style.duplicate()
	le_focus.border_color = C_PRIMARY
	le.add_theme_stylebox_override("focus", le_focus)

	le.add_theme_color_override("caret_color", C_PRIMARY)

	return le


func _make_chip_button(text: String, filled := false) -> Button:
	var b := Button.new()
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.text = text
	b.add_theme_font_size_override("font_size", 34)
	b.add_theme_color_override("font_color", Color("#000000") if filled else Color("#F1F5F9"))
	b.add_theme_color_override("font_hover_color", Color("#000000") if filled else C_PRIMARY)
	if _font_regular:
		b.add_theme_font_override("font", _font_regular)
	
	var style := StyleBoxFlat.new()
	style.bg_color = C_PRIMARY if filled else Color("#0f1b3d")
	style.set_corner_radius_all(10)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = C_PRIMARY if filled else Color("#3d4a7a")
	style.set_content_margin_all(12)
	b.add_theme_stylebox_override("normal", style)
	
	var hover: StyleBoxFlat = style.duplicate()
	hover.bg_color = style.bg_color.lightened(0.15)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	
	var disabled: StyleBoxFlat = style.duplicate()
	disabled.bg_color = Color("#1a2540")
	disabled.border_color = Color("#2d3a6a")
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_color_override("font_disabled_color", Color("#4a5580"))
	return b

func _make_word_toggle(word: String) -> Button:
	var b := Button.new()
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.text = word
	b.toggle_mode = true
	b.add_theme_font_size_override("font_size", 36)
	b.add_theme_color_override("font_color", Color("#F1F5F9"))
	b.add_theme_color_override("font_pressed_color", Color("#000000"))
	b.add_theme_color_override("font_hover_color", C_PRIMARY)
	if _font_regular:
		b.add_theme_font_override("font", _font_regular)
	
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	normal.set_corner_radius_all(6)
	normal.set_content_margin_all(6)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal.duplicate())
	
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color("#fbbf24")  # Amber highlight
	pressed.set_corner_radius_all(6)
	pressed.set_content_margin_all(6)
	b.add_theme_stylebox_override("pressed", pressed)
	return b

func _make_feedback(parent: Node) -> Label:
	var fb := Label.new()
	fb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fb.autowrap_mode = TextServer.AUTOWRAP_WORD
	fb.add_theme_font_size_override("font_size", 32)
	fb.visible = false
	if _font_bold:
		fb.add_theme_font_override("font", _font_bold)
	parent.add_child(fb)
	return fb

# ============================================================
# GRADING
# ============================================================
func _on_check_pressed() -> void:
	if _is_graded:
		_reset_for_retry()
		return

	var correct := 0
	var total := 0

	for item in _items:
		if not item.has("get"):
			continue

		total += 1

		var user_answer = item["get"].call()
		var is_correct := _is_item_correct(item, user_answer)

		var fb: Label = item.get("feedback", null)

		if fb == null:
			continue

		fb.visible = true

		var answer_text: String = str(item.get("answer_display", _format_answer(item.get("answer"))))
		var item_type := str(item.get("type", ""))

		if is_correct:
			correct += 1

			if item_type in ["text_highlight", "text_highlight_multi", "word_search_cell"]:
				fb.text = "✓"
			else:
				fb.text = "Correct!"

			fb.add_theme_color_override("font_color", C_SUCCESS)
		else:
			if item_type in ["text_highlight", "text_highlight_multi", "word_search_cell"]:
				fb.text = "✗"
			else:
				fb.text = "Correct answer: " + answer_text

				var expl := str(item.get("explanation_en", ""))
				if expl != "":
					fb.text += "\n" + expl

			fb.add_theme_color_override("font_color", C_ERROR)

	_is_graded = true

	if _score_banner:
		_score_banner.visible = true

		if total > 0 and correct == total:
			_score_banner.text = "Excellent! %d/%d correct!" % [correct, total]
			_score_banner.add_theme_color_override("font_color", C_SUCCESS)
		else:
			_score_banner.text = "You got %d/%d." % [correct, total]
			_score_banner.add_theme_color_override("font_color", C_PRIMARY)

	if _note_label:
		_note_label.visible = true

	if _check_btn:
		_check_btn.text = "Try Again"

	exercise_checked.emit(str(_exercise.get("exercise_id", "")), correct, total)


func _is_item_correct(item: Dictionary, user_answer: Variant) -> bool:
	var item_type := str(item.get("type", ""))

	if item_type == "image_hotspot":
		var u: Array = []

		if user_answer is Array:
			for x in user_answer:
				u.append(str(x))

		var c: Array = []
		var ans = item.get("answer", [])

		if ans is Array:
			for x in ans:
				c.append(str(x))
		else:
			c.append(str(ans))

		u.sort()
		c.sort()

		return _compare(u, c)

	if _compare(user_answer, item.get("answer")):
		return true

	var user_str := str(user_answer)
	var norm := _normalize(user_str)

	if item.has("answer_patterns"):
		for pat in item["answer_patterns"]:
			var rx := RegEx.new()

			if rx.compile(str(pat)) == OK:
				if rx.search(user_str):
					return true

	if item.has("required_words"):
		var req_ok := true

		for w in item["required_words"]:
			if not norm.contains(_normalize(str(w))):
				req_ok = false
				break

		if req_ok:
			for w in item.get("forbidden_words", []):
				if norm.contains(_normalize(str(w))):
					req_ok = false
					break

		if req_ok:
			return true

	return false


func _compare(user_answer: Variant, correct_answer: Variant) -> bool:
	if user_answer == null:
		return false

	if correct_answer == null:
		return false

	if correct_answer is Array:
		if correct_answer.is_empty():
			return str(user_answer).strip_edges() != ""

		if user_answer is Array:
			if user_answer.size() != correct_answer.size():
				return false

			for i in user_answer.size():
				if not _compare(user_answer[i], correct_answer[i]):
					return false

			return true

		var normalized := _normalize(str(user_answer))

		for accepted in correct_answer:
			if _normalize(str(accepted)) == normalized:
				return true

		return false

	if user_answer is Array:
		return false

	if correct_answer is bool:
		if user_answer is bool:
			return user_answer == correct_answer

		var s := _normalize(str(user_answer))

		if s in ["true", "t", "yes", "y"]:
			return correct_answer == true

		if s in ["false", "f", "no", "n"]:
			return correct_answer == false

		return false

	if correct_answer is int and user_answer is String and user_answer.is_valid_int():
		return int(user_answer) == int(correct_answer)

	if user_answer is String and correct_answer is String:
		return _normalize(user_answer) == _normalize(correct_answer)

	return user_answer == correct_answer


func _normalize(s: String) -> String:
	s = str(s).to_lower().strip_edges()

	s = s.replace(char(0x2019), "'")
	s = s.replace("'", "")

	for ch in [".", ",", "!", "?", ";", ":", "\"", "(", ")", "[", "]", "{", "}", "/"]:
		s = s.replace(ch, " ")

	while s.contains("  "):
		s = s.replace("  ", " ")

	return s.strip_edges()


func _format_answer(answer: Variant) -> String:
	if answer is Array:
		var parts: Array = []

		for a in answer:
			parts.append(_format_answer(a))

		return _join_string_array(parts, " / ")

	if answer is bool:
		return "True" if answer else "False"

	if answer is Dictionary:
		return _get_en_text(answer)

	if answer == null:
		return ""

	return str(answer)


func _reset_for_retry() -> void:
	_is_graded = false

	if _score_banner:
		_score_banner.visible = false

	if _check_btn:
		_check_btn.text = "Check Answer"

	build(_exercise, false)


func _on_reveal_sample() -> void:
	var is_showing := false

	for item in _items:
		if item.has("sample_label") and item["sample_label"] != null:
			item["sample_label"].visible = not item["sample_label"].visible

			if item["sample_label"].visible:
				is_showing = true

	if _reveal_btn:
		if is_showing:
			_reveal_btn.text = "Hide Sample Answer"
		else:
			_reveal_btn.text = "Show Sample Answer"


func _on_open_ended_done() -> void:
	if _note_label:
		_note_label.visible = true

	if _done_btn:
		_done_btn.text = "Saved"

	exercise_checked.emit(str(_exercise.get("exercise_id", "")), 1, 1)


# ============================================================
# CUSTOM DROPDOWN
# ============================================================
class Dropdown extends Button:
	signal item_selected(index: int)

	var selected: int = 0
	var placeholder := "Choose"

	var _options: Array = []
	var _font: Font
	var _popup: PopupPanel
	var _scroll: ScrollContainer
	var _list: VBoxContainer

	const _ITEM_FONT := 35
	const _MAX_W := 900
	const _MIN_W := 360
	const _MAX_H := 560
	const _PAD_L := 16
	const _PAD_R := 14
	const _PAD_V := 10


	func set_font(f: Font) -> void:
		_font = f


	func add_item(label: String) -> void:
		_options.append(label)


	func get_item_text(index: int) -> String:
		if index <= 0 or index > _options.size():
			return "— " + placeholder + " —"

		return str(_options[index - 1])


	func _ready() -> void:
		alignment = HORIZONTAL_ALIGNMENT_LEFT
		clip_text = true
		text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		add_theme_font_size_override("font_size", _ITEM_FONT)
		add_theme_color_override("font_color", Color("#F1F5F9"))
		add_theme_color_override("font_hover_color", ExerciseEngine.C_PRIMARY)
		if _font:
			add_theme_font_override("font", _font)
	
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#0f1b3d")  # Dark bg
		style.set_corner_radius_all(10)
		style.border_width_bottom = 2
		style.border_color = ExerciseEngine.C_PRIMARY.lightened(0.3)
		style.set_content_margin_all(12)
		add_theme_stylebox_override("normal", style)
	
		var hover: StyleBoxFlat = style.duplicate()
		hover.border_color = ExerciseEngine.C_PRIMARY
		add_theme_stylebox_override("hover", hover)
	
		var pressed: StyleBoxFlat = hover.duplicate()
		pressed.bg_color = Color(ExerciseEngine.C_PRIMARY.r, ExerciseEngine.C_PRIMARY.g, ExerciseEngine.C_PRIMARY.b, 0.1)
		add_theme_stylebox_override("pressed", pressed)
	
		_build_popup()
		_refresh_face()
		connect("pressed", _open_popup)


	func _build_popup() -> void:
		_popup = PopupPanel.new()
		var panel := StyleBoxFlat.new()
		panel.bg_color = Color("#0f1b3d")  # Dark popup bg
		panel.set_corner_radius_all(14)
		panel.border_width_left = 1
		panel.border_width_right = 1
		panel.border_width_top = 1
		panel.border_width_bottom = 1
		panel.border_color = Color(ExerciseEngine.C_PRIMARY.r, ExerciseEngine.C_PRIMARY.g, ExerciseEngine.C_PRIMARY.b, 0.4)
		panel.shadow_color = Color(0, 0, 0, 0.5)
		panel.shadow_size = 16
		panel.shadow_offset = Vector2(0, 8)
		panel.set_content_margin_all(8)
		_popup.add_theme_stylebox_override("panel", panel)

		_scroll = ScrollContainer.new()
		_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_popup.add_child(_scroll)

		_list = VBoxContainer.new()
		_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_list.add_theme_constant_override("separation", 6)
		_scroll.add_child(_list)

		add_child(_popup)

		_popup.about_to_popup.connect(_on_about_to_popup)


	func _open_popup() -> void:
		var btn_rect := get_global_rect()

		var f: Font = _font if _font else ThemeDB.fallback_font

		var longest := 0.0

		for opt in _options:
			longest = maxf(
				longest,
				f.get_string_size(str(opt), HORIZONTAL_ALIGNMENT_LEFT, -1, _ITEM_FONT).x
			)

		var w := clampi(int(maxf(btn_rect.size.x, longest + 70.0)), _MIN_W, _MAX_W)
		var wrap_w := float(w - 16 - 10 - _PAD_L - _PAD_R)

		_populate(wrap_w)

		var content_h := int(_list.get_combined_minimum_size().y) + 16
		var h := mini(content_h, _MAX_H)

		_scroll.custom_minimum_size = Vector2(w - 16, h - 16)

		_popup.popup(Rect2i(
			Vector2i(int(btn_rect.position.x), int(btn_rect.end.y + 8)),
			Vector2i(w, h)
		))


	func _populate(wrap_w: float) -> void:
		for c in _list.get_children():
			_list.remove_child(c)
			c.queue_free()

		var f: Font = _font if _font else ThemeDB.fallback_font

		var labels := ["— " + placeholder + " —"]
		labels.append_array(_options)

		for i in labels.size():
			var is_sel := (i == selected)
			var is_placeholder := (i == 0)

			var display: String = ("✓  " + str(labels[i])) if is_sel else str(labels[i])

			var row := Button.new()
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.custom_minimum_size.y = f.get_multiline_string_size(
				display,
				HORIZONTAL_ALIGNMENT_LEFT,
				wrap_w,
				_ITEM_FONT
			).y + _PAD_V * 2

			var normal := StyleBoxFlat.new()

			if is_sel:
				normal.bg_color = Color(ExerciseEngine.C_PRIMARY.r, ExerciseEngine.C_PRIMARY.g, ExerciseEngine.C_PRIMARY.b, 0.2)
			else:
				normal.bg_color = Color(0, 0, 0, 0)

			normal.set_corner_radius_all(8)

			if is_sel:
				normal.border_width_left = 3
				normal.border_color = ExerciseEngine.C_PRIMARY

			row.add_theme_stylebox_override("normal", normal)

			var hover: StyleBoxFlat = normal.duplicate()

			if is_sel:
				hover.bg_color = Color(ExerciseEngine.C_PRIMARY.r, ExerciseEngine.C_PRIMARY.g, ExerciseEngine.C_PRIMARY.b, 0.16)
			else:
				hover.bg_color = Color(ExerciseEngine.C_PRIMARY.r, ExerciseEngine.C_PRIMARY.g, ExerciseEngine.C_PRIMARY.b, 0.08)

			row.add_theme_stylebox_override("hover", hover)
			row.add_theme_stylebox_override("pressed", hover)
			row.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

			var lbl := Label.new()
			lbl.text = display
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", _ITEM_FONT)

			var base_color: Color = ExerciseEngine.C_MUTED if is_placeholder else Color("#F1F5F9")
			lbl.add_theme_color_override("font_color", base_color)

			if _font:
				lbl.add_theme_font_override("font", _font)

			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE

			lbl.anchor_right = 1.0
			lbl.anchor_bottom = 1.0

			lbl.offset_left = _PAD_L
			lbl.offset_right = -_PAD_R
			lbl.offset_top = _PAD_V
			lbl.offset_bottom = -_PAD_V

			row.add_child(lbl)

			row.pressed.connect(_on_row_pressed.bind(i))

			row.mouse_entered.connect(func():
				lbl.add_theme_color_override("font_color", ExerciseEngine.C_PRIMARY)
			)

			row.mouse_exited.connect(func():
				lbl.add_theme_color_override("font_color", base_color)
			)

			_list.add_child(row)


	func _on_about_to_popup() -> void:
		var tw := create_tween().set_parallel(true)

		var rows := _list.get_children()

		for i in rows.size():
			var r: Control = rows[i]
			r.modulate.a = 0.0
			tw.tween_property(r, "modulate:a", 1.0, 0.12).set_delay(i * 0.02)


	func _on_row_pressed(index: int) -> void:
		selected = index
		_refresh_face()
		_popup.hide()
		item_selected.emit(index)


	func _refresh_face() -> void:
		text = get_item_text(selected) + "   ▾"


# ============================================================
# HOTSPOT OVERLAY
# ============================================================
class HotspotOverlay extends Control:
	signal hotspot_changed(selected_ids: Array)

	var hotspots: Array = []
	var selected: Array = []
	var multi := true
	var base_size := Vector2(1, 1)


	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP


	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var norm := Vector2(
				event.position.x / maxf(size.x, 1.0),
				event.position.y / maxf(size.y, 1.0)
			)

			var hit := ""

			for i in hotspots.size():
				if _hotspot_contains(hotspots[i], norm):
					hit = _hotspot_id(hotspots[i], i)
					break

			if hit != "":
				if multi:
					if selected.has(hit):
						selected.erase(hit)
					else:
						selected.append(hit)
				else:
					if selected.size() == 1 and selected[0] == hit:
						selected.clear()
					else:
						selected = [hit]

				queue_redraw()
				hotspot_changed.emit(selected.duplicate())
				accept_event()


	func _draw() -> void:
		for i in hotspots.size():
			var hs: Dictionary = hotspots[i]

			var id := _hotspot_id(hs, i)
			var is_sel := selected.has(id)

			var col := Color(str(hs.get("color", "#2563EB")))

			var fill_alpha := 0.45 if is_sel else 0.18
			var fill := Color(col.r, col.g, col.b, fill_alpha)
			var line := Color(col.r, col.g, col.b, 0.9)

			var poly := _scaled_polygon(hs)

			if poly.size() >= 3:
				draw_colored_polygon(poly, fill)
				draw_polyline(poly, line, 3.0, true)

			var label := str(hs.get("label", id))

			if label != "":
				var center := _polygon_center(poly)
				draw_string(
					ThemeDB.fallback_font,
					center,
					label,
					HORIZONTAL_ALIGNMENT_LEFT,
					-1,
					18,
					Color(0.1, 0.1, 0.1, 0.9)
				)


	func _hotspot_id(hs: Dictionary, index: int) -> String:
		return str(hs.get("id", "hotspot_%d" % index))


	func _hotspot_contains(hs: Dictionary, norm_pos: Vector2) -> bool:
		if hs.has("polygon"):
			var poly := _normalized_polygon(hs)
			return Geometry2D.is_point_in_polygon(norm_pos, poly)

		if hs.has("rect"):
			var rect := _normalized_rect(hs["rect"])
			return rect.has_point(norm_pos)

		return false


	func _scaled_polygon(hs: Dictionary) -> PackedVector2Array:
		var poly := _normalized_polygon(hs)

		var out := PackedVector2Array()

		for p in poly:
			out.append(Vector2(p.x * size.x, p.y * size.y))

		if out.size() < 3 and hs.has("rect"):
			var r := _normalized_rect(hs["rect"])

			var p0 := Vector2(r.position.x * size.x, r.position.y * size.y)
			var p1 := Vector2(r.end.x * size.x, r.position.y * size.y)
			var p2 := Vector2(r.end.x * size.x, r.end.y * size.y)
			var p3 := Vector2(r.position.x * size.x, r.end.y * size.y)

			out = PackedVector2Array()
			out.append(p0)
			out.append(p1)
			out.append(p2)
			out.append(p3)

		return out


	func _normalized_polygon(hs: Dictionary) -> PackedVector2Array:
		var out := PackedVector2Array()

		if hs.has("polygon"):
			for p in hs["polygon"]:
				if p is Array and p.size() >= 2:
					var v := Vector2(float(p[0]), float(p[1]))

					if _is_pixel(v):
						v = Vector2(
							v.x / maxf(base_size.x, 1.0),
							v.y / maxf(base_size.y, 1.0)
						)

					out.append(v)

		elif hs.has("rect"):
			var r := _normalized_rect(hs["rect"])

			out.append(r.position)
			out.append(Vector2(r.end.x, r.position.y))
			out.append(r.end)
			out.append(Vector2(r.position.x, r.end.y))

		return out


	func _normalized_rect(rect: Variant) -> Rect2:
		if rect is Array and rect.size() >= 4:
			var r := Rect2(
				float(rect[0]),
				float(rect[1]),
				float(rect[2]),
				float(rect[3])
			)

			if _is_pixel(Vector2(r.position.x, r.position.y)) or _is_pixel(r.size):
				r.position.x /= maxf(base_size.x, 1.0)
				r.position.y /= maxf(base_size.y, 1.0)
				r.size.x /= maxf(base_size.x, 1.0)
				r.size.y /= maxf(base_size.y, 1.0)

			return r

		elif rect is Rect2:
			return rect

		return Rect2()


	func _is_pixel(v: Vector2) -> bool:
		return v.x > 1.0001 or v.y > 1.0001


	func _polygon_center(poly: PackedVector2Array) -> Vector2:
		if poly.is_empty():
			return Vector2(10, 20)

		var sum := Vector2.ZERO

		for p in poly:
			sum += p

		return sum / float(poly.size())
