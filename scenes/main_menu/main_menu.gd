extends "res://autoload/BackButtonHandler.gd"

############################################################
# MAIN MENU — modern, friendly, animated (Godot 4.7)
# Rebuilt with the shared MenuStyle design language:
# greeting hero, rounded book cards, exam card, side menu.
# The animated backdrop lives in the MenuBackground autoload.
############################################################

# --- Scene paths ---
const SCENE_BOOK_MENU    := "res://scenes/book_menu/BookMenu.tscn"
const SCENE_SAVED_WORDS  := "res://scenes/saved_words/SavedWords.tscn"
const SCENE_SETTINGS     := "res://scenes/settings/Settings.tscn"
const SCENE_ACCOUNT      := "res://scenes/auth/Auth.tscn"
const SCENE_FINAL_EXAMS  := "res://scenes/exam/FinalExams.tscn"
const SCENE_PURCHASE     := "res://scenes/purchase/Purchase.tscn"
const SCENE_LEITNER      := "res://scenes/review/WordReview.tscn"
const SCENE_ABOUT_ME     := "res://scenes/about_me/AboutMe.tscn"
const SCENE_MAIN_MENU    := "res://scenes/main_menu/MainMenu.tscn"

# --- Per-book accent identities (friendly, modern) ---
const COLOR_BOOK1 := Color("#3B82F6")   # Vision 1 — solid light blue
const COLOR_BOOK2 := Color("#22C55E")   # Vision 2 — solid green
const COLOR_BOOK3 := Color("#EF4444")   # Vision 3 — solid red
const COLOR_EXAM  := Color("#7C3AED")   # Final exams — violet

# --- Book metadata ---
const BOOK_EMOJI := { 1: "📘", 2: "📗", 3: "📕" }
const BOOK_COVER := {
	1: "res://images/Vision 1.jpg",
	2: "res://images/Vision 2.jpg",
	3: "res://images/Vision 3.jpg",
}
# Cover cards are taller than the default so the portrait cover chip (108x150)
# sits inside with clean, balanced margins and is never cropped or distorted.
const BOOK_CARD_HEIGHT := 176
const BOOK_SUBTITLE := {
	1: "پایه دهم · ۴ درس",
	2: "پایه یازدهم · ۳ درس",
	3: "پایه دوازدهم · ۳ درس",
}

# --- Built UI state ---
var _navigating: bool = false
var _card_buttons: Array[Button] = []
var _card_accents: Array[Color] = []
var _hamburger: Button = null
var _side_menu: Node = null
var _back_message_nodes: Array[Node] = []   # active exit-confirmation overlays

@onready var _root_scroll: ScrollContainer = null
@onready var _main_col: VBoxContainer = null


############################################################
# READY
############################################################
func _ready() -> void:
	_build_ui()

	# Side menu wiring (instance lives in the scene).
	_side_menu = $SideMenu
	_side_menu.set_hamburger_button(_hamburger)
	_hamburger.pressed.connect(_side_menu.toggle)
	_side_menu.saved_words_pressed.connect(_on_side_menu_saved_words_pressed)
	_side_menu.settings_pressed.connect(_on_side_menu_settings_pressed)
	_side_menu.account_pressed.connect(_on_side_menu_account_pressed)
	_side_menu.purchase_pressed.connect(_on_side_menu_purchase_pressed)
	_side_menu.leitner_pressed.connect(_on_side_menu_leitner_pressed)
	_side_menu.about_me_pressed.connect(_on_side_menu_about_me_pressed)

	Global.on_theme_changed(_on_theme_changed)

	# Entrance — cinematic stagger on first visit, instant otherwise.
	if not Global.intro_animation_played:
		Global.intro_animation_played = true
		_play_intro_animation()
	else:
		_start_ambient()


