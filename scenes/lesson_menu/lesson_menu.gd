extends "res://autoload/BackButtonHandler.gd"

############################################################
# LESSON MENU — modern, friendly section picker.
# Shows the section cards for Global.current_book + current_lesson.
# The section cards are GLOSSY buttons: a raised, lightly tinted face wearing
# a rounded sheen (GlossSheen) that brightens on hover and flattens on press.
# Navigation: GRAMMAR slides forward; other sections fade.
# A fixed header bar — the main menu's, at the same size — carries the
# screen's top label and sits over the scrolling cards.
############################################################

const SCENE_BOOK_MENU          := "res://scenes/book_menu/BookSelection.tscn"
const SCENE_VOCAB              := "res://scenes/vocabulary/VocabFlashcards.tscn"
const SCENE_CONVERSATION       := "res://scenes/conversation/Conversation.tscn"
const SCENE_READING            := "res://scenes/reading/Reading.tscn"
const SCENE_GRAMMAR            := "res://scenes/grammar/GrammarHub.tscn"
const SCENE_VOCAB_DEVELOPMENT  := "res://scenes/vocabulary_development/VocabularyDevelopment.tscn"
const SCENE_LISTENING_SPEAKING := "res://scenes/listening_speaking/ListeningSpeaking.tscn"
const SCENE_PRONUNCIATION      := "res://scenes/pronunciation/Pronunciation.tscn"
const SCENE_WRITING            := "res://scenes/writing/Writing.tscn"
const SCENE_WHAT_YOU_LEARNED   := "res://scenes/what_you_learned/WhatYouLearned.tscn"
const SCENE_WORKBOOK           := "res://scenes/workbook/Workbook.tscn"

const PERSIAN_DIGITS := ["۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹", "۱۰"]

# Section definitions: [English label, Persian label, emoji, scene key]
const SECTIONS_VISION_1 := [
	["Get Ready and New Words", "لغات جدید",        "📚", "VOCAB"],
	["Conversation",            "مکالمه",            "💬", "CONVERSATION"],
	["Reading",                 "خواندن",            "📖", "READING"],
	["Grammar",                 "گرامر",             "✏️", "GRAMMAR"],
	["Listening and Speaking",  "شنیداری و گفتاری",  "🎧", "LISTENING_SPEAKING"],
	["Pronunciation",           "تلفظ",              "🎙️", "PRONUNCIATION"],
	["Writing",                 "نوشتن",             "📝", "WRITING"],
	["What You Learned",        "آنچه آموختید",      "🔄", "WHAT_YOU_LEARNED"],
	["Workbook",                "کتاب کار",          "📘", "WORKBOOK"],
]

const SECTIONS_VISION_2_3 := [
	["Get Ready and New Words", "لغات جدید",        "📚", "VOCAB"],
	["Conversation",            "مکالمه",            "💬", "CONVERSATION"],
	["Reading",                 "خواندن",            "📖", "READING"],
	["Vocabulary Development",  "توسعه واژگان",      "🧠", "VOCAB_DEVELOPMENT"],
	["Grammar",                 "گرامر",             "✏️", "GRAMMAR"],
	["Listening and Speaking",  "شنیداری و گفتاری",  "🎧", "LISTENING_SPEAKING"],
	["Pronunciation",           "تلفظ",              "🎙️", "PRONUNCIATION"],
	["Writing",                 "نوشتن",             "📝", "WRITING"],
	["What You Learned",        "آنچه آموختید",      "🔄", "WHAT_YOU_LEARNED"],
	["Workbook",                "کتاب کار",          "📘", "WORKBOOK"],
]

const SECTION_ACCENT_COLORS: Array[Color] = [
	Color("#3B82F6"), Color("#22C55E"), Color("#EF4444"),
	Color("#9333EA"), Color("#0D9488"), Color("#E11D48"),
	Color("#7C3AED"), Color("#D97706"), Color("#64748B"),
	Color("#0891B2"),
]

const BOOK_COLORS := {
	1: Color("#3B82F6"),   # Vision 1 — solid light blue
	2: Color("#22C55E"),   # Vision 2 — solid green
	3: Color("#EF4444"),   # Vision 3 — solid red
}


const LESSON_TITLES := {
	1: ["نجات طبیعت", "شگفتی‌های آفرینش", "ارزش دانش", "سفر به دور دنیا"],
	2: ["درک مردم", "سبک زندگی سالم", "هنر و فرهنگ"],
	3: ["حس قدردانی", "جستجو کن!", "انرژی تجدیدپذیر"],
}

# The book menu hands this screen its blurred cover, which is sharpened on
# arrival. The content fades in during the same window so the screen reads as
# one arrival instead of an empty sharp background that content then lands on.
const BG_UNBLUR_TIME := 0.55
const CONTENT_FADE_TIME := 0.40

