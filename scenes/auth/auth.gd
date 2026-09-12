extends "res://autoload/BackButtonHandler.gd"

# ============================================================
#  AUTH — phone + OTP sign-in.
#  Step 1: enter the phone number  →  API.request_otp()
#  Step 2: enter the SMS code      →  API.verify_otp()
#  The UI is built in code (like Purchase) so the scene file stays tiny and
#  the whole screen re-themes with the app's Dark / Light palette.
# ============================================================

const SCENE_MAIN_MENU := "res://scenes/main_menu/MainMenu.tscn"
const SCENE_SETTINGS  := "res://scenes/settings/Settings.tscn"

const COLOR_ACCENT := Color("#8B5CF6")
const COLOR_OK     := Color("#10B981")
const COLOR_ERR    := Color("#EF4444")

var _phone_edit: LineEdit
var _code_edit: LineEdit
var _status_label: Label
var _send_button: Button
var _verify_button: Button
var _resend_button: Button
var _change_button: Button
var _phone_step: VBoxContainer
var _code_step: VBoxContainer

var _phone: String = ""
var _resend_cooldown: float = 0.0
var _busy: bool = false


func _ready() -> void:
	_build_ui()
	_apply_theme()
	Global.on_theme_changed(_on_theme_changed)
	set_process(true)


func _process(delta: float) -> void:
	if _resend_cooldown > 0.0:
		_resend_cooldown = maxf(0.0, _resend_cooldown - delta)
		if _resend_button != null and _resend_button.visible:
			_resend_button.disabled = _resend_cooldown > 0.0
			_resend_button.text = "ارسال دوباره کد (%d)" % int(ceil(_resend_cooldown))
			_resend_button.text = MenuStyle.persian_digits(_resend_button.text)


# ══════════════════════════════════════════════════════════════
#  UI
# ══════════════════════════════════════════════════════════════
func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.name = "Bg"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# ---- Header bar ----
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

	var back := MenuStyle.make_back_button("res://images/Back.png", 132)
	# Name it "BackButton": Global.style_header maps header buttons to their
	# icon by node name, and an unnamed button would have its icon cleared.
	back.name = "BackButton"
	back.pressed.connect(_on_back_pressed)
	MenuStyle.wire_microinteractions(back)
	h_row.add_child(back)

	var title := Label.new()
	title.name = "HeaderTitle"
	title.text = "حساب کاربری"
	title.add_theme_font_override("font", MenuStyle.vazir())
	title.add_theme_font_size_override("font_size", 46)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h_row.add_child(title)

	# ---- Centered card ----
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_top = 220.0
	add_child(center)

	var card := PanelContainer.new()
	card.name = "AuthCard"
	card.custom_minimum_size = Vector2(880, 0)
	center.add_child(card)

	var card_margin := MarginContainer.new()
	for side in ["left", "right"]:
		card_margin.add_theme_constant_override("margin_" + side, 48)
	for side in ["top", "bottom"]:
		card_margin.add_theme_constant_override("margin_" + side, 56)
	card.add_child(card_margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 30)
	card_margin.add_child(col)

	var heading := Label.new()
	heading.name = "CardHeading"
	heading.text = "ورود با شماره موبایل"
	heading.add_theme_font_override("font", MenuStyle.vazir())
	heading.add_theme_font_size_override("font_size", 42)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(heading)

	_phone_step = _build_phone_step()
	col.add_child(_phone_step)

	_code_step = _build_code_step()
	_code_step.visible = false
	col.add_child(_code_step)

	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_override("font", MenuStyle.vazir())
	_status_label.add_theme_font_size_override("font_size", 30)
	col.add_child(_status_label)