############################################################
# UI BUILD
############################################################
func _build_ui() -> void:
	_root_scroll = ScrollContainer.new()
	_root_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_root_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_root_scroll.add_theme_constant_override("margin_left", 40)
	_root_scroll.add_theme_constant_override("margin_right", 40)
	add_child(_root_scroll)

	var outer := MarginContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_theme_constant_override("margin_left", 40)
	outer.add_theme_constant_override("margin_right", 40)
	outer.add_theme_constant_override("margin_top", 150)
	outer.add_theme_constant_override("margin_bottom", 72)
	_root_scroll.add_child(outer)

	_main_col = VBoxContainer.new()
	_main_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_main_col.add_theme_constant_override("separation", 26)
	_main_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(_main_col)

	# 1. Top row: logo mark + spacer (hamburger floats above, like the old design,
	# so it can slide with the drawer when the side menu opens).
	_main_col.add_child(_build_top_row())
	_build_hamburger()

	# 2. Hero greeting.
	_main_col.add_child(_build_hero())

	# 3. Continue card (only when there is somewhere to continue to).
	if Global.has_last_scene():
		_main_col.add_child(_make_continue_card())

	# 4. Section label.
	var section_lbl := Label.new()
	section_lbl.name = "SectionLabel"
	section_lbl.text = "کتابهای درسی 📚"
	section_lbl.add_theme_font_override("font", MenuStyle.vazir())
	section_lbl.add_theme_font_size_override("font_size", 40)
	section_lbl.add_theme_color_override("font_color", MenuStyle.text_dim())
	section_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	section_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	section_lbl.custom_minimum_size = Vector2(0, 80)
	_main_col.add_child(section_lbl)

	# 5. Book cards — cover images on the left (taller cards for portrait covers).
	_add_card("Vision 1", BOOK_SUBTITLE[1], BOOK_EMOJI[1], COLOR_BOOK1, _on_book_pressed.bind(1), BOOK_COVER[1], BOOK_CARD_HEIGHT)
	_add_card("Vision 2", BOOK_SUBTITLE[2], BOOK_EMOJI[2], COLOR_BOOK2, _on_book_pressed.bind(2), BOOK_COVER[2], BOOK_CARD_HEIGHT)
	_add_card("Vision 3", BOOK_SUBTITLE[3], BOOK_EMOJI[3], COLOR_BOOK3, _on_book_pressed.bind(3), BOOK_COVER[3], BOOK_CARD_HEIGHT)

	# 6. Exam card.
	_add_card("امتحانات نهایی", "تمرین سوالات امتحان", "🎓", COLOR_EXAM, _on_exam_pressed)

	# Bottom breathing room.
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.custom_minimum_size = Vector2(0, 64)
	_main_col.add_child(spacer)


func _build_top_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 16)
	row.custom_minimum_size = Vector2(0, 104)

	# The logo mark ("V") was removed — it was purely decorative and not
	# needed. The top row is now just an empty breathing spacer so the
	# hamburger keeps its floating top-right position.
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	return row


## Floating hamburger button pinned to the top-right corner (NOT inside a
## container), so the side menu can slide it left alongside the drawer — the
## original pre-modernization behaviour.
func _build_hamburger() -> void:
	_hamburger = Button.new()
	_hamburger.text = "☰ منو"
	_hamburger.add_theme_font_override("font", MenuStyle.vazir())
	_hamburger.add_theme_font_size_override("font_size", 40)
	_hamburger.custom_minimum_size = Vector2(190, 96)
	_hamburger.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_hamburger.offset_left = -230
	_hamburger.offset_top = 150
	_hamburger.offset_right = -40
	_hamburger.offset_bottom = 246
	add_child(_hamburger)
	_apply_hamburger_style()
	MenuStyle.wire_microinteractions(_hamburger)


func _build_hero() -> VBoxContainer:
	var hero := VBoxContainer.new()
	hero.name = "HeroVBox"
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.add_theme_constant_override("separation", 8)
	hero.custom_minimum_size = Vector2(0, 330)

	var greeting := Label.new()
	greeting.name = "GreetingLabel"
	greeting.text = "سلام! 👋"
	greeting.add_theme_font_override("font", MenuStyle.vazir())
	greeting.add_theme_font_size_override("font_size", 58)
	greeting.add_theme_color_override("font_color", MenuStyle.accent_bright())
	greeting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero.add_child(greeting)

	var title := Label.new()
	title.name = "AppTitle"
	title.text = "Vision Master"
	title.add_theme_font_override("font", MenuStyle.josefin())
	title.add_theme_font_size_override("font_size", 108)
	title.add_theme_color_override("font_color", _wordmark_color())
	# Violet-tinted glow so the wordmark lifts off either background.
	title.add_theme_color_override("font_shadow_color", Color(0.36, 0.16, 0.9, 0.20))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hero.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "AppSubtitle"
	subtitle.text = "یادگیری زبان انگلیسی مدرسه · متوسطه دوم"
	subtitle.add_theme_font_override("font", MenuStyle.vazir())
	subtitle.add_theme_font_size_override("font_size", 38)
	subtitle.add_theme_color_override("font_color", MenuStyle.subtitle_color())
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero.add_child(subtitle)

	return hero


