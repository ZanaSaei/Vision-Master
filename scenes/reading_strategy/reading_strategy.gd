extends "res://autoload/BackButtonHandler.gd"
# ============================================================
# READING STRATEGY SCENE
# Loads from res://data/categories/reading_strategies.json
# Renders: strategy banner, step timeline, reference chips,
#          Persian tips, and interactive practice (ExerciseEngine).
# ============================================================

const SCENE_LESSON_MENU := "res://scenes/lesson_menu/LessonMenu.tscn"

# ---------- Fonts ----------
const FONT_REGULAR_PATH := "res://assets/fonts/PlusJakartaSans-Regular.ttf"
const FONT_BOLD_PATH    := "res://assets/fonts/PlusJakartaSans-Bold.ttf"
const FONT_VAZIRMATN    := "res://assets/fonts/Vazirmatn-Regular.ttf"

var font_regular: FontFile
var font_bold: FontFile
var font_farsi: FontFile

# ---------- Per-strategy visual theme ----------
const STRATEGY_THEMES := {
	"Scanning":                     {"accent": Color("#0891B2"), "soft": Color("#ECFEFF"), "icon": "🔍"},
	"Skimming":                     {"accent": Color("#2563EB"), "soft": Color("#EFF6FF"), "icon": "📖"},
	"Recognizing Reference Words":  {"accent": Color("#7C3AED"), "soft": Color("#F5F3FF"), "icon": "🔗"},
	"Question Generation":          {"accent": Color("#EA580C"), "soft": Color("#FFF7ED"), "icon": "❓"},
	"Highlighting":                 {"accent": Color("#CA8A04"), "soft": Color("#FEFCE8"), "icon": "🖍️"},
	"Note Taking":                  {"accent": Color("#059669"), "soft": Color("#ECFDF5"), "icon": "📝"},
}
const DEFAULT_THEME := {"accent": Color("#2563EB"), "soft": Color("#EFF6FF"), "icon": "🎯"}

# ---------- Node references ----------
@onready var back_button: Button      = $HeaderBar/HeaderContent/BackButton
@onready var header_title: Label      = $HeaderBar/HeaderContent/HeaderTitle
@onready var background: ColorRect    = $BackgroundColor
@onready var content_layout: VBoxContainer = $MarginContainer/MainLayout/ScrollContainer/ContentLayout

var _reveal_cards: Array = []   # collected for staggered entrance


func _ready() -> void:
	font_regular = load(FONT_REGULAR_PATH)
	font_bold = load(FONT_BOLD_PATH)
	font_farsi = load(FONT_VAZIRMATN)
	
	back_button.pressed.connect(_on_back_button_pressed)
	if font_bold: header_title.add_theme_font_override("font", font_bold)
	# Restyle live when the app theme toggles.
	Global.on_theme_changed(_apply_theme)
	
	var book: int = Global.current_book
	var lesson: int = Global.current_lesson
	header_title.text = MenuStyle.persian_digits("درس %d\nراهبرد خواندن" % lesson)
	
	var data: Dictionary = Global.load_category("reading_strategies", book, lesson)
	if data.is_empty() or not data.has("strategy"):
		_build_unavailable()
		return
	
	var strategy: Dictionary = data["strategy"]
	var palette: Dictionary = STRATEGY_THEMES.get(strategy["name"]["en"], DEFAULT_THEME)
	
	_build_banner(strategy, palette)
	_build_steps(strategy, palette)
	_build_reference_materials(strategy, palette)
	_build_persian_insights(strategy, palette)
	_build_practice(data.get("exercises", []), palette)
	_build_bottom_spacer()
	_play_entrance()
	_apply_theme()


# ============================================================
# THEME
# ============================================================
func _apply_theme() -> void:
	if not is_inside_tree():
		return
	background.color = Global.get_theme_color("bg_base")
	background.material = null


