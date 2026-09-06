extends "res://autoload/BackButtonHandler.gd"

# ============================================================
#  FINAL EXAMS — placeholder screen.
#  The real exam flow isn't implemented yet; this screen exists
#  so navigating here shows a friendly, themed message with a
#  WORKING back button instead of a blank, unescapable page.
# ============================================================

const SCENE_MAIN_MENU := "res://scenes/main_menu/MainMenu.tscn"
const BACK_ICON       := "res://images/Back.png"


func _ready() -> void:
	_build_ui()
	_apply_theme()
	Global.on_theme_changed(_on_theme_changed)


func _build_ui() -> void:
	# Page background.
	var bg := ColorRect.new()
	bg.name = "Bg"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Header bar with a working back button.
	var header := PanelContainer.new()
	header.name = "HeaderBar"
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.offset_bottom = 220.0
	header.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(header)

	var h_margin := MarginContainer.new()
	h_margin.add_theme_constant_override("margin_left", 36)
	h_margin.add_theme_constant_override("margin_right", 36)
	h_margin.add_theme_constant_override("margin_top", 60)
	h_margin.add_theme_constant_override("margin_bottom", 24)
	header.add_child(h_margin)

	var h_row := HBoxContainer.new()
	h_row.add_theme_constant_override("separation", 20)
	h_margin.add_child(h_row)

	var back := MenuStyle.make_back_button(BACK_ICON, 132)
	back.pressed.connect(_on_back_pressed)
	MenuStyle.wire_microinteractions(back)
	h_row.add_child(back)

	var title := Label.new()
	title.name = "HeaderTitle"
	title.text = "آزمون‌های نهایی"
	title.add_theme_font_override("font", MenuStyle.vazir())
	title.add_theme_font_size_override("font_size", 44)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h_row.add_child(title)

	# Centered "coming soon" content.
	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 28)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(center)

	var icon := Label.new()
	icon.text = "📝"
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 120)
	center.add_child(icon)

	var msg := Label.new()
	msg.name = "MessageLabel"
	msg.text = "آزمون‌های نهایی به‌زودی اضافه می‌شوند."
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD
	msg.add_theme_font_override("font", MenuStyle.vazir())
	msg.add_theme_font_size_override("font_size", 40)
	center.add_child(msg)

	var sub := Label.new()
	sub.name = "SubLabel"
	sub.text = "فعلاً با دکمه برگشت به منوی اصلی برگردید."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD
	sub.add_theme_font_override("font", MenuStyle.vazir())
	sub.add_theme_font_size_override("font_size", 30)
	center.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	center.add_child(spacer)

	var home_btn := Button.new()
	home_btn.name = "HomeButton"
	home_btn.text = "بازگشت به منوی اصلی"
	home_btn.add_theme_font_override("font", MenuStyle.vazir())
	home_btn.add_theme_font_size_override("font_size", 34)
	home_btn.custom_minimum_size = Vector2(420, 96)
	home_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	home_btn.pressed.connect(_on_back_pressed)
	MenuStyle.wire_microinteractions(home_btn)
	center.add_child(home_btn)


func _apply_theme() -> void:
	if not is_inside_tree():
		return
	var bg: ColorRect = get_node_or_null("Bg")
	if bg:
		bg.color = Global.get_theme_color("bg")
	var header: PanelContainer = get_node_or_null("HeaderBar")
	if header:
		header.add_theme_stylebox_override("panel", MenuStyle.header_bar_style(44, true))
	var msg: Label = get_node_or_null("MessageLabel")
	if msg:
		msg.add_theme_color_override("font_color", Global.get_theme_color("text"))
	var sub: Label = get_node_or_null("SubLabel")
	if sub:
		sub.add_theme_color_override("font_color", Global.get_theme_color("text_dim"))
	var title: Label = get_node_or_null("HeaderTitle")
	if title:
		title.add_theme_color_override("font_color", Global.get_theme_color("accent_bright"))
	var home_btn: Button = get_node_or_null("HomeButton")
	if home_btn:
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(26)
		style.bg_color = Global.get_theme_color("accent")
		style.set_content_margin_all(20)
		home_btn.add_theme_stylebox_override("normal", style)
		home_btn.add_theme_stylebox_override("hover", style)
		home_btn.add_theme_stylebox_override("pressed", style)
		home_btn.add_theme_color_override("font_color", Global.get_theme_color("on_accent"))


func _on_theme_changed(_mode: int) -> void:
	_apply_theme()


func _on_back_pressed() -> void:
	Sfx.click()
	TransitionManager.change_scene(SCENE_MAIN_MENU)


func _on_android_back_pressed() -> void:
	_on_back_pressed()
