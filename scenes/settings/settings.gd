extends "res://autoload/BackButtonHandler.gd"
## ============================================================
##  SETTINGS — a polished, feature-complete settings screen.
##  Sections:
##    • صدا و گفتار  (sound effects + English TTS)
##    • داده‌ها      (clear saved words / review words / reset all)
##    • درباره برنامه (app version, subscription, developer)
##  The app uses the Light appearance exclusively.
##  Settings persist to user://settings.json via Global.
## ============================================================


# --- Node references (match Settings.tscn) ---
@onready var bg: ColorRect          = $Bg
@onready var sound_toggle: Button    = $Scroll/Margin/Layout/SoundCard/VBox/SoundRow/SoundToggle
@onready var tts_toggle: Button      = $Scroll/Margin/Layout/SoundCard/VBox/TtsRow/TtsToggle
@onready var clear_saved_button: Button = $Scroll/Margin/Layout/DataCard/VBox/ClearSavedButton
@onready var clear_review_button: Button = $Scroll/Margin/Layout/DataCard/VBox/ClearReviewButton
@onready var reset_button: Button        = $Scroll/Margin/Layout/DataCard/VBox/ResetButton
@onready var version_value: Label = $Scroll/Margin/Layout/AboutCard/VBox/VersionRow/VersionValue
@onready var sub_value: Label     = $Scroll/Margin/Layout/AboutCard/VBox/SubRow/SubValue

var _modal_root: Control = null      # full-screen wrapper (dims + centers the card)
var _confirm_card: PanelContainer
var _dim: ColorRect
var _confirm_title: Label
var _confirm_message: Label
var _confirm_ok: Button
var _confirm_cancel: Button
var _pending_action: Callable = Callable()


func _ready() -> void:
	wire_header_bar()
	# Initialise the toggles from the persisted settings.
	_set_toggle(sound_toggle, Global.sound_enabled)
	_set_toggle(tts_toggle, Global.tts_enabled)

	# About section values.
	version_value.text = _app_version()
	sub_value.text = _subscription_text()

	# Wiring.
	sound_toggle.pressed.connect(_on_sound_toggled)
	tts_toggle.pressed.connect(_on_tts_toggled)
	clear_saved_button.pressed.connect(_on_clear_saved_pressed)
	clear_review_button.pressed.connect(_on_clear_review_pressed)
	reset_button.pressed.connect(_on_reset_pressed)

	_build_extra_sections()
	_build_confirm_dialog()
	_apply_theme()


# ══════════════════════════════════════════════════════════════
#  SOUND & TTS TOGGLES (custom on/off switch buttons)
# ══════════════════════════════════════════════════════════════
func _set_toggle(btn: Button, on: bool) -> void:
	btn.text = "روشن" if on else "خاموش"
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(18)
	style.content_margin_left = 26.0
	style.content_margin_top = 16.0
	style.content_margin_right = 26.0
	style.content_margin_bottom = 16.0
	if on:
		style.bg_color = Global.get_theme_color("accent")
		style.border_color = Global.get_theme_color("accent_bright")
		style.set_border_width_all(2)
		btn.add_theme_color_override("font_color", Global.get_theme_color("on_accent"))
	else:
		style.bg_color = Global.get_theme_color("surface_alt")
		style.border_color = Global.get_theme_color("border")
		style.set_border_width_all(1)
		btn.add_theme_color_override("font_color", Global.get_theme_color("text"))
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)