# ============================================================
# BANNER — the strategy's identity, big and bold
# ============================================================
func _build_banner(strategy: Dictionary, palette: Dictionary) -> void:
	var accent: Color = palette["accent"]
	
	var banner := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = accent
	style.set_corner_radius_all(20)
	style.set_content_margin_all(28)
	banner.add_theme_stylebox_override("panel", style)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	
	var icon := Label.new()
	icon.name = "BannerIcon"
	icon.text = str(palette["icon"])
	icon.add_theme_font_size_override("font_size", 84)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(icon)
	
	var name_en := Label.new()
	name_en.text = strategy["name"]["en"]
	name_en.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_en.add_theme_font_size_override("font_size", 56)
	name_en.add_theme_color_override("font_color", Color.WHITE)
	name_en.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font_bold: name_en.add_theme_font_override("font", font_bold)
	vbox.add_child(name_en)
	
	var name_fa := Label.new()
	name_fa.text = strategy["name"]["fa"]
	name_fa.add_theme_font_size_override("font_size", 40)
	name_fa.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	name_fa.text_direction = Control.TEXT_DIRECTION_RTL
	name_fa.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font_farsi: name_fa.add_theme_font_override("font", font_farsi)
	vbox.add_child(name_fa)
	
	var desc := Label.new()
	desc.text = strategy["description"]["en"]
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.add_theme_font_size_override("font_size", 36)
	desc.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	if font_regular: desc.add_theme_font_override("font", font_regular)
	vbox.add_child(desc)
	
	var desc_fa := Label.new()
	desc_fa.text = strategy["description"]["fa"]
	desc_fa.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_fa.add_theme_font_size_override("font_size", 34)
	desc_fa.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	desc_fa.text_direction = Control.TEXT_DIRECTION_RTL
	desc_fa.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if font_farsi: desc_fa.add_theme_font_override("font", font_farsi)
	vbox.add_child(desc_fa)
	
	banner.add_child(vbox)
	content_layout.add_child(banner)
	_reveal_cards.append(banner)


# ============================================================
# STEPS — numbered vertical timeline
# ============================================================
func _build_steps(strategy: Dictionary, palette: Dictionary) -> void:
	var steps: Array = strategy.get("steps", [])
	if steps.is_empty(): return
	
	var accent: Color = palette["accent"]
	var soft: Color = palette["soft"]
	
	content_layout.add_child(_make_section_title("How to do it", "چگونه انجام دهیم", accent))
	
	var timeline := VBoxContainer.new()
	timeline.add_theme_constant_override("separation", 0)
	
	for i in steps.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		
		# Number circle + connector line
		var rail := VBoxContainer.new()
		rail.add_theme_constant_override("separation", 0)
		rail.custom_minimum_size = Vector2(56, 0)
		
		var circle := Label.new()
		circle.text = str(i + 1)
		circle.add_theme_font_size_override("font_size", 32)
		circle.add_theme_color_override("font_color", Color.WHITE)
		circle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		circle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var c_style := StyleBoxFlat.new()
		c_style.bg_color = accent
		c_style.set_corner_radius_all(28)
		c_style.set_content_margin_all(12)
		circle.add_theme_stylebox_override("normal", c_style)
		if font_bold: circle.add_theme_font_override("font", font_bold)
		rail.add_child(circle)
		
		if i < steps.size() - 1:
			var connector := ColorRect.new()
			connector.color = accent.lightened(0.6)
			connector.custom_minimum_size = Vector2(3, 0)
			connector.size_flags_vertical = Control.SIZE_EXPAND_FILL
			connector.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			rail.add_child(connector)
		
		# Step text card
		var card := _make_soft_card(soft, accent)
		var step_vbox := VBoxContainer.new()
		step_vbox.add_theme_constant_override("separation", 6)
		
		var en := Label.new()
		en.text = steps[i]["en"]
		en.autowrap_mode = TextServer.AUTOWRAP_WORD
		en.add_theme_font_size_override("font_size", 38)
		en.add_theme_color_override("font_color", DesignTokens.INK)
		if font_regular: en.add_theme_font_override("font", font_regular)
		step_vbox.add_child(en)
		
		var fa := Label.new()
		fa.text = steps[i]["fa"]
		fa.autowrap_mode = TextServer.AUTOWRAP_WORD
		fa.add_theme_font_size_override("font_size", 34)
		fa.add_theme_color_override("font_color", Color("#64748B"))
		fa.text_direction = Control.TEXT_DIRECTION_RTL
		fa.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if font_farsi: fa.add_theme_font_override("font", font_farsi)
		step_vbox.add_child(fa)
		
		card.add_child(step_vbox)
		_add_hover_lift(card)
		
		row.add_child(rail)
		row.add_child(card)
		timeline.add_child(row)
		_reveal_cards.append(row)
	
	content_layout.add_child(timeline)


