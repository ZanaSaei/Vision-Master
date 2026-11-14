class_name LearningUnitView
extends RefCounted
# ============================================================
#  LEARNING UNIT VIEW — Modern Grammar Content Page UX
# ============================================================
#  Builds an engaging, modern grammar teaching page with:
#   1. Hero header with topic & bilingual badge
#   2. Key concept card with decorative accent indicator stripe
#   3. Smart Grammar Formula builder (visual syntax chips + connectors)
#   4. Interactive Example Cards with native Text-to-Speech (TTS)
# ============================================================


static func render(target: VBoxContainer, unit: Dictionary) -> void:
	target.add_theme_constant_override("separation", 20)

	# --- 1. HERO HEADER ---
	_build_hero_header(target, unit)

	# --- 2. KEY CONCEPT & EXPLANATION CARD ---
	var explanation_text := str(unit.get("explanation", "")).strip_edges()
	if not explanation_text.is_empty():
		_build_explanation_card(target, explanation_text)

	# --- 3. GRAMMAR FORMULA / STRUCTURE VISUALIZER ---
	var structure_text := str(unit.get("structure", "")).strip_edges()
	var cards: Array = unit.get("cards", [])
	var examples: Array = unit.get("examples", [])
	var has_structure := not structure_text.is_empty() or not cards.is_empty()

	if has_structure:
		_build_structure_section(target, structure_text, cards)

	# --- 4. REAL-WORLD EXAMPLES WITH AUDIO TTS ---
	var all_examples: Array = []
	# If cards were used purely as examples, or if explicit examples array exists
	if not examples.is_empty():
		all_examples.append_array(examples)
	elif not cards.is_empty() and not structure_text.is_empty():
		all_examples.append_array(cards)
	elif not cards.is_empty() and structure_text.is_empty():
		# If no separate structure text was given, cards serve as examples
		all_examples.append_array(cards)

	if not all_examples.is_empty():
		_build_examples_section(target, all_examples)


# ============================================================
# HERO HEADER
# ============================================================
static func _build_hero_header(target: VBoxContainer, unit: Dictionary) -> void:
	var header_vbox := VBoxContainer.new()
	header_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_vbox.add_theme_constant_override("separation", 10)
	header_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	target.add_child(header_vbox)

	# Category pill badge
	var category_row := HBoxContainer.new()
	category_row.alignment = BoxContainer.ALIGNMENT_CENTER
	header_vbox.add_child(category_row)

	var category_badge := GrammarTheme.make_badge(
		"🎓 آموزش و نکات کلیدی گرامر",
		GrammarTheme.accent_soft_color(),
		GrammarTheme.accent_color(),
		24,
		GrammarTheme.accent_color(),
		1
	)
	category_row.add_child(category_badge)

	# Main Persian Title
	var title_fa := str(unit.get("title_fa", "")).strip_edges()
	if not title_fa.is_empty():
		var title_label := Label.new()
		GrammarTheme.set_bidi_text(title_label, title_fa)
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_label.add_theme_font_size_override("font_size", GrammarTheme.HEADING_SIZE)
		title_label.add_theme_color_override("font_color", GrammarTheme.text_color())
		title_label.add_theme_font_override("font", GrammarTheme.get_fa_bold())
		header_vbox.add_child(title_label)

	# English Title / Subtitle
	var title_en := str(unit.get("title_en", "")).strip_edges()
	if not title_en.is_empty():
		var en_row := HBoxContainer.new()
		en_row.alignment = BoxContainer.ALIGNMENT_CENTER
		header_vbox.add_child(en_row)

		var en_badge := GrammarTheme.make_badge(
			title_en,
			Global.get_theme_color("surface_alt"),
			GrammarTheme.text_secondary_color(),
			26,
			Global.get_theme_color("border"),
			1
		)
		en_row.add_child(en_badge)

	GrammarAnimation.appear(header_vbox, 0.04)