# Fixed header bar on top of the screen, carrying the screen's top label.
# Same geometry as the main menu's header bar — full width, 200 px tall,
# 35 px bottom shoulders, 60 px side padding — so the two menu screens line
# up, and the cards start one gap below it.
const HEADER_HEIGHT := 200.0
const HEADER_RADIUS := 35
const HEADER_PAD_X := 60
const HEADER_LABEL_HEIGHT := 70
const HEADER_LABEL_SIZE := 40
const HEADER_GAP := 48
const HEADER_TEXT := "یک بخش را انتخاب کنید 👇"

# Section cards are GLOSSY buttons: one rounded corner radius drives both the
# card's styleboxes and the sheen overlay's mask, so the shine stops exactly at
# the rounded face instead of spilling into the corners.
const CARD_RADIUS := 26

var _navigating: bool = false
var _book: int = 1
var _lesson: int = 1

# Built UI state.
var _scroll: ScrollContainer = null
var _col: VBoxContainer = null
var _header: PanelContainer = null
var _title_label: Label = null
var _subtitle_badge: Label = null
var _card_buttons: Array[Button] = []
var _card_accents: Array[Color] = []
var _bg_blur: TextureRect = null
var _bg_clear: TextureRect = null


func _ready() -> void:
	_book = Global.current_book
	_lesson = Global.current_lesson

	# Kick off the on-demand download of this lesson's media (audio + images)
	# so every section opened from here has its files locally.
	Content.ensure_lesson(_book, _lesson)

	_build_ui()

	# The screen opens on the blurred cover the book menu left on screen, so
	# from the user's point of view nothing happened to the background at the
	# swap: it simply sharpens while the content arrives.
	_animate_background_in()

	# Save current scene for back navigation from drill-down scenes.
	# `current_scene` is only set when this screen is reached through a scene
	# change, so fall back to this node's own path: the screen must also be
	# instantiable in isolation (tooling, tests) without crashing on null.
	var current := get_tree().current_scene
	Global.set_last_scene(current.scene_file_path if current != null else scene_file_path)

	Global.on_theme_changed(_on_theme_changed)
	_apply_theme()

	# Gentle entrance: the header bar and the cards arrive together.
	_scroll.modulate.a = 0.0
	_header.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_scroll, "modulate:a", 1.0, CONTENT_FADE_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_header, "modulate:a", 1.0, CONTENT_FADE_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Fades the sharp artwork in over the blurred still the screen opened on.
## Runs on every entry (book menu, back from a section, tab bar), so the
## background always resolves from soft to sharp instead of popping in.
func _animate_background_in() -> void:
	if _bg_clear == null:
		return
	_bg_clear.modulate.a = 0.0
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_bg_clear, "modulate:a", 1.0, BG_UNBLUR_TIME)
	tw.tween_callback(_on_background_sharpened)


func _on_background_sharpened() -> void:
	# The blurred underlayer is fully covered now: drop it so the screen draws
	# one background instead of two.
	if is_instance_valid(_bg_blur):
		_bg_blur.visible = false
		_bg_blur.texture = null


func _get_lesson_title() -> String:
	var titles: Array = LESSON_TITLES.get(_book, [])
	if _lesson - 1 < titles.size():
		return titles[_lesson - 1]
	return ""


func _build_ui() -> void:
	# Book artwork, on its own canvas layer so scene transitions never slide it
	# (a sliding background is what used to flash the flat theme fill).
	# Two stacked stills: the blurred cover the book menu hands over on, and the
	# sharp picture faded in on top of it by _animate_background_in().
	var bg_layer := CanvasLayer.new()
	bg_layer.name = "BackgroundLayer"
	bg_layer.layer = -1

	_bg_blur = _make_background_still(
		"BackgroundBlur",
		"res://assets/images/ui/book_scene/Vision%d_blur.png" % _book
	)
	bg_layer.add_child(_bg_blur)

	_bg_clear = _make_background_still(
		"BackgroundClear",
		"res://assets/images/ui/book_scene/Vision%d.png" % _book
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

	var sections: Array = SECTIONS_VISION_1 if _book == 1 else SECTIONS_VISION_2_3
	for i in sections.size():
		var sec: Array = sections[i]
		var label_en: String = sec[0]
		var label_fa: String = sec[1]
		var emoji: String = sec[2]
		var scene_key: String = sec[3]
		var accent: Color = SECTION_ACCENT_COLORS[i % SECTION_ACCENT_COLORS.size()]

		var card: Button = MenuStyle.make_card(label_en, label_fa, emoji, accent, 150)
		card.pressed.connect(_on_section_pressed.bind(scene_key))
		MenuStyle.wire_microinteractions(card)
		# Glossy face + shine coating, both tinted with the section's accent.
		MenuStyle.style_gloss_card(card, accent, CARD_RADIUS)
		_col.add_child(card)
		_card_buttons.append(card)
		_card_accents.append(accent)

	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.custom_minimum_size = Vector2(0, 40)
	_col.add_child(spacer)

	_col.add_child(MenuStyle.make_tip_card("بخشها را به ترتیب پیش ببر تا بهتر یاد بگیری 🌱", "🌟"))

	# ---- Header bar (added last so it paints over the scrolling cards) ----
	_build_header()


## Fixed bar across the top of the screen: the main menu's header bar, sized the
## same way, carrying this screen's top label. It ignores the mouse so wheel and
## drag gestures in the bar's area still reach the card list underneath it.
func _build_header() -> void:
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = MenuStyle.surface()
	bar_style.corner_radius_bottom_left = HEADER_RADIUS
	bar_style.corner_radius_bottom_right = HEADER_RADIUS

	_header = PanelContainer.new()
	_header.name = "HeaderBar"
	_header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_header.offset_bottom = HEADER_HEIGHT
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header.add_theme_stylebox_override("panel", bar_style)
	add_child(_header)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", HEADER_PAD_X)
	margin.add_theme_constant_override("margin_right", HEADER_PAD_X)
	_header.add_child(margin)

	var row := VBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(row)

	# The screen's top label, now the title of the bar. _apply_theme() tints it
	# with the current book's accent colour.
	_title_label = Label.new()
	_title_label.text = HEADER_TEXT
	_title_label.add_theme_font_override("font", MenuStyle.vazir())
	_title_label.add_theme_font_size_override("font_size", HEADER_LABEL_SIZE)
	_title_label.add_theme_color_override("font_color", MenuStyle.text())
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.custom_minimum_size = Vector2(0, HEADER_LABEL_HEIGHT)
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_title_label)


