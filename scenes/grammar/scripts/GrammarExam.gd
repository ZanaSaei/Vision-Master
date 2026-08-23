class_name GrammarExam
extends "res://autoload/BackButtonHandler.gd"
# ============================================================
#  GRAMMAR EXAM — shell scene reached from the Grammar Hub's
#  "امتحان گرامر" button.
#  Reached from: GrammarHub  ->  Back returns to GrammarHub.
# ============================================================

const SCENE_HUB: String = "res://scenes/grammar/GrammarHub.tscn"

var _navigating: bool = false


func _ready() -> void:
	super._ready()
	# Use the shared animated background (MenuBackground autoload) exactly
	# like the other grammar scenes do.
	MenuBackground.enter_background()
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

	var back_button: Button = Button.new()
	back_button.text = "↩ قبلی"
	back_button.custom_minimum_size = Vector2(160.0, 64.0)
	back_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	GrammarTheme.style_secondary_button(back_button)
	var font: Font = GrammarTheme.get_fa_bold()
	if font != null:
		back_button.add_theme_font_override("font", font)
	back_button.add_theme_font_size_override("font_size", 26)
	back_button.pressed.connect(_on_back_pressed)
	header_row.add_child(back_button)

	var title_label: Label = Label.new()
	title_label.text = "امتحان گرامر"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if font != null:
		title_label.add_theme_font_override("font", font)
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.add_theme_color_override("font_color", GrammarTheme.TEXT)
	header_row.add_child(title_label)

	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(160.0, 1.0)
	header_row.add_child(spacer)

	var content_box: PanelContainer = PanelContainer.new()
	GrammarTheme.style_card(content_box)
	content_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(content_box)

	var content_margin: MarginContainer = MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", GrammarTheme.CONTENT_MARGIN)
	content_margin.add_theme_constant_override("margin_top", GrammarTheme.CONTENT_MARGIN)
	content_margin.add_theme_constant_override("margin_right", GrammarTheme.CONTENT_MARGIN)
	content_margin.add_theme_constant_override("margin_bottom", GrammarTheme.CONTENT_MARGIN)
	content_box.add_child(content_margin)

	var center: VBoxContainer = VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 16)
	content_margin.add_child(center)

	var icon: Label = Label.new()
	icon.text = "🎓"
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 80)
	center.add_child(icon)

	var msg: Label = Label.new()
	msg.text = "امتحان گرامر به‌زودی در دسترس خواهد بود."
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if font != null:
		msg.add_theme_font_override("font", font)
	msg.add_theme_font_size_override("font_size", 28)
	msg.add_theme_color_override("font_color", GrammarTheme.TEXT_MUTED)
	center.add_child(msg)


func _on_back_pressed() -> void:
	if _navigating:
		return
	_navigating = true
	TransitionManager.change_scene(SCENE_HUB)


func _on_android_back_pressed() -> void:
	_on_back_pressed()