func _make_continue_card() -> Button:
	var card: Button = MenuStyle.make_card("ادامه بده", "به آخرین بخش برگرد", "🚀", MenuStyle.accent(), 148, "", true)
	card.name = "ContinueButton"
	card.pressed.connect(_on_continue_pressed)
	return card


func _add_card(title: String, subtitle: String, emoji: String, accent: Color, on_pressed: Callable, image_path: String = "", min_height: int = 158) -> void:
	var card: Button = MenuStyle.make_card(title, subtitle, emoji, accent, min_height, image_path, true)
	card.pressed.connect(on_pressed)
	MenuStyle.wire_microinteractions(card)
	_main_col.add_child(card)
	_card_buttons.append(card)
	_card_accents.append(accent)


############################################################
# HAMBURGER PILL
############################################################
func _apply_hamburger_style() -> void:
	if _hamburger == null:
		return
	var dark := MenuStyle.is_dark()
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#FFF7BA", 0.96) if not dark else Color(0.09, 0.10, 0.20, 0.96)
	normal.set_corner_radius_all(48)
	normal.set_border_width_all(1)
	normal.border_color = MenuStyle.accent() if not dark else Color(1, 1, 1, 0.18)
	# Flat: no drop shadow on the floating pill.
	normal.shadow_size = 0
	normal.shadow_offset = Vector2.ZERO
	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = MenuStyle.accent_bright()
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = MenuStyle.accent_soft() if not dark else Color(1, 1, 1, 0.08)
	_hamburger.add_theme_stylebox_override("normal", normal)
	_hamburger.add_theme_stylebox_override("hover", hover)
	_hamburger.add_theme_stylebox_override("pressed", pressed)
	_hamburger.add_theme_stylebox_override("focus", hover)
	var fc := MenuStyle.text() if not dark else Color(1, 1, 1)
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_hamburger.add_theme_color_override(st, fc)


############################################################
# THEME AWARENESS
############################################################
func _wordmark_color() -> Color:
	# One brand violet, tuned per theme for perfect contrast:
	# · Dark  → bright luminous lavender (#C4B5FD) that pops off the navy.
	# · Light → deep rich violet (#5B21B6) that pops off the pale periwinkle.
	# Same hue family in both — the wordmark is visible and beautiful no
	# matter which theme the user has chosen.
	if MenuStyle.is_dark():
		return Color(0.769, 0.71, 0.992)
	return Color(0.357, 0.129, 0.714)


func _on_theme_changed(_mode: int) -> void:
	_apply_theme()


func _apply_theme() -> void:
	if not is_inside_tree():
		return
	# Restyle theme-dependent labels.
	var greeting: Label = _main_col.get_node_or_null("HeroVBox/GreetingLabel") as Label
	if greeting:
		greeting.add_theme_color_override("font_color", MenuStyle.accent_bright())
	var title: Label = _main_col.get_node_or_null("HeroVBox/AppTitle") as Label
	if title:
		title.add_theme_color_override("font_color", _wordmark_color())
	_apply_hamburger_style()
	# Rebuild card styleboxes (flat — MainMenu buttons have no elevation).
	for i in _card_buttons.size():
		var btn: Button = _card_buttons[i]
		var accent := _card_accents[i]
		btn.add_theme_stylebox_override("normal", MenuStyle.card_style(accent, 26, false, true))
		btn.add_theme_stylebox_override("hover", MenuStyle.card_hover_style(accent, 26, true))
		btn.add_theme_stylebox_override("pressed", MenuStyle.card_pressed_style(accent, 26, true))
		btn.add_theme_stylebox_override("focus", MenuStyle.card_hover_style(accent, 26, true))
		# Title / subtitle / chevron colours.
		var tl: Label = btn.get_node_or_null("Margin/Row/TextColumn/TitleLabel") as Label
		if tl:
			tl.add_theme_color_override("font_color", MenuStyle.text())
		var sl: Label = btn.get_node_or_null("Margin/Row/TextColumn/SubLabel") as Label
		if sl:
			sl.add_theme_color_override("font_color", MenuStyle.subtitle_color())