## Full-screen background still. Uses the same fit as the book menu's covers so
## the two screens line up pixel for pixel when the picture is handed over.
func _make_background_still(still_name: String, texture_path: String) -> TextureRect:
	var still := TextureRect.new()
	still.name = still_name
	still.set_anchors_preset(Control.PRESET_FULL_RECT)
	still.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	still.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	still.mouse_filter = Control.MOUSE_FILTER_IGNORE
	still.texture = load(texture_path)
	return still


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
	var book_accent: Color = BOOK_COLORS.get(_book, MenuStyle.accent())
	if _title_label:
		_title_label.add_theme_color_override("font_color", book_accent)
	if _subtitle_badge:
		_subtitle_badge.add_theme_stylebox_override("normal", MenuStyle.icon_chip(book_accent, 26))
		_subtitle_badge.add_theme_color_override("font_color", MenuStyle.pill_text(book_accent))
	for i in _card_buttons.size():
		var btn: Button = _card_buttons[i]
		var accent: Color = _card_accents[i]
		# Glossy cards: the same call that built them restyles them, so a theme
		# change re-tints the face and the sheen instead of dropping the gloss.
		MenuStyle.style_gloss_card(btn, accent, CARD_RADIUS)
		var tl: Label = btn.get_node_or_null("Margin/Row/TextColumn/TitleLabel") as Label
		if tl:
			tl.add_theme_color_override("font_color", MenuStyle.text())
		var sl: Label = btn.get_node_or_null("Margin/Row/TextColumn/SubLabel") as Label
		if sl:
			sl.add_theme_color_override("font_color", MenuStyle.subtitle_color())


############################################################
# NAVIGATION
############################################################
func _on_section_pressed(scene_key: String) -> void:
	if _navigating:
		return
	_navigating = true
	Global.set_last_scene(get_tree().current_scene.scene_file_path)

	if scene_key == "VOCAB":
		AppRouter.set_args({"mode": "lesson"})

	var scene_map := {
		"VOCAB": SCENE_VOCAB,
		"CONVERSATION": SCENE_CONVERSATION,
		"READING": SCENE_READING,
		"VOCAB_DEVELOPMENT": SCENE_VOCAB_DEVELOPMENT,
		"GRAMMAR": SCENE_GRAMMAR,
		"LISTENING_SPEAKING": SCENE_LISTENING_SPEAKING,
		"PRONUNCIATION": SCENE_PRONUNCIATION,
		"WRITING": SCENE_WRITING,
		"WHAT_YOU_LEARNED": SCENE_WHAT_YOU_LEARNED,
		"WORKBOOK": SCENE_WORKBOOK,
	}
	var path: String = scene_map.get(scene_key, "")
	if path == "":
		push_error("No scene path for key: " + scene_key)
		_navigating = false
		return

	await get_tree().create_timer(0.10).timeout
	if not is_inside_tree():
		return

	# Grammar is part of the main menu flow, so it slides FORWARD like
	# book-menu -> lesson-menu. Other drill-downs keep the fade transition.
	if scene_key == "GRAMMAR":
		TransitionManager.slide_change_scene(path, TransitionManager.Slide.FORWARD)
	else:
		TransitionManager.change_scene(path)


func _on_android_back_pressed() -> void:
	if _navigating:
		return
	_navigating = true
	await get_tree().create_timer(0.10).timeout
	if not is_inside_tree():
		return
	TransitionManager.slide_change_scene(SCENE_BOOK_MENU, TransitionManager.Slide.BACK)
