extends "res://autoload/BackButtonHandler.gd"

############################################################
# LESSON MENU — modern, friendly section picker.
# Shows the section cards for Global.current_book + current_lesson.
# Navigation: GRAMMAR slides forward; other sections fade.
# The animated background lives in the MenuBackground autoload.
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

var _navigating: bool = false
var _book: int = 1
var _lesson: int = 1

# Built UI state.
var _scroll: ScrollContainer = null
var _col: VBoxContainer = null
var _title_label: Label = null
var _subtitle_badge: Label = null
var _card_buttons: Array[Button] = []
var _card_accents: Array[Color] = []


func _ready() -> void:
	_book = Global.current_book
	_lesson = Global.current_lesson

	# Kick off the on-demand download of this lesson's media (audio + images)
	# so every section opened from here has its files locally.
	Content.ensure_lesson(_book, _lesson)

	_build_ui()

	# Save current scene for back navigation from drill-down scenes.
	# `current_scene` is only set when this screen is reached through a scene
	# change, so fall back to this node's own path: the screen must also be
	# instantiable in isolation (tooling, tests) without crashing on null.
	var current := get_tree().current_scene
	Global.set_last_scene(current.scene_file_path if current != null else scene_file_path)

	Global.on_theme_changed(_on_theme_changed)
	_apply_theme()

	# Gentle entrance.
	_scroll.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_scroll, "modulate:a", 1.0, 0.30) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _get_lesson_title() -> String:
	var titles: Array = LESSON_TITLES.get(_book, [])
	if _lesson - 1 < titles.size():
		return titles[_lesson - 1]
	return ""


func _build_ui() -> void:
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
	outer.add_theme_constant_override("margin_top", 48)
	outer.add_theme_constant_override("margin_bottom", 170)
	_scroll.add_child(outer)

	_col = VBoxContainer.new()
	_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_col.add_theme_constant_override("separation", 18)
	outer.add_child(_col)

	var hero := Label.new()
	hero.text = "یک بخش را انتخاب کنید 👇"
	hero.add_theme_font_override("font", MenuStyle.vazir())
	hero.add_theme_font_size_override("font_size", 40)
	hero.add_theme_color_override("font_color", MenuStyle.text_dim())
	hero.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero.custom_minimum_size = Vector2(0, 70)
	_col.add_child(hero)

	var sections: Array = SECTIONS_VISION_1 if _book == 1 else SECTIONS_VISION_2_3
	for i in sections.size():
		var sec: Array = sections[i]
		var label_en: String = sec[0]
		var label_fa: String = sec[1]
		var emoji: String = sec[2]
		var scene_key: String = sec[3]
		var accent: Color = SECTION_ACCENT_COLORS[i % SECTION_ACCENT_COLORS.size()]

		var card: Button = MenuStyle.make_card(label_en, label_fa, emoji, accent, 150, "", true)
		card.pressed.connect(_on_section_pressed.bind(scene_key))
		MenuStyle.wire_microinteractions(card)
		_col.add_child(card)
		_card_buttons.append(card)
		_card_accents.append(accent)

	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.custom_minimum_size = Vector2(0, 40)
	_col.add_child(spacer)

	_col.add_child(MenuStyle.make_tip_card("بخشها را به ترتیب پیش ببر تا بهتر یاد بگیری 🌱", "🌟"))


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
		btn.add_theme_stylebox_override("normal", MenuStyle.card_style(accent, 26, false, true))
		btn.add_theme_stylebox_override("hover", MenuStyle.card_hover_style(accent, 26, true))
		btn.add_theme_stylebox_override("pressed", MenuStyle.card_pressed_style(accent, 26, true))
		btn.add_theme_stylebox_override("focus", MenuStyle.card_hover_style(accent, 26, true))
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