# ══════════════════════════════════════════════════════════════
#  THEME AWARENESS — restyle this screen with the fixed Light palette
# ══════════════════════════════════════════════════════════════
func _apply_theme() -> void:
	# Keep the settings page on the same flat background as the rest of the app.
	bg.color = Global.get_theme_color("bg_base")

	# Cards + text walk the whole scene.
	_theme_walk(self)

	# Rebuild the custom toggles with the current palette.
	_set_toggle(sound_toggle, Global.sound_enabled)
	_set_toggle(tts_toggle, Global.tts_enabled)

	# Danger (reset) button: shared UI/Styles/danger treatment reads clearly
	# in both themes. Reused resource — edit the .tres to restyle.
	UiTheme.style_button(reset_button, "danger")

	# The two "clear" buttons: the scene's default white-on-white styles only
	# read on dark cards, so in Light theme they get a visible outline + fill.
	# (Hover states are irrelevant on touch devices, so every state is the same.)
	var clear_style := StyleBoxFlat.new()
	clear_style.set_corner_radius_all(18)
	clear_style.content_margin_left = 26.0
	clear_style.content_margin_top = 20.0
	clear_style.content_margin_right = 26.0
	clear_style.content_margin_bottom = 20.0
	clear_style.set_border_width_all(2)
	clear_style.bg_color = Color(1, 1, 1, 0.85)
	clear_style.border_color = Global.get_theme_color("accent")
	clear_saved_button.add_theme_stylebox_override("normal", clear_style)
	clear_saved_button.add_theme_stylebox_override("hover", clear_style)
	clear_saved_button.add_theme_stylebox_override("pressed", clear_style)
	clear_saved_button.add_theme_stylebox_override("focus", clear_style)
	clear_review_button.add_theme_stylebox_override("normal", clear_style)
	clear_review_button.add_theme_stylebox_override("hover", clear_style)
	clear_review_button.add_theme_stylebox_override("pressed", clear_style)
	clear_review_button.add_theme_stylebox_override("focus", clear_style)
	var clear_fc: Color = Global.get_theme_color("accent")
	clear_saved_button.add_theme_color_override("font_color", clear_fc)
	clear_review_button.add_theme_color_override("font_color", clear_fc)

	# The runtime confirm modal follows the palette too.
	if _confirm_card != null:
		var p := _confirm_card.get_theme_stylebox("panel") as StyleBoxFlat
		p.bg_color = Global.get_theme_color("surface")
		p.border_color = Global.get_theme_color("accent")
	_confirm_title.add_theme_color_override("font_color", Global.get_theme_color("accent_bright"))
	_confirm_message.add_theme_color_override("font_color", Global.get_theme_color("text"))

	_style_extra_buttons()


func _theme_walk(node: Node) -> void:
	var node_name: String = node.name
	if node == _modal_root:
		return
	# The bottom NavigationBar owns its own bespoke styling — leave it alone.
	if node_name == "NavigationBar":
		return
	# The app-wide header bar paints its own surface and type ramp; the card
	# style below must never repaint it.
	if node_name == "HeaderBar":
		return
	if node is ColorRect and node_name == "Bg":
		bg.color = Global.get_theme_color("bg_base")

	elif node is PanelContainer:
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(26)
		style.content_margin_left = 44.0
		style.content_margin_top = 38.0
		style.content_margin_right = 44.0
		style.content_margin_bottom = 38.0
		style.bg_color = Color(1, 1, 1, 0.85)
		style.border_color = Color(0, 0, 0, 0.10)
		style.set_border_width_all(1)
		node.add_theme_stylebox_override("panel", style)

	elif node is Label:
		_theme_label(node)

	elif node is Button and node != sound_toggle and node != tts_toggle and node != reset_button:
		var btn := node as Button
		btn.add_theme_color_override("font_color", Global.get_theme_color("text"))

	for child in node.get_children():
		_theme_walk(child)


func _theme_label(label: Label) -> void:
	var n: String = label.name
	if n.ends_with("Title"):
		label.add_theme_color_override("font_color", Global.get_theme_color("accent_bright"))
	elif n in ["VersionName", "DevName", "SubName"]:
		label.add_theme_color_override("font_color", Global.get_theme_color("text_dim"))
	else:
		label.add_theme_color_override("font_color", Global.get_theme_color("text"))


func _on_sound_toggled() -> void:
	Global.sound_enabled = not Global.sound_enabled
	Global.save_settings()
	_set_toggle(sound_toggle, Global.sound_enabled)
	if Global.sound_enabled:
		Sfx.click()


func _on_tts_toggled() -> void:
	Global.tts_enabled = not Global.tts_enabled
	Global.save_settings()
	_set_toggle(tts_toggle, Global.tts_enabled)
	# Give instant feedback: speak a sample word when it's turned on.
	if Global.tts_enabled:
		Global.speak_word("Hello")
	Sfx.click()