############################################################
# AMBIENT LIFE + INTRO
############################################################
func _start_ambient() -> void:
	var title: Label = _main_col.get_node_or_null("HeroVBox/AppTitle") as Label
	if title == null:
		return
	var tw := create_tween().set_loops()
	tw.tween_property(title, "scale", Vector2(1.03, 1.03), 3.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(title, "scale", Vector2.ONE, 3.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _play_intro_animation() -> void:
	var targets: Array[Control] = []
	for child in _main_col.get_children():
		if child is Control and not child.is_queued_for_deletion():
			targets.append(child)

	for t in targets:
		t.modulate.a = 0.0
		t.position += Vector2(0, 30)

	await get_tree().process_frame
	if not is_inside_tree():
		return

	for i in targets.size():
		var t: Control = targets[i]
		var tw := create_tween()
		tw.tween_interval(0.06 * i)
		tw.tween_property(t, "modulate:a", 1.0, 0.30) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(t, "position:y", t.position.y - 30.0, 0.30) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(0.06 * targets.size() + 0.4).timeout
	if not is_inside_tree():
		return
	_start_ambient()


############################################################
# NAVIGATION
############################################################
func _on_continue_pressed() -> void:
	if _navigating:
		return
	var last := Global.get_last_scene()
	if last == "":
		return
	_navigating = true
	await get_tree().create_timer(0.10).timeout
	if not is_inside_tree():
		return
	TransitionManager.slide_change_scene(last, TransitionManager.Slide.FORWARD)


func _on_book_pressed(book_number: int) -> void:
	if _navigating:
		return
	_navigating = true
	Global.current_book = book_number
	await get_tree().create_timer(0.10).timeout
	if not is_inside_tree():
		return
	TransitionManager.slide_change_scene(SCENE_BOOK_MENU, TransitionManager.Slide.FORWARD)


func _on_exam_pressed() -> void:
	if _navigating:
		return
	_navigating = true
	await get_tree().create_timer(0.10).timeout
	if not is_inside_tree():
		return
	TransitionManager.slide_change_scene(SCENE_FINAL_EXAMS, TransitionManager.Slide.FORWARD)


func _on_side_menu_about_me_pressed() -> void:
	if _navigating:
		return
	_navigating = true
	TransitionManager.change_scene(SCENE_ABOUT_ME)


func _on_side_menu_account_pressed() -> void:
	if _navigating:
		return
	_navigating = true
	TransitionManager.change_scene(SCENE_ACCOUNT)


func _on_side_menu_saved_words_pressed() -> void:
	if _navigating:
		return
	_navigating = true
	AppRouter.set_args({"mode": "saved"})
	TransitionManager.change_scene(SCENE_SAVED_WORDS)


func _on_side_menu_leitner_pressed() -> void:
	if _navigating:
		return
	_navigating = true
	AppRouter.set_args({"return_route": SCENE_MAIN_MENU})
	TransitionManager.change_scene(SCENE_LEITNER)


func _on_side_menu_settings_pressed() -> void:
	if _navigating:
		return
	_navigating = true
	TransitionManager.change_scene(SCENE_SETTINGS)


func _on_side_menu_purchase_pressed() -> void:
	if _navigating:
		return
	_navigating = true
	TransitionManager.change_scene(SCENE_PURCHASE)


############################################################
# ANDROID BACK (double-tap to exit)
############################################################
func _on_android_back_pressed() -> void:
	var current_time := Time.get_unix_time_from_system()
	if back_pressed_time > 0 and current_time - back_pressed_time < double_back_timeout:
		get_tree().quit()
	else:
		back_pressed_time = current_time
		_show_back_message()


func _show_back_message() -> void:
	# Only one exit message at a time — pressing back again while it shows
	# either quits (double-press) or is ignored, never stacks overlays.
	if not _back_message_nodes.is_empty():
		return
	var message := Label.new()
	message.text = "برای خروج دوباره دکمه برگشت را بزنید"
	message.add_theme_font_override("font", MenuStyle.vazir())
	message.add_theme_font_size_override("font_size", 38)
	message.add_theme_color_override("font_color", Color.WHITE)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.anchor_left = 0.0
	message.anchor_top = 0.0
	message.anchor_right = 1.0
	message.anchor_bottom = 1.0
	message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(message)

	var bg := ColorRect.new()
	bg.color = Color("#0F172A", 0.72)
	bg.anchor_left = 0.0
	bg.anchor_top = 0.0
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	move_child(bg, 0)

	_back_message_nodes = [bg, message]

	await get_tree().create_timer(1.5).timeout
	if not is_inside_tree():
		return

	var tw := create_tween()
	tw.parallel().tween_property(bg, "modulate:a", 0.0, 0.3)
	tw.parallel().tween_property(message, "modulate:a", 0.0, 0.3)
	await tw.finished
	if not is_inside_tree():
		return

	bg.queue_free()
	message.queue_free()
	_back_message_nodes.clear()
