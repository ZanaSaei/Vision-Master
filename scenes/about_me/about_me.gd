extends "res://autoload/BackButtonHandler.gd"
## ============================================================
##  ABOUT ME — a polished developer/author page.
##  Shown via the side-menu «درباره من» entry (fade transition).
##  Uses the persistent bottom navigation for scene changes.
## ============================================================

const DEV_EMAIL := "mrsaei@example.com"   # TODO: replace with your real contact
const DEV_INSTAGRAM := "@mrsaei"           # TODO: replace with your real handle

# --- Node references (match AboutMe.tscn) ---
@onready var bg: ColorRect = $Bg
@onready var email_button: Button = $Scroll/Margin/Layout/ContactCard/VBox/EmailRow
@onready var instagram_button: Button = $Scroll/Margin/Layout/ContactCard/VBox/InstagramRow
@onready var version_value: Label = $Scroll/Margin/Layout/Footer/VersionValue


func _ready() -> void:
	wire_header_bar()
	version_value.text = "نسخه " + _app_version()
	email_button.pressed.connect(_on_email_pressed)
	instagram_button.pressed.connect(_on_instagram_pressed)
	Global.on_theme_changed(_on_theme_changed)
	_apply_theme()


func _on_theme_changed(_mode: int) -> void:
	_apply_theme()


# ══════════════════════════════════════════════════════════════
#  THEME AWARENESS — restyle this page for Dark / Light
# ══════════════════════════════════════════════════════════════
func _apply_theme() -> void:
	bg.color = Global.get_theme_color("bg_base")
	_theme_walk(self)

func _theme_walk(node: Node) -> void:
	# The bottom NavigationBar owns its own bespoke styling — leave it alone.
	if node.name == "NavigationBar":
		return
	# The app-wide header bar paints its own surface and type ramp; the card
	# style below must never repaint it.
	if node.name == "HeaderBar":
		return
	if node is ColorRect and node.name == "Bg":
		bg.color = Global.get_theme_color("bg_base")
	elif node is PanelContainer and node.name != "Avatar":
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(26)
		style.content_margin_left = 44.0
		style.content_margin_top = 38.0
		style.content_margin_right = 44.0
		style.content_margin_bottom = 38.0
		if Global.theme_is_dark():
			style.bg_color = Color(1, 1, 1, 0.06)
			style.border_color = Color(1, 1, 1, 0.10)
		else:
			style.bg_color = Color(1, 1, 1, 0.85)
			style.border_color = Color(0, 0, 0, 0.10)
		style.set_border_width_all(1)
		node.add_theme_stylebox_override("panel", style)
	elif node is Label:
		_theme_label(node)
	elif node is Button:
		node.add_theme_color_override("font_color", Global.get_theme_color("text"))
	for child in node.get_children():
		_theme_walk(child)


func _theme_label(label: Label) -> void:
	var n: String = label.name
	if n.ends_with("Title"):
		label.add_theme_color_override("font_color", Global.get_theme_color("accent_bright"))
	elif n in ["Subtitle", "ContactHint", "VersionValue", "CreditLabel"]:
		label.add_theme_color_override("font_color", Global.get_theme_color("text_dim"))
	elif n == "Role":
		label.add_theme_color_override("font_color", Global.get_theme_color("accent_bright"))
	else:
		label.add_theme_color_override("font_color", Global.get_theme_color("text"))


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
func _on_android_back_pressed() -> void:
	Sfx.click()
	TransitionManager.change_scene("res://scenes/main_menu/MainMenu.tscn")