# ══════════════════════════════════════════════════════════════
#  DATA MANAGEMENT
# ══════════════════════════════════════════════════════════════
func _on_clear_saved_pressed() -> void:
	Sfx.click()
	_confirm(
		"پاک کردن فلش‌کارت‌ها",
		"همه لغات ذخیره‌شده شما پاک خواهد شد. این عمل قابل بازگشت نیست.\nادامه می‌دهید؟",
		func() -> void:
			Global.clear_saved_words()
			_show_toast("فلش‌کارت‌ها پاک شدند ✓")
	)


func _on_clear_review_pressed() -> void:
	Sfx.click()
	_confirm(
		"پاک کردن لایتنر",
		"همه لغات در نوبت مرور (لایتنر) پاک خواهد شد.\nتوجه: با توجه به همگام‌بودن لیست‌ها، لغات ذخیره‌شده (فلش‌کارت‌ها) هم پاک می‌شوند. این عمل قابل بازگشت نیست.\nادامه می‌دهید؟",
		func() -> void:
			Global.clear_review_words()
			_show_toast("نوبت مرور پاک شد ✓")
	)


func _on_reset_pressed() -> void:
	Sfx.click()
	_confirm(
		"بازنشانی کامل",
		"همه پیشرفت شما (فلش‌کارت‌ها، لایتنر، پیشرفت گرامر و ...) برای همیشه حذف خواهد شد.\nآیا مطمئن هستید؟",
		func() -> void:
			Global.reset_all_progress()
			_show_toast("همه داده‌ها بازنشانی شد ✓")
	)


# ══════════════════════════════════════════════════════════════
#  CONFIRM MODAL — a fully custom, big and readable popup
# ══════════════════════════════════════════════════════════════
const ACCENT    := Color(0.545098, 0.360784, 0.964706)
const ACCENT_ON := Color(0.760784, 0.611765, 1)
const FONT_PATH := "res://assets/fonts/Vazirmatn-Regular.ttf"


func _build_confirm_dialog() -> void:
	var font: Font = load(FONT_PATH)

	# Full-screen wrapper that catches taps so nothing behind it is clickable.
	_modal_root = Control.new()
	_modal_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_root.visible = false
	add_child(_modal_root)

	# Dimmed backdrop so the page behind is clearly masked.
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.6)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_root.add_child(_dim)

	# Centered card via a margin wrapper.
	var center_wrap := MarginContainer.new()
	center_wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_wrap.add_theme_constant_override("margin_left", 90)
	center_wrap.add_theme_constant_override("margin_top", 240)
	center_wrap.add_theme_constant_override("margin_right", 90)
	center_wrap.add_theme_constant_override("margin_bottom", 240)
	_modal_root.add_child(center_wrap)

	_confirm_card = PanelContainer.new()
	_confirm_card.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.02, 0.03, 0.10, 1.0)
	panel.border_width_left = 4
	panel.border_width_top = 4
	panel.border_width_right = 4
	panel.border_width_bottom = 4
	panel.border_color = ACCENT
	panel.set_corner_radius_all(28)
	panel.shadow_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.45)
	panel.shadow_size = 30
	panel.shadow_offset = Vector2.ZERO
	panel.content_margin_left = 56
	panel.content_margin_top = 56
	panel.content_margin_right = 56
	panel.content_margin_bottom = 52
	_confirm_card.add_theme_stylebox_override("panel", panel)
	center_wrap.add_child(_confirm_card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 34)
	_confirm_card.add_child(vbox)

	# Title — big, accent-tinted.
	_confirm_title = Label.new()
	_confirm_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_title.add_theme_font_override("font", font)
	_confirm_title.add_theme_font_size_override("font_size", 46)
	_confirm_title.add_theme_color_override("font_color", ACCENT_ON)
	_confirm_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	_confirm_title.add_theme_constant_override("outline_size", 8)
	vbox.add_child(_confirm_title)

	# Message — large and readable.
	_confirm_message = Label.new()
	_confirm_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_message.add_theme_font_override("font", font)
	_confirm_message.add_theme_font_size_override("font_size", 38)
	_confirm_message.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98))
	_confirm_message.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.4))
	_confirm_message.add_theme_constant_override("outline_size", 6)
	vbox.add_child(_confirm_message)

	# Buttons — large, clear.
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 40)
	vbox.add_child(buttons)

	_confirm_ok = Button.new()
	_confirm_ok.custom_minimum_size = Vector2(270, 100)
	_confirm_ok.text = "تایید"
	_confirm_ok.add_theme_font_override("font", font)
	_confirm_ok.add_theme_font_size_override("font_size", 36)
	_style_dialog_button(_confirm_ok, ACCENT)
	_confirm_ok.pressed.connect(_on_confirm_accepted)
	buttons.add_child(_confirm_ok)

	_confirm_cancel = Button.new()
	_confirm_cancel.custom_minimum_size = Vector2(270, 100)
	_confirm_cancel.text = "انصراف"
	_confirm_cancel.add_theme_font_override("font", font)
	_confirm_cancel.add_theme_font_size_override("font_size", 36)
	_style_dialog_button(_confirm_cancel, Color(1, 1, 1, 0.14))
	_confirm_cancel.pressed.connect(_close_confirm)
	buttons.add_child(_confirm_cancel)


