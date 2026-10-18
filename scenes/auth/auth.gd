extends "res://autoload/BackButtonHandler.gd"

# ============================================================
#  AUTH — phone + OTP sign-in.
#  Step 1: enter the phone number  →  API.request_otp()
#  Step 2: enter the SMS code      →  API.verify_otp()
#  The UI is built in code (like Purchase) so the scene file stays tiny and
#  the whole screen re-themes with the app's Dark / Light palette.
# ============================================================

const SCENE_SETTINGS  := "res://scenes/settings/Settings.tscn"

const COLOR_ACCENT := DesignTokens.ACCENT
const COLOR_OK     := Color("#10B981")
const COLOR_ERR    := Color("#EF4444")

@onready var _phone_edit: LineEdit = $CenterContainer/AuthCard/CardMargin/VBoxContainer/PhoneStep/PhoneEdit
@onready var _code_edit: LineEdit = $CenterContainer/AuthCard/CardMargin/VBoxContainer/CodeStep/CodeEdit
@onready var _status_label: Label = $CenterContainer/AuthCard/CardMargin/VBoxContainer/StatusLabel
@onready var _send_button: Button = $CenterContainer/AuthCard/CardMargin/VBoxContainer/PhoneStep/SendButton
@onready var _verify_button: Button = $CenterContainer/AuthCard/CardMargin/VBoxContainer/CodeStep/VerifyButton
@onready var _resend_button: Button = $CenterContainer/AuthCard/CardMargin/VBoxContainer/CodeStep/ResendButton
@onready var _change_button: Button = $CenterContainer/AuthCard/CardMargin/VBoxContainer/CodeStep/ChangeButton
@onready var _phone_step: VBoxContainer = $CenterContainer/AuthCard/CardMargin/VBoxContainer/PhoneStep
@onready var _code_step: VBoxContainer = $CenterContainer/AuthCard/CardMargin/VBoxContainer/CodeStep

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
	_phone_edit.placeholder_text = "۰۹۱۲۳۴۵۶۷۸۹"
	_phone_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PHONE
	_phone_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phone_edit.add_theme_font_override("font", MenuStyle.vazir())
	_phone_edit.add_theme_font_size_override("font_size", 40)
	_code_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	_code_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code_edit.add_theme_font_override("font", MenuStyle.vazir())
	_code_edit.add_theme_font_size_override("font_size", 46)
	_send_button.pressed.connect(_on_send_pressed)
	_verify_button.pressed.connect(_on_verify_pressed)
	_resend_button.pressed.connect(_on_resend_pressed)
	_change_button.pressed.connect(_on_change_number_pressed)
	_resend_button.visible = false
	_status_label.add_theme_font_override("font", MenuStyle.vazir())
	_status_label.add_theme_font_size_override("font_size", 30)
	var phone_hint: Label = _phone_step.get_node("PhoneHint") as Label
	phone_hint.add_theme_font_override("font", MenuStyle.vazir())
	phone_hint.add_theme_font_size_override("font_size", 28)
	var code_hint: Label = _code_step.get_node("CodeHint") as Label
	code_hint.add_theme_font_override("font", MenuStyle.vazir())
	code_hint.add_theme_font_size_override("font_size", 28)
	_apply_button_layout(_send_button, 36, true)
	_apply_button_layout(_verify_button, 36, true)
	_apply_button_layout(_resend_button, 32, false)
	_apply_button_layout(_change_button, 32, false)
	var side_menu: Node = get_node_or_null("SideMenu")
	if side_menu != null and side_menu.has_method("set_hamburger_button"):
		var hamburger: Button = get_node_or_null("HamburgerButton") as Button
		if hamburger != null:
			side_menu.set_hamburger_button(hamburger)
			hamburger.pressed.connect(side_menu.toggle)
			MenuStyle.style_button(hamburger, "secondary")
			MenuStyle.wire_microinteractions(hamburger)


func _apply_button_layout(button: Button, font_size: int, primary: bool) -> void:
	button.add_theme_font_override("font", MenuStyle.vazir())
	button.add_theme_font_size_override("font_size", font_size)
	if primary:
		button.add_theme_color_override("font_color", Color.WHITE)
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_color_override("font_pressed_color", Color.WHITE)
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(20)
		style.bg_color = COLOR_ACCENT
		style.set_content_margin_all(18)
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
		button.add_theme_stylebox_override("pressed", style)
		button.add_theme_stylebox_override("focus", style)
	MenuStyle.wire_microinteractions(button)


# ══════════════════════════════════════════════════════════════
#  THEME
# ══════════════════════════════════════════════════════════════
func _on_theme_changed(_mode: int) -> void:
	_apply_theme()


func _apply_theme() -> void:
	if not is_inside_tree():
		return
	var bg: ColorRect = $Background
	bg.color = Global.get_theme_color("bg")

	var card: PanelContainer = $CenterContainer/AuthCard
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

	var heading: Label = $CenterContainer/AuthCard/CardMargin/VBoxContainer/CardHeading
	if heading != null:
		heading.add_theme_color_override("font_color", Global.get_theme_color("accent_bright"))

	if _status_label != null:
		_status_label.add_theme_color_override("font_color", Global.get_theme_color("text_dim"))



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
func _on_android_back_pressed() -> void:
	Sfx.click()
	TransitionManager.change_scene("res://scenes/main_menu/MainMenu.tscn")