# ============================================================
# EXPLANATION CARD
# ============================================================
static func _build_explanation_card(target: VBoxContainer, text: String) -> void:
	var card := PanelContainer.new()
	var card_style := GrammarTheme.info_card_style()
	# Accent stripe on the right side for RTL Persian reading emphasis
	card_style.border_width_right = 5
	card_style.border_color = GrammarTheme.accent_color()
	card.add_theme_stylebox_override("panel", card_style)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	card.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)

	# Card header row: Icon + Tag
	var tag_row := HBoxContainer.new()
	tag_row.alignment = BoxContainer.ALIGNMENT_END
	tag_row.add_theme_constant_override("separation", 8)
	layout.add_child(tag_row)

	var tag_label := Label.new()
	tag_label.text = "💡 نکته آموزشی و مفهوم"
	tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tag_label.add_theme_font_override("font", GrammarTheme.get_fa_bold())
	tag_label.add_theme_font_size_override("font_size", 26)
	tag_label.add_theme_color_override("font_color", GrammarTheme.accent_color())
	tag_row.add_child(tag_label)

	# Explanation Body
	var body_label := Label.new()
	GrammarTheme.set_bidi_text(body_label, text)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_label.add_theme_font_size_override("font_size", GrammarTheme.BODY_SIZE)
	body_label.add_theme_color_override("font_color", GrammarTheme.text_color())
	body_label.add_theme_font_override("font", GrammarTheme.get_fa_regular())
	layout.add_child(body_label)

	GrammarAnimation.appear(card, 0.08)