func _style_dialog_button(btn: Button, bg_col: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg_col
	normal.border_color = bg_col.lightened(0.25)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(20)
	normal.content_margin_left = 34
	normal.content_margin_top = 22
	normal.content_margin_right = 34
	normal.content_margin_bottom = 22

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = bg_col.lightened(0.12)
	hover.shadow_color = Color(bg_col.r, bg_col.g, bg_col.b, 0.5)
	hover.shadow_size = 14
	hover.shadow_offset = Vector2.ZERO

	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = bg_col.darkened(0.12)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", normal)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)


func _confirm(title: String, message: String, action: Callable) -> void:
	_pending_action = action
	_confirm_title.text = title
	_confirm_message.text = message
	_confirm_ok.disabled = false

	_modal_root.visible = true
	_confirm_card.scale = Vector2(0.86, 0.86)
	_confirm_card.pivot_offset = _confirm_card.size / 2.0
	_confirm_card.modulate.a = 0.0
	_dim.modulate.a = 0.0

	var tw := create_tween().set_parallel(true)
	tw.tween_property(_dim, "modulate:a", 1.0, 0.25)
	tw.tween_property(_confirm_card, "modulate:a", 1.0, 0.28)
	tw.tween_property(_confirm_card, "scale", Vector2.ONE, 0.34) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _close_confirm() -> void:
	_pending_action = Callable()
	_modal_root.visible = false


func _on_confirm_accepted() -> void:
	if _pending_action.is_valid():
		_pending_action.call()
	_pending_action = Callable()
	_modal_root.visible = false


# ══════════════════════════════════════════════════════════════
#  ABOUT VALUES
# ══════════════════════════════════════════════════════════════
func _app_version() -> String:
	var v: Variant = ProjectSettings.get_setting("application/config/version", "")
	return str(v) if not str(v).is_empty() else "1.0.0"


func _subscription_text() -> String:
	# Placeholder — the app's purchase flow (Purchase.tscn) manages real state.
	return "نسخه رایگان"


# ══════════════════════════════════════════════════════════════
#  TOAST — a big, prominent confirmation banner
# ══════════════════════════════════════════════════════════════
func _show_toast(text: String) -> void:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.15, 0.97)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = ACCENT_ON
	style.set_corner_radius_all(24)
	style.content_margin_left = 48
	style.content_margin_top = 26
	style.content_margin_right = 48
	style.content_margin_bottom = 26
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	label.add_theme_constant_override("outline_size", 8)
	panel.add_child(label)

	add_child(panel)
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.position.y -= 150
	# `panel.size` is still (0,0) right after add_child — wait one frame so
	# the pivot is centered on the real size, then pop the animation in.
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(panel):
		return
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2(0.82, 0.82)
	panel.modulate.a = 0.0

	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.22)
	tw.parallel().tween_property(panel, "scale", Vector2.ONE, 0.32) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.4)
	tw.tween_property(panel, "modulate:a", 0.0, 0.45)
	tw.tween_callback(panel.queue_free)