# ============================================================
# REFERENCE MATERIALS — question starters / ref words / symbols
# ============================================================
func _build_reference_materials(strategy: Dictionary, palette: Dictionary) -> void:
	var accent: Color = palette["accent"]
	var soft: Color = palette["soft"]
	
	# Question starters (Question Generation)
	if strategy.has("question_starters"):
		content_layout.add_child(_make_section_title("Question Starters", "کلمات پرسشی", accent))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("separation", 12)
		for qs in strategy["question_starters"]:
			flow.add_child(_make_chip(
				qs["starter"] + "  →  " + qs["answer_type"]["en"],
				qs["fa"] + "  →  " + qs["answer_type"]["fa"],
				accent, soft))
		content_layout.add_child(flow)
		_reveal_cards.append(flow)
	
	# Common reference words (Recognizing Reference Words)
	if strategy.has("common_reference_words"):
		content_layout.add_child(_make_section_title("Common Reference Words", "کلمات ارجاعی رایج", accent))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("separation", 12)
		for rw in strategy["common_reference_words"]:
			flow.add_child(_make_chip(rw["en"], rw["fa"], accent, soft))
		content_layout.add_child(flow)
		_reveal_cards.append(flow)
	
	# Useful symbols (Note Taking)
	if strategy.has("useful_symbols"):
		content_layout.add_child(_make_section_title("Useful Symbols & Abbreviations", "نمادها و اختصارات", accent))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("separation", 12)
		for sym in strategy["useful_symbols"]:
			flow.add_child(_make_chip(sym["symbol"] + "  =  " + sym["meaning"]["en"], sym["meaning"]["fa"], accent, soft))
		content_layout.add_child(flow)
		_reveal_cards.append(flow)
	
	# Key questions (Skimming)
	if strategy.has("key_questions"):
		content_layout.add_child(_make_section_title("Ask Yourself", "از خود بپرسید", accent))
		for kq in strategy["key_questions"]:
			var card := _make_soft_card(soft, accent)
			var vb := VBoxContainer.new()
			vb.add_theme_constant_override("separation", 6)
			var en := _make_label(kq["en"], 36, DesignTokens.INK, false)
			var fa := _make_label(kq["fa"], 33, Color("#64748B"), false)
			fa.text_direction = Control.TEXT_DIRECTION_RTL
			fa.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			if font_farsi: fa.add_theme_font_override("font", font_farsi)
			
			# Ensure Farsi text toggles with translation
			
			vb.add_child(en)
			vb.add_child(fa)
			card.add_child(vb)
			content_layout.add_child(card)
			_reveal_cards.append(card)


# ============================================================
# PERSIAN INSIGHTS — extra_fa + tips_fa
# ============================================================
func _build_persian_insights(strategy: Dictionary, palette: Dictionary) -> void:
	var accent: Color = palette["accent"]
	
	var extra: Array = strategy.get("extra_fa", [])
	if not extra.is_empty():
		content_layout.add_child(_make_section_title("More to Know", "بیشتر بدانید", accent))
		for tip in extra:
			var card := _make_insight_card(str(tip), accent)
			content_layout.add_child(card)
			_reveal_cards.append(card)
	
	var tips: Array = strategy.get("tips_fa", [])
	if not tips.is_empty():
		content_layout.add_child(_make_section_title("Practical Tips", "نکات کاربردی", accent))
		for t in tips:
			var card := _make_insight_card("✅ " + str(t), accent)
			content_layout.add_child(card)
			_reveal_cards.append(card)

func _make_insight_card(text: String, accent: Color) -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.set_corner_radius_all(14)
	style.border_width_right = 5
	style.border_color = accent
	style.set_content_margin_all(20)
	card.add_theme_stylebox_override("panel", style)
	
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_font_size_override("font_size", 36)
	label.add_theme_color_override("font_color", DesignTokens.INK)
	label.text_direction = Control.TEXT_DIRECTION_RTL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if font_farsi: label.add_theme_font_override("font", font_farsi)
	card.add_child(label)
	
	# Hide Farsi insight cards initially and hook into translation toggle
	
	_add_hover_lift(card)
	return card

# ============================================================
# PRACTICE — reuse your ExerciseEngine
# ============================================================
func _build_practice(exercises: Array, palette: Dictionary) -> void:
	if exercises.is_empty(): return
	content_layout.add_child(_make_section_title("Practice", "تمرین", palette["accent"]))
	for exercise in exercises:
		var engine := ExerciseEngine.new()
		content_layout.add_child(engine)
		engine.build(exercise)
		_reveal_cards.append(engine)


