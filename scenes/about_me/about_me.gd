extends "res://autoload/BackButtonHandler.gd"
## ============================================================
##  ABOUT ME — Redesigned Engaging & Modern Developer Scene
##  Vision Master English Learning Application
##  Developer: MrSaei
## ============================================================

const DEV_EMAIL := "mrsaei.dev@gmail.com"
const DEV_INSTAGRAM := "mrsaei_dev"
const INSTAGRAM_URL := "https://instagram.com/mrsaei_dev"
const EMAIL_URL := "mailto:mrsaei.dev@gmail.com?subject=Vision%20Master%20Feedback"

# --- Node references (match AboutMe.tscn) ---
@onready var bg: ColorRect = $Bg
@onready var scroll: ScrollContainer = $Scroll
@onready var layout: VBoxContainer = $Scroll/Margin/Layout

# Cards for staggered entrance animation
@onready var profile_card: PanelContainer = $Scroll/Margin/Layout/ProfileCard
@onready var highlights_card: PanelContainer = $Scroll/Margin/Layout/HighlightsCard
@onready var bio_card: PanelContainer = $Scroll/Margin/Layout/BioCard
@onready var contact_card: PanelContainer = $Scroll/Margin/Layout/ContactCard
@onready var app_card: PanelContainer = $Scroll/Margin/Layout/AppCard
@onready var footer: VBoxContainer = $Scroll/Margin/Layout/Footer

# Contact Action Buttons
@onready var btn_copy_instagram: Button = $Scroll/Margin/Layout/ContactCard/VBox/InstagramBox/VBox/Actions/CopyInstagramButton
@onready var btn_open_instagram: Button = $Scroll/Margin/Layout/ContactCard/VBox/InstagramBox/VBox/Actions/OpenInstagramButton
@onready var btn_copy_email: Button = $Scroll/Margin/Layout/ContactCard/VBox/EmailBox/VBox/Actions/CopyEmailButton
@onready var btn_open_email: Button = $Scroll/Margin/Layout/ContactCard/VBox/EmailBox/VBox/Actions/OpenEmailButton

@onready var version_value: Label = $Scroll/Margin/Layout/AppCard/VBox/VersionRow/VersionValue
@onready var footer_version: Label = $Scroll/Margin/Layout/Footer/VersionValue

var _current_toast: CanvasLayer = null


func _ready() -> void:
	wire_header_bar("درباره من")
	
	var app_ver: String = _app_version()
	if version_value != null:
		version_value.text = "نسخه " + app_ver
	if footer_version != null:
		footer_version.text = "Vision Master • نسخه " + app_ver

	_wire_interactive_buttons()
	_apply_theme()
	Global.on_theme_changed(_on_theme_changed)

	# Smooth staggered entrance animation
	_play_entrance_animation()


func _on_theme_changed(_mode: int) -> void:
	_apply_theme()


# ══════════════════════════════════════════════════════════════
#  INTERACTIVE BUTTONS & SPRING MICRO-INTERACTIONS
# ══════════════════════════════════════════════════════════════
func _wire_interactive_buttons() -> void:
	# Instagram actions
	if btn_copy_instagram != null:
		btn_copy_instagram.pressed.connect(_on_copy_instagram_pressed)
		_setup_button_spring(btn_copy_instagram)
	if btn_open_instagram != null:
		btn_open_instagram.pressed.connect(_on_open_instagram_pressed)
		_setup_button_spring(btn_open_instagram)

	# Email actions
	if btn_copy_email != null:
		btn_copy_email.pressed.connect(_on_copy_email_pressed)
		_setup_button_spring(btn_copy_email)
	if btn_open_email != null:
		btn_open_email.pressed.connect(_on_open_email_pressed)
		_setup_button_spring(btn_open_email)


## Adds tactile spring-physics micro-interaction to any button
func _setup_button_spring(button: Button) -> void:
	# Enforce center-pivot rule
	button.resized.connect(func() -> void:
		button.pivot_offset = button.size / 2.0
	)
	button.pivot_offset = button.size / 2.0

	var tween_ref: Array = [null]

	button.mouse_entered.connect(func() -> void:
		if tween_ref[0] and tween_ref[0].is_valid():
			tween_ref[0].kill()
		var tw: Tween = create_tween()
		tween_ref[0] = tw
		tw.tween_property(button, "scale", Vector2(1.03, 1.03), 0.14) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)

	button.mouse_exited.connect(func() -> void:
		if tween_ref[0] and tween_ref[0].is_valid():
			tween_ref[0].kill()
		var tw: Tween = create_tween()
		tween_ref[0] = tw
		tw.tween_property(button, "scale", Vector2.ONE, 0.18) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)

	button.button_down.connect(func() -> void:
		if tween_ref[0] and tween_ref[0].is_valid():
			tween_ref[0].kill()
		var tw: Tween = create_tween()
		tween_ref[0] = tw
		tw.tween_property(button, "scale", Vector2(0.96, 0.96), 0.08) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)

	button.button_up.connect(func() -> void:
		if tween_ref[0] and tween_ref[0].is_valid():
			tween_ref[0].kill()
		var tw: Tween = create_tween()
		tween_ref[0] = tw
		var target_scale: Vector2 = Vector2(1.03, 1.03) if button.is_hovered() else Vector2.ONE
		tw.tween_property(button, "scale", target_scale, 0.20) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)