# ══════════════════════════════════════════════════════════════
#  ACCOUNT + CONTENT DOWNLOADS (built at runtime)
# ══════════════════════════════════════════════════════════════
const SCENE_AUTH := "res://scenes/auth/Auth.tscn"

var _account_status: Label
var _account_button: Button
var _account_logout_button: Button
var _download_info: Label
var _download_progress_label: Label
var _download_button: Button
var _clear_content_button: Button


func _build_extra_sections() -> void:
	var layout: VBoxContainer = $Scroll/Margin/Layout
	layout.add_child(_build_account_card())
	layout.add_child(_build_downloads_card())
	# Surface account + content downloads at the top of the screen.
	layout.move_child(layout.get_node("AccountCard"), 0)
	layout.move_child(layout.get_node("DownloadsCard"), 1)

	_refresh_account_section()
	_refresh_downloads_section()

	API.logged_in.connect(func(_user: Dictionary) -> void: _refresh_account_section())
	API.logged_out.connect(_refresh_account_section)
	API.subscription_updated.connect(func(_sub: Dictionary) -> void: _refresh_account_section())
	Content.manifest_ready.connect(_refresh_downloads_section)
	Content.download_progress.connect(_on_download_progress)
	Content.download_finished.connect(_on_download_finished)


func _build_account_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "AccountCard"
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	card.add_child(vbox)

	vbox.add_child(_section_title("حساب کاربری"))

	_account_status = _section_body("")
	vbox.add_child(_account_status)

	_account_button = _section_button("ورود / ثبت‌نام")
	_account_button.pressed.connect(_on_account_pressed)
	vbox.add_child(_account_button)

	_account_logout_button = _section_button("خروج از حساب")
	_account_logout_button.pressed.connect(_on_logout_pressed)
	vbox.add_child(_account_logout_button)
	return card


func _build_downloads_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "DownloadsCard"
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	card.add_child(vbox)

	vbox.add_child(_section_title("دانلود محتوا"))

	_download_info = _section_body("")
	vbox.add_child(_download_info)

	_download_progress_label = _section_body("")
	vbox.add_child(_download_progress_label)

	_download_button = _section_button("دانلود همه محتوا")
	_download_button.pressed.connect(_on_download_all_pressed)
	vbox.add_child(_download_button)

	_clear_content_button = _section_button("پاک کردن محتوای دانلودشده")
	_clear_content_button.pressed.connect(_on_clear_content_pressed)
	vbox.add_child(_clear_content_button)
	return card