# ============================================================
# STRUCTURE & FORMULA VISUALIZER
# ============================================================
static func _build_structure_section(target: VBoxContainer, structure_str: String, _cards: Array) -> void:
	if structure_str.is_empty():
		return

	# Section Header
	var header_row := HBoxContainer.new()
	header_row.alignment = BoxContainer.ALIGNMENT_END
	header_row.add_theme_constant_override("separation", 8)
	target.add_child(header_row)

	var sec_label := Label.new()
	sec_label.text = "⚡ فرمول و ساختار جمله"
	sec_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sec_label.add_theme_font_override("font", GrammarTheme.get_fa_bold())
	sec_label.add_theme_font_size_override("font_size", GrammarTheme.SECTION_SIZE)
	sec_label.add_theme_color_override("font_color", GrammarTheme.text_color())
	header_row.add_child(sec_label)

	# Main Formula Container Card
	var formula_card := PanelContainer.new()
	formula_card.add_theme_stylebox_override("panel", GrammarTheme.formula_card_style())
	formula_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target.add_child(formula_card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	formula_card.add_child(margin)

	# Check if formula contains '+' syntax (e.g. subject + will + base verb)
	if structure_str.contains("+"):
		var flow := HFlowContainer.new()
		flow.alignment = FlowContainer.ALIGNMENT_CENTER
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		flow.add_theme_constant_override("h_separation", 12)
		flow.add_theme_constant_override("v_separation", 10)
		margin.add_child(flow)

		var raw_tokens := structure_str.split("+")
		for i in range(raw_tokens.size()):
			var token := raw_tokens[i].strip_edges()
			if token.is_empty():
				continue

			# Determine chip accent
			var is_operator := token.to_lower() in ["will", "be going to", "going to", "not", "am / is / are", "am/is/are", "have", "has", "do", "does", "did"]
			var bg_col := GrammarTheme.accent_color() if is_operator else GrammarTheme.accent_soft_color()
			var text_col := Color.WHITE if is_operator else GrammarTheme.accent_color()
			var border_col := GrammarTheme.accent_bright_color() if is_operator else GrammarTheme.accent_color()

			var chip := GrammarTheme.make_badge(
				token,
				bg_col,
				text_col,
				32,
				border_col,
				2
			)
			flow.add_child(chip)

			# Add '+' connector if not the last token
			if i < raw_tokens.size() - 1:
				var plus_label := Label.new()
				plus_label.text = "+"
				plus_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				plus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				plus_label.add_theme_font_override("font", GrammarTheme.get_fa_bold())
				plus_label.add_theme_font_size_override("font_size", 34)
				plus_label.add_theme_color_override("font_color", GrammarTheme.accent_bright_color())
				flow.add_child(plus_label)

	elif structure_str.contains(","):
		# List of forms (e.g. I'll, You'll, He'll...)
		var flow := HFlowContainer.new()
		flow.alignment = FlowContainer.ALIGNMENT_CENTER
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		flow.add_theme_constant_override("h_separation", 10)
		flow.add_theme_constant_override("v_separation", 10)
		margin.add_child(flow)

		var forms := structure_str.split(",")
		for form in forms:
			var trimmed := form.strip_edges()
			if trimmed.is_empty():
				continue
			var chip := GrammarTheme.make_badge(
				trimmed,
				GrammarTheme.accent_soft_color(),
				GrammarTheme.accent_color(),
				30,
				GrammarTheme.accent_color(),
				1
			)
			flow.add_child(chip)
	else:
		# Single formula string
		var label := Label.new()
		GrammarTheme.set_bidi_text(label, structure_str)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", GrammarTheme.BODY_LARGE_SIZE)
		label.add_theme_color_override("font_color", GrammarTheme.primary_dark_color())
		label.add_theme_font_override("font", GrammarTheme.get_en_bold())
		margin.add_child(label)

	GrammarAnimation.appear(formula_card, 0.12)


# ============================================================
# REAL-WORLD EXAMPLES (WITH NATIVE TTS AUDIO)
# ============================================================
static func _build_examples_section(target: VBoxContainer, examples: Array) -> void:
	# Section Header
	var header_row := HBoxContainer.new()
	header_row.alignment = BoxContainer.ALIGNMENT_END
	header_row.add_theme_constant_override("separation", 8)
	target.add_child(header_row)

	var sec_label := Label.new()
	sec_label.text = "📝 مثال‌های کاربردی"
	sec_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sec_label.add_theme_font_override("font", GrammarTheme.get_fa_bold())
	sec_label.add_theme_font_size_override("font_size", GrammarTheme.SECTION_SIZE)
	sec_label.add_theme_color_override("font_color", GrammarTheme.text_color())
	header_row.add_child(sec_label)

	# Cards Container
	for i in range(examples.size()):
		var data: Dictionary = examples[i]
		var en_text := str(data.get("en", "")).strip_edges()
		var fa_text := str(data.get("fa", "")).strip_edges()
		if en_text.is_empty() and fa_text.is_empty():
			continue

		var card := PanelContainer.new()
		var card_style := GrammarTheme.info_card_style()
		card_style.border_width_bottom = 2
		card_style.border_color = GrammarTheme.accent_color()
		card.add_theme_stylebox_override("panel", card_style)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		target.add_child(card)

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 20)
		margin.add_theme_constant_override("margin_right", 20)
		margin.add_theme_constant_override("margin_top", 16)
		margin.add_theme_constant_override("margin_bottom", 16)
		card.add_child(margin)

		var card_row := HBoxContainer.new()
		card_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_row.add_theme_constant_override("separation", 14)
		margin.add_child(card_row)

		# Text Stack (English + Persian)
		var text_stack := VBoxContainer.new()
		text_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_stack.add_theme_constant_override("separation", 6)
		card_row.add_child(text_stack)

		# English sentence
		if not en_text.is_empty():
			var en_label := Label.new()
			en_label.text = en_text
			en_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			en_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			en_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			en_label.add_theme_font_size_override("font_size", GrammarTheme.BODY_LARGE_SIZE)
			en_label.add_theme_color_override("font_color", GrammarTheme.text_color())
			en_label.add_theme_font_override("font", GrammarTheme.get_en_bold())
			text_stack.add_child(en_label)

		# Persian translation
		if not fa_text.is_empty():
			var fa_label := Label.new()
			GrammarTheme.set_bidi_text(fa_label, fa_text)
			fa_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			fa_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			fa_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			fa_label.add_theme_font_size_override("font_size", GrammarTheme.BODY_SMALL_SIZE)
			fa_label.add_theme_color_override("font_color", GrammarTheme.text_secondary_color())
			fa_label.add_theme_font_override("font", GrammarTheme.get_fa_regular())
			text_stack.add_child(fa_label)

		# Speaker Pronunciation Button (🔊)
		if not en_text.is_empty():
			var speaker_btn := GrammarTheme.make_speaker_button(en_text, 76.0)
			speaker_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			card_row.add_child(speaker_btn)

		GrammarAnimation.appear(card, 0.16 + (i * 0.06))