# ============================================================
# SHARED WIDGET HELPERS
# ============================================================
func _make_section_title(en: String, fa: String, accent: Color, rtl_primary := false) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	
	var bar := ColorRect.new()
	bar.color = accent
	bar.custom_minimum_size = Vector2(6, 44)
	row.add_child(bar)
	
	var title := Label.new()
	title.text = fa if rtl_primary else en
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", DesignTokens.INK)
	
	if rtl_primary:
		title.text_direction = Control.TEXT_DIRECTION_RTL
		if font_farsi:
			title.add_theme_font_override("font", font_farsi)
	else:
		if font_bold:
			title.add_theme_font_override("font", font_bold)
	
	row.add_child(title)
	
	var sub := Label.new()
	sub.text = en if rtl_primary else fa
	sub.add_theme_font_size_override("font_size", 32)
	sub.add_theme_color_override("font_color", Color("#94A3B8"))
	
	if rtl_primary:
		if font_bold:
			sub.add_theme_font_override("font", font_bold)
	else:
		if font_farsi:
			sub.add_theme_font_override("font", font_farsi)
	
	
	return row


func _make_soft_card(soft: Color, accent: Color) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = soft
	style.set_corner_radius_all(14)
	style.border_width_left = 4
	style.border_color = accent
	style.set_content_margin_all(18)
	card.add_theme_stylebox_override("panel", style)
	return card


func _make_chip(main: String, sub: String, accent: Color, soft: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.set_corner_radius_all(22)
	style.border_width_left = 1; style.border_width_right = 1
	style.border_width_top = 1; style.border_width_bottom = 1
	style.border_color = accent.lightened(0.3)
	style.set_content_margin_all(14)
	chip.add_theme_stylebox_override("panel", style)
	
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	var m := Label.new()
	m.text = main
	m.add_theme_font_size_override("font_size", 32)
	m.add_theme_color_override("font_color", accent)
	if font_bold: m.add_theme_font_override("font", font_bold)
	var s := Label.new()
	s.text = sub
	s.add_theme_font_size_override("font_size", 28)
	s.add_theme_color_override("font_color", Color("#64748B"))
	s.text_direction = Control.TEXT_DIRECTION_RTL
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if font_farsi: s.add_theme_font_override("font", font_farsi)
	vb.add_child(m)
	vb.add_child(s)
	chip.add_child(vb)
	_add_hover_lift(chip)
	return chip


func _make_label(text: String, font_size: int, color: Color, bold: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if bold and font_bold: l.add_theme_font_override("font", font_bold)
	elif not bold and font_regular: l.add_theme_font_override("font", font_regular)
	return l


func _add_hover_lift(control: Control) -> void:
	control.mouse_entered.connect(func():
		control.pivot_offset = control.size / 2.0
		var t := create_tween()
		t.tween_property(control, "scale", Vector2(1.015, 1.015), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)
	control.mouse_exited.connect(func():
		control.pivot_offset = control.size / 2.0
		var t := create_tween()
		t.tween_property(control, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)


# ============================================================
# ENTRANCE ANIMATION — staggered reveal
# ============================================================
func _play_entrance() -> void:
	# Pop the banner icon
	var icon := content_layout.find_child("BannerIcon", true, false)
	if icon:
		icon.pivot_offset = icon.size / 2.0
		icon.scale = Vector2(0.5, 0.5)
		var pop := create_tween()
		pop.tween_property(icon, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Stagger the cards
	for i in _reveal_cards.size():
		var card: Control = _reveal_cards[i]
		card.modulate.a = 0.0
		var t := create_tween()
		t.tween_property(card, "modulate:a", 1.0, 0.35).set_delay(0.08 * i).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _build_unavailable() -> void:
	var label := _make_label("📚 This lesson has no Reading Strategy section.\nReading Strategies appear in Vision 2 and Vision 3.", 38, Color("#64748B"), false)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_layout.add_child(label)


func _build_bottom_spacer() -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 120)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_layout.add_child(spacer)


func _on_back_button_pressed() -> void:
	back_button.pivot_offset = back_button.size / 2.0
	var t := create_tween()
	t.tween_property(back_button, "scale", Vector2(0.96, 0.96), 0.08)
	TransitionManager.change_scene(SCENE_LESSON_MENU)
