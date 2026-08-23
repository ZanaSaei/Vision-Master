extends "res://autoload/BackButtonHandler.gd"
## ============================================================
##  ABOUT ME — a polished developer/author page.
##  Shown via the side-menu «درباره من» entry (fade transition).
##  Back returns to the main menu.
## ============================================================

const SCENE_MAIN_MENU := "res://scenes/main_menu/MainMenu.tscn"
const DEV_EMAIL := "mrsaei@example.com"   # TODO: replace with your real contact
const DEV_INSTAGRAM := "@mrsaei"           # TODO: replace with your real handle

# --- Node references (match AboutMe.tscn) ---
@onready var back_button: Button = $Header/Margin/HBox/BackButton
@onready var email_button: Button = $Scroll/Margin/Layout/ContactCard/VBox/EmailRow
@onready var instagram_button: Button = $Scroll/Margin/Layout/ContactCard/VBox/InstagramRow
@onready var version_value: Label = $Scroll/Margin/Layout/Footer/VersionValue


func _ready() -> void:
	version_value.text = "نسخه " + _app_version()
	back_button.pressed.connect(_on_back_pressed)
	email_button.pressed.connect(_on_email_pressed)
	instagram_button.pressed.connect(_on_instagram_pressed)


func _on_instagram_pressed() -> void:
	Sfx.click()
	DisplayServer.clipboard_set(DEV_INSTAGRAM)
	_show_toast("اینستاگرام کپی شد ✓")


func _app_version() -> String:
	var v: Variant = ProjectSettings.get_setting("application/config/version", "")
	return str(v) if not str(v).is_empty() else "1.0.0"


func _on_email_pressed() -> void:
	Sfx.click()
	DisplayServer.clipboard_set(DEV_EMAIL)
	_show_toast("ایمیل کپی شد ✓")


# small confirmation banner (same style as the Settings toast)
func _show_toast(text: String) -> void:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.15, 0.97)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.760784, 0.611765, 1)
	style.set_corner_radius_all(24)
	style.content_margin_left = 48
	style.content_margin_top = 24
	style.content_margin_right = 48
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 38)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	label.add_theme_constant_override("outline_size", 8)
	panel.add_child(label)

	add_child(panel)
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.position.y -= 150
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2(0.82, 0.82)
	panel.modulate.a = 0.0

	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.22)
	tw.parallel().tween_property(panel, "scale", Vector2.ONE, 0.32) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.3)
	tw.tween_property(panel, "modulate:a", 0.0, 0.4)
	tw.tween_callback(panel.queue_free)


# ══════════════════════════════════════════════════════════════
#  NAVIGATION
# ══════════════════════════════════════════════════════════════
func _on_back_pressed() -> void:
	Sfx.click()
	TransitionManager.change_scene(SCENE_MAIN_MENU)


func _on_android_back_pressed() -> void:
	_on_back_pressed()