func _build_phone_step() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)

	var hint := _make_hint("شماره موبایل خود را وارد کنید. یک کد تأیید برایتان پیامک می‌شود.")

	_phone_edit = LineEdit.new()
	_phone_edit.name = "PhoneEdit"
	_phone_edit.placeholder_text = "۰۹۱۲۳۴۵۶۷۸۹"
	_phone_edit.max_length = 13
	_phone_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phone_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PHONE
	_phone_edit.add_theme_font_override("font", MenuStyle.vazir())
	_phone_edit.add_theme_font_size_override("font_size", 40)
	_phone_edit.custom_minimum_size = Vector2(0, 96)

	_send_button = _make_primary_button("ارسال کد")
	_send_button.pressed.connect(_on_send_pressed)

	box.add_child(hint)
	box.add_child(_phone_edit)
	box.add_child(_send_button)
	return box


func _build_code_step() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)

	var hint := _make_hint("کد ارسال‌شده را وارد کنید.")

	_code_edit = LineEdit.new()
	_code_edit.name = "CodeEdit"
	_code_edit.placeholder_text = "کد ۵ رقمی"
	_code_edit.max_length = 6
	_code_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	_code_edit.add_theme_font_override("font", MenuStyle.vazir())
	_code_edit.add_theme_font_size_override("font_size", 46)
	_code_edit.custom_minimum_size = Vector2(0, 96)

	_verify_button = _make_primary_button("تأیید و ورود")
	_verify_button.pressed.connect(_on_verify_pressed)

	_resend_button = _make_secondary_button("ارسال دوباره کد")
	_resend_button.pressed.connect(_on_resend_pressed)

	_change_button = _make_secondary_button("تغییر شماره")
	_change_button.pressed.connect(_on_change_number_pressed)

	box.add_child(hint)
	box.add_child(_code_edit)
	box.add_child(_verify_button)
	box.add_child(_resend_button)
	box.add_child(_change_button)
	return box


func _make_hint(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", MenuStyle.vazir())
	lbl.add_theme_font_size_override("font_size", 28)
	return lbl


func _make_primary_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 100)
	btn.add_theme_font_override("font", MenuStyle.vazir())
	btn.add_theme_font_size_override("font_size", 36)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(20)
	style.bg_color = COLOR_ACCENT
	style.set_content_margin_all(18)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("focus", style)
	MenuStyle.wire_microinteractions(btn)
	return btn


func _make_secondary_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 88)
	btn.add_theme_font_override("font", MenuStyle.vazir())
	btn.add_theme_font_size_override("font_size", 32)
	MenuStyle.wire_microinteractions(btn)
	return btn


# ══════════════════════════════════════════════════════════════
#  THEME
# ══════════════════════════════════════════════════════════════
func _on_theme_changed(_mode: int) -> void:
	_apply_theme()


func _apply_theme() -> void:
	if not is_inside_tree():
		return
	var bg: ColorRect = get_node_or_null("Bg")
	if bg != null:
		bg.color = Global.get_theme_color("bg")

	var card: PanelContainer = get_node_or_null("CenterContainer/AuthCard")
	if card != null:
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(28)
		style.content_margin_left = 48
		style.content_margin_right = 48
		style.content_margin_top = 56
		style.content_margin_bottom = 56
		style.bg_color = Global.get_theme_color("surface")
		style.border_color = Global.get_theme_color("border")
		style.set_border_width_all(1)
		card.add_theme_stylebox_override("panel", style)

	var heading: Label = get_node_or_null("CenterContainer/AuthCard/MarginContainer/VBoxContainer/CardHeading")
	if heading != null:
		heading.add_theme_color_override("font_color", Global.get_theme_color("accent_bright"))

	if _status_label != null:
		_status_label.add_theme_color_override("font_color", Global.get_theme_color("text_dim"))

	if has_node("HeaderBar"):
		Global.style_header($HeaderBar)


func _set_status(message: String, color: Color) -> void:
	if _status_label == null:
		return
	_status_label.text = message
	_status_label.add_theme_color_override("font_color", color)