func _section_title(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", MenuStyle.vazir())
	lbl.add_theme_font_size_override("font_size", 42)
	lbl.add_theme_color_override("font_color", Global.get_theme_color("accent_bright"))
	return lbl


func _section_body(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.add_theme_font_override("font", MenuStyle.vazir())
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.add_theme_color_override("font_color", Global.get_theme_color("text"))
	return lbl


func _section_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 92)
	btn.add_theme_font_override("font", MenuStyle.vazir())
	btn.add_theme_font_size_override("font_size", 34)
	MenuStyle.wire_microinteractions(btn)
	return btn


func _style_extra_buttons() -> void:
	if _account_button == null:
		return
	_style_action_button(_account_button, true)
	_style_action_button(_account_logout_button, false)
	_style_action_button(_download_button, true)
	_style_action_button(_clear_content_button, false)
	if _account_status != null:
		_account_status.add_theme_color_override("font_color", Global.get_theme_color("text"))
	if _download_info != null:
		_download_info.add_theme_color_override("font_color", Global.get_theme_color("text_dim"))
	if _download_progress_label != null:
		_download_progress_label.add_theme_color_override("font_color", Global.get_theme_color("text_dim"))


func _style_action_button(btn: Button, primary: bool) -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(18)
	style.content_margin_left = 26.0
	style.content_margin_top = 20.0
	style.content_margin_right = 26.0
	style.content_margin_bottom = 20.0
	if primary:
		style.bg_color = Global.get_theme_color("accent")
		style.border_color = Global.get_theme_color("accent_bright")
		style.set_border_width_all(2)
		btn.add_theme_color_override("font_color", Global.get_theme_color("on_accent"))
	else:
		style.bg_color = Global.get_theme_color("surface_alt")
		style.border_color = Global.get_theme_color("border")
		style.set_border_width_all(1)
		btn.add_theme_color_override("font_color", Global.get_theme_color("text"))
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("focus", style)


func _refresh_account_section() -> void:
	if _account_status == null:
		return
	if API.is_logged_in():
		var phone := MenuStyle.persian_digits(API.get_phone())
		var tier := str(API.get_subscription().get("tier", "free"))
		var tier_fa := "ویژه" if tier != "free" else "رایگان"
		_account_status.text = "شماره: %s\nوضعیت اشتراک: %s" % [phone, tier_fa]
		_account_button.visible = false
		_account_logout_button.visible = true
	else:
		_account_status.text = "برای همگام‌سازی پیشرفت و دانلود محتوا با شماره موبایل وارد شوید."
		_account_button.visible = true
		_account_logout_button.visible = false


func _refresh_downloads_section() -> void:
	if _download_info == null:
		return
	var size_text := MenuStyle.persian_digits(_format_mb(Content.total_downloaded_bytes()))
	if Content.has_manifest():
		_download_info.text = "حجم دانلودشده: %s" % size_text
	else:
		_download_info.text = "حجم دانلودشده: %s\n(برای دانلود، وارد حساب شوید)" % size_text


func _format_mb(bytes: int) -> String:
	if bytes < 1048576:
		return "%d کیلوبایت" % int(bytes / 1024.0)
	return "%.1f مگابایت" % (float(bytes) / 1048576.0)


func _on_account_pressed() -> void:
	Sfx.click()
	TransitionManager.change_scene(SCENE_AUTH)


func _on_logout_pressed() -> void:
	Sfx.click()
	_confirm(
		"خروج از حساب",
		"از حساب خود خارج می‌شوید. پیشرفت محلی حفظ می‌شود.\nادامه می‌دهید؟",
		func() -> void:
			API.logout()
			_show_toast("از حساب خارج شدید ✓")
	)


func _on_download_all_pressed() -> void:
	Sfx.click()
	if not API.is_logged_in():
		_show_toast("ابتدا وارد حساب شوید تا محتوا دانلود شود")
		return
	_download_button.disabled = true
	_download_progress_label.text = "در حال آماده‌سازی دانلود…"
	Content.download_all()


func _on_clear_content_pressed() -> void:
	Sfx.click()
	_confirm(
		"پاک کردن محتوای دانلودشده",
		"همه فایل‌های صوتی و تصویری دانلودشده حذف می‌شوند.\nبا باز کردن هر درس دوباره دانلود خواهند شد. ادامه می‌دهید؟",
		func() -> void:
			Content.clear_downloads()
			_refresh_downloads_section()
			_download_progress_label.text = ""
			_show_toast("محتوای دانلودشده پاک شد ✓")
	)


func _on_download_progress(done_count: int, total_count: int, done_bytes: int, total_bytes: int) -> void:
	if _download_progress_label == null:
		return
	if total_count == 0:
		return
	_download_progress_label.text = "دانلود %d از %d فایل  (%s از %s)" % [
		done_count, total_count,
		MenuStyle.persian_digits(_format_mb(done_bytes)),
		MenuStyle.persian_digits(_format_mb(total_bytes)),
	]


func _on_download_finished(success: bool) -> void:
	if _download_button == null:
		return
	_download_button.disabled = false
	_download_progress_label.text = "دانلود کامل شد ✓" if success else "دانلود با خطا مواجه شد — دوباره تلاش کنید."
	_refresh_downloads_section()


# ══════════════════════════════════════════════════════════════
#  NAVIGATION
# ══════════════════════════════════════════════════════════════
func _on_android_back_pressed() -> void:
	Sfx.click()
	TransitionManager.change_scene("res://scenes/main_menu/MainMenu.tscn")