# ══════════════════════════════════════════════════════════════
#  ACTIONS: INSTAGRAM & EMAIL
# ══════════════════════════════════════════════════════════════
func _on_copy_instagram_pressed() -> void:
	Sfx.click()
	DisplayServer.clipboard_set(DEV_INSTAGRAM)
	_show_toast("آیدی اینستاگرام کپی شد: %s ✓" % DEV_INSTAGRAM)


func _on_open_instagram_pressed() -> void:
	Sfx.click()
	var err: Error = OS.shell_open(INSTAGRAM_URL)
	if err == OK:
		_show_toast("در حال باز کردن اینستاگرام...")
	else:
		DisplayServer.clipboard_set(DEV_INSTAGRAM)
		_show_toast("آیدی اینستاگرام کپی شد: %s ✓" % DEV_INSTAGRAM)


func _on_copy_email_pressed() -> void:
	Sfx.click()
	DisplayServer.clipboard_set(DEV_EMAIL)
	_show_toast("ایمیل کپی شد: %s ✓" % DEV_EMAIL)


func _on_open_email_pressed() -> void:
	Sfx.click()
	var err: Error = OS.shell_open(EMAIL_URL)
	if err == OK:
		_show_toast("در حال باز کردن برنامه ایمیل...")
	else:
		DisplayServer.clipboard_set(DEV_EMAIL)
		_show_toast("ایمیل کپی شد: %s ✓" % DEV_EMAIL)


# ══════════════════════════════════════════════════════════════
#  ENTRANCE ANIMATION
# ══════════════════════════════════════════════════════════════
func _play_entrance_animation() -> void:
	var animated_cards: Array[Control] = [
		profile_card,
		highlights_card,
		bio_card,
		contact_card,
		app_card,
		footer
	]

	var delay: float = 0.04
	for i in range(animated_cards.size()):
		var card: Control = animated_cards[i]
		if card == null:
			continue
		card.pivot_offset = Vector2(card.size.x / 2.0, card.size.y / 2.0)
		card.modulate.a = 0.0
		card.scale = Vector2(0.96, 0.96)

		var tw: Tween = create_tween()
		tw.set_parallel(true)
		tw.tween_property(card, "modulate:a", 1.0, 0.28).set_delay(delay * i)
		tw.tween_property(card, "scale", Vector2.ONE, 0.36).set_delay(delay * i) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ══════════════════════════════════════════════════════════════
#  TOAST FEEDBACK
# ══════════════════════════════════════════════════════════════
func _show_toast(text: String) -> void:
	if _current_toast != null and is_instance_valid(_current_toast):
		_current_toast.queue_free()

	var toast_layer := CanvasLayer.new()
	toast_layer.layer = 2  # Above BottomNavigation
	add_child(toast_layer)
	_current_toast = toast_layer

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.15, 0.22, 0.96)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Global.get_theme_color("accent_bright")
	style.set_corner_radius_all(24)
	style.content_margin_left = 40.0
	style.content_margin_top = 20.0
	style.content_margin_right = 40.0
	style.content_margin_bottom = 20.0
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0, 8)
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.theme_override_constants_separation = 16
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var icon_label := Label.new()
	icon_label.text = "✓"
	icon_label.add_theme_font_size_override("font_size", 34)
	icon_label.add_theme_color_override("font_color", Global.get_theme_color("accent_bright"))
	hbox.add_child(icon_label)

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Color.WHITE)
	hbox.add_child(label)

	panel.add_child(hbox)
	toast_layer.add_child(panel)

	# Position above bottom navigation
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.position.y -= 230.0
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2(0.85, 0.85)
	panel.modulate.a = 0.0

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(panel, "modulate:a", 1.0, 0.22)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.32) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	tw.chain().tween_interval(2.0)
	tw.chain().tween_property(panel, "modulate:a", 0.0, 0.35)
	tw.parallel().tween_property(panel, "scale", Vector2(0.85, 0.85), 0.35) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(toast_layer.queue_free)


# ══════════════════════════════════════════════════════════════
#  THEME STYLING
# ══════════════════════════════════════════════════════════════
func _apply_theme() -> void:
	if bg != null:
		bg.color = Global.get_theme_color("bg_base")


func _app_version() -> String:
	var v: Variant = ProjectSettings.get_setting("application/config/version", "")
	return str(v) if not str(v).is_empty() else "1.0.0"


# ══════════════════════════════════════════════════════════════
#  NAVIGATION
# ══════════════════════════════════════════════════════════════
func _on_android_back_pressed() -> void:
	Sfx.click()
	TransitionManager.change_scene("res://scenes/main_menu/MainMenu.tscn")