# ══════════════════════════════════════════════════════════════
#  FLOW
# ══════════════════════════════════════════════════════════════
func _on_send_pressed() -> void:
	if _busy:
		return
	var phone := _phone_edit.text.strip_edges()
	if phone.length() < 10:
		_set_status("شماره موبایل معتبر وارد کنید.", COLOR_ERR)
		return
	_phone = phone
	_busy = true
	_send_button.disabled = true
	_set_status("در حال ارسال کد…", Global.get_theme_color("text_dim"))
	API.request_otp(phone, _on_otp_requested)


func _on_otp_requested(ok: bool, error: String, retry_after: int) -> void:
	_busy = false
	_send_button.disabled = false
	if not ok:
		_set_status(_error_message(error, retry_after), COLOR_ERR)
		return
	_phone_step.visible = false
	_code_step.visible = true
	_code_edit.text = ""
	_code_edit.grab_focus()
	_start_resend_cooldown(60.0)
	_set_status("کد تأیید پیامک شد.", COLOR_OK)


func _on_verify_pressed() -> void:
	if _busy:
		return
	var code := _code_edit.text.strip_edges()
	if code.length() < 4:
		_set_status("کد را کامل وارد کنید.", COLOR_ERR)
		return
	_busy = true
	_verify_button.disabled = true
	_set_status("در حال بررسی کد…", Global.get_theme_color("text_dim"))
	API.verify_otp(_phone, code, _on_otp_verified)


func _on_otp_verified(ok: bool, error: String) -> void:
	_busy = false
	_verify_button.disabled = false
	if not ok:
		_set_status(_error_message(error, 0), COLOR_ERR)
		return
	_set_status("خوش آمدید! پیشرفت شما همگام‌سازی می‌شود…", COLOR_OK)
	await get_tree().create_timer(0.6).timeout
	TransitionManager.change_scene(SCENE_SETTINGS)


func _on_resend_pressed() -> void:
	if _busy or _resend_cooldown > 0.0:
		return
	_busy = true
	_resend_button.disabled = true
	API.request_otp(_phone, func(ok: bool, error: String, retry_after: int) -> void:
		_busy = false
		if ok:
			_start_resend_cooldown(60.0)
			_set_status("کد جدید پیامک شد.", COLOR_OK)
		else:
			_resend_button.disabled = false
			_set_status(_error_message(error, retry_after), COLOR_ERR))


func _on_change_number_pressed() -> void:
	_code_step.visible = false
	_phone_step.visible = true
	_resend_cooldown = 0.0
	_set_status("", Global.get_theme_color("text_dim"))


func _start_resend_cooldown(seconds: float) -> void:
	_resend_cooldown = seconds
	_resend_button.visible = true


func _error_message(error: String, retry_after: int) -> String:
	match error:
		"invalid_phone", "invalid_input":
			return "شماره موبایل معتبر نیست."
		"too_many_requests":
			return "لطفاً %d ثانیه دیگر دوباره تلاش کنید." % retry_after
		"sms_failed":
			return "ارسال پیامک ناموفق بود. دوباره تلاش کنید."
		"no_code":
			return "کدی برای این شماره ارسال نشده است."
		"expired":
			return "کد منقضی شده است. کد جدید بگیرید."
		"too_many_attempts":
			return "تلاش‌های بیش از حد. کد جدید بگیرید."
		"invalid_code":
			return "کد وارد‌شده صحیح نیست."
		"no_base_url":
			return "اتصال به سرور تنظیم نشده است."
		_:
			return "خطا در ارتباط با سرور. دوباره تلاش کنید."


# ══════════════════════════════════════════════════════════════
#  NAVIGATION
# ══════════════════════════════════════════════════════════════
func _on_back_pressed() -> void:
	Sfx.click()
	TransitionManager.change_scene(SCENE_MAIN_MENU)


func _on_android_back_pressed() -> void:
	_on_back_pressed()
