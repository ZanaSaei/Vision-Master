class_name LearningUnitView
extends RefCounted
# ============================================================
#  LEARNING UNIT VIEW
#  Builds a "learn" (teaching) screen — title, explanation card
#  and structure/example cards — into a target VBoxContainer.
#  Keeps the teaching UI out of the main GrammarLesson controller
#  so the controller stays small and focused on the flow.
# ============================================================


static func render(target: VBoxContainer, unit: Dictionary) -> void:

	# --- Title (Persian) ---
	var title := Label.new()
	title.text = str(unit.get("title_fa", ""))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", GrammarTheme.HEADING_SIZE)
	title.add_theme_color_override("font_color", GrammarTheme.text_color())
	title.add_theme_font_override("font", GrammarTheme.get_fa_bold())
	target.add_child(title)
	GrammarAnimation.appear(title)

	# --- English subtitle ---
	var english_title := Label.new()
	english_title.text = str(unit.get("title_en", ""))
	english_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	english_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	english_title.add_theme_font_size_override("font_size", GrammarTheme.BODY_SIZE)
	english_title.add_theme_color_override("font_color", GrammarTheme.text_secondary_color())
	english_title.add_theme_font_override("font", GrammarTheme.get_en_bold())
	target.add_child(english_title)

	# --- Explanation card ---
	var explanation_card := _make_card(target, 0)
	var explanation := Label.new()
	explanation.text = str(unit.get("explanation", ""))
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	explanation.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	explanation.size_flags_vertical = Control.SIZE_EXPAND_FILL
	explanation.add_theme_font_size_override("font_size", GrammarTheme.BODY_SIZE)
	explanation.add_theme_color_override("font_color", GrammarTheme.text_color())
	explanation.add_theme_font_override("font", GrammarTheme.get_fa_regular())
	_add_to_card(explanation_card, explanation)

	# --- Structure / example cards ---
	var cards: Array = unit.get("cards", [])
	var structure_fallback := str(unit.get("structure", ""))
	var has_structure := cards.size() > 0 or structure_fallback != ""

	if has_structure:
		var section_title := Label.new()
		section_title.text = "ساختار"
		section_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		section_title.add_theme_font_size_override("font_size", GrammarTheme.SECTION_SIZE)
		section_title.add_theme_color_override("font_color", GrammarTheme.text_secondary_color())
		section_title.add_theme_font_override("font", GrammarTheme.get_fa_bold())
		target.add_child(section_title)

	if structure_fallback != "":
		var structure_label := Label.new()
		structure_label.text = structure_fallback
		structure_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		structure_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		structure_label.add_theme_font_size_override("font_size", GrammarTheme.BODY_LARGE_SIZE)
		structure_label.add_theme_color_override("font_color", GrammarTheme.primary_dark_color())
		structure_label.add_theme_font_override("font", GrammarTheme.get_en_bold())
		target.add_child(structure_label)

	for card in cards:
		_add_structure_card(target, card)

	# Legacy examples (kept for older data)
	var examples: Array = unit.get("examples", [])
	for example in examples:
		_add_structure_card(target, example)


static func _add_structure_card(target: VBoxContainer, data: Dictionary) -> void:
	var card := _make_card(target, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_add_to_card(card, box)

	var en := Label.new()
	en.text = str(data.get("en", ""))
	en.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	en.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	en.add_theme_font_size_override("font_size", GrammarTheme.BODY_LARGE_SIZE)
	en.add_theme_color_override("font_color", GrammarTheme.primary_dark_color())
	en.add_theme_font_override("font", GrammarTheme.get_en_bold())
	box.add_child(en)

	var fa := Label.new()
	fa.text = str(data.get("fa", ""))
	fa.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fa.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fa.add_theme_font_size_override("font_size", GrammarTheme.BODY_SMALL_SIZE)
	fa.add_theme_color_override("font_color", GrammarTheme.text_secondary_color())
	fa.add_theme_font_override("font", GrammarTheme.get_fa_regular())
	box.add_child(fa)


static func _make_card(target: VBoxContainer, min_height: int) -> PanelContainer:
	var card := PanelContainer.new()
	if min_height > 0:
		card.custom_minimum_size = Vector2(0, min_height)
	# Use the raised info-card style (surface_alt) so the teaching boxes
	# clearly contrast with the parent surface container in both themes.
	card.add_theme_stylebox_override("panel", GrammarTheme.info_card_style())
	target.add_child(card)
	GrammarAnimation.appear(card, 0.05)
	return card


static func _add_to_card(card: PanelContainer, content: Control) -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.add_child(content)
	card.add_child(margin)
