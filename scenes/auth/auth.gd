extends "res://autoload/BackButtonHandler.gd"

# ============================================================
#  AUTH — Account Authentication & Management
#  Supports:
#    * Sign In with Username / Phone + Password
#    * Sign Up via Phone OTP -> Username, Password (twice), School Grade (10, 11, 12)
#    * Password Recovery via Phone OTP -> Set New Password (twice)
#    * Logged-in profile view & logout
# ============================================================

enum Mode {
	LOGGED_IN,
	SIGN_IN,
	SIGNUP_PHONE,
	SIGNUP_OTP,
	SIGNUP_PROFILE,
	FORGOT_PHONE,
	FORGOT_OTP,
	FORGOT_NEW_PASS,
}

const SCENE_SETTINGS := "res://scenes/settings/Settings.tscn"
const SCENE_MAIN_MENU := "res://scenes/main_menu/MainMenu.tscn"

const COLOR_ACCENT := DesignTokens.ACCENT
const COLOR_OK     := Color("#10B981")
const COLOR_ERR    := Color("#EF4444")

# UI node references
@onready var _card_heading: Label = $Scroll/ScrollMargin/CenterBox/AuthCard/CardMargin/VBoxContainer/CardHeading
@onready var _card_subtitle: Label = $Scroll/ScrollMargin/CenterBox/AuthCard/CardMargin/VBoxContainer/CardSubtitle
@onready var _status_label: Label = $Scroll/ScrollMargin/CenterBox/AuthCard/CardMargin/VBoxContainer/StatusLabel

# View containers
@onready var _signin_view: VBoxContainer = $Scroll/ScrollMargin/CenterBox/AuthCard/CardMargin/VBoxContainer/SignInView
@onready var _phone_step_view: VBoxContainer = $Scroll/ScrollMargin/CenterBox/AuthCard/CardMargin/VBoxContainer/PhoneStepView
@onready var _otp_step_view: VBoxContainer = $Scroll/ScrollMargin/CenterBox/AuthCard/CardMargin/VBoxContainer/OtpStepView
@onready var _register_view: VBoxContainer = $Scroll/ScrollMargin/CenterBox/AuthCard/CardMargin/VBoxContainer/RegisterFormView
@onready var _reset_pass_view: VBoxContainer = $Scroll/ScrollMargin/CenterBox/AuthCard/CardMargin/VBoxContainer/ResetPassView
@onready var _logged_in_view: VBoxContainer = $Scroll/ScrollMargin/CenterBox/AuthCard/CardMargin/VBoxContainer/LoggedInView

# Sign In Controls
@onready var _login_user_edit: LineEdit = _signin_view.get_node("LoginUserEdit") as LineEdit
@onready var _login_pass_edit: LineEdit = _signin_view.get_node("LoginPassEdit") as LineEdit
@onready var _login_button: Button = _signin_view.get_node("LoginButton") as Button
@onready var _to_signup_button: Button = _signin_view.get_node("ToSignupButton") as Button
@onready var _to_forgot_button: Button = _signin_view.get_node("ToForgotButton") as Button

# Phone Step Controls
@onready var _phone_hint: Label = _phone_step_view.get_node("PhoneHint") as Label
@onready var _phone_edit: LineEdit = _phone_step_view.get_node("PhoneEdit") as LineEdit
@onready var _send_otp_button: Button = _phone_step_view.get_node("SendOtpButton") as Button
@onready var _phone_cancel_button: Button = _phone_step_view.get_node("PhoneCancelButton") as Button

# OTP Step Controls
@onready var _otp_hint: Label = _otp_step_view.get_node("OtpHint") as Label
@onready var _otp_edit: LineEdit = _otp_step_view.get_node("OtpEdit") as LineEdit
@onready var _verify_otp_button: Button = _otp_step_view.get_node("VerifyOtpButton") as Button
@onready var _resend_otp_button: Button = _otp_step_view.get_node("ResendOtpButton") as Button
@onready var _change_phone_button: Button = _otp_step_view.get_node("ChangePhoneButton") as Button

# Register Form Controls
@onready var _reg_hint: Label = _register_view.get_node("RegHint") as Label
@onready var _reg_user_edit: LineEdit = _register_view.get_node("RegUserEdit") as LineEdit
@onready var _reg_pass_edit: LineEdit = _register_view.get_node("RegPassEdit") as LineEdit
@onready var _reg_pass_confirm_edit: LineEdit = _register_view.get_node("RegPassConfirmEdit") as LineEdit
@onready var _grade_label: Label = _register_view.get_node("GradeSection/GradeLabel") as Label
@onready var _grade_10_btn: Button = _register_view.get_node("GradeSection/GradeButtonsBox/Grade10Button") as Button
@onready var _grade_11_btn: Button = _register_view.get_node("GradeSection/GradeButtonsBox/Grade11Button") as Button
@onready var _grade_12_btn: Button = _register_view.get_node("GradeSection/GradeButtonsBox/Grade12Button") as Button
@onready var _submit_reg_button: Button = _register_view.get_node("SubmitRegisterButton") as Button
@onready var _cancel_reg_button: Button = _register_view.get_node("CancelRegisterButton") as Button

# Reset Password Controls
@onready var _reset_hint: Label = _reset_pass_view.get_node("ResetHint") as Label
@onready var _new_pass_edit: LineEdit = _reset_pass_view.get_node("NewPassEdit") as LineEdit
@onready var _confirm_pass_edit: LineEdit = _reset_pass_view.get_node("ConfirmPassEdit") as LineEdit
@onready var _submit_reset_button: Button = _reset_pass_view.get_node("SubmitResetButton") as Button
@onready var _cancel_reset_button: Button = _reset_pass_view.get_node("CancelResetButton") as Button

# Logged In Controls
@onready var _profile_info_label: Label = _logged_in_view.get_node("ProfileInfoLabel") as Label
@onready var _logout_button: Button = _logged_in_view.get_node("LogoutButton") as Button

# State variables
var _current_mode: Mode = Mode.SIGN_IN
var _phone: String = ""
var _signup_token: String = ""
var _reset_token: String = ""
var _selected_grade: int = 10
var _resend_cooldown: float = 0.0
var _busy: bool = false


func _ready() -> void:
	wire_header_bar()
	_setup_controls()
	_apply_theme()
	Global.on_theme_changed(_on_theme_changed)

	if API.is_logged_in():
		_switch_mode(Mode.LOGGED_IN)
	else:
		_switch_mode(Mode.SIGN_IN)

	set_process(true)


func _process(delta: float) -> void:
	if _resend_cooldown > 0.0:
		_resend_cooldown = maxf(0.0, _resend_cooldown - delta)
		if _resend_otp_button != null and _resend_otp_button.visible:
			_resend_otp_button.disabled = _resend_cooldown > 0.0
			var seconds_left := int(ceil(_resend_cooldown))
			_resend_otp_button.text = "ارسال دوباره کد (%d)" % seconds_left
			_resend_otp_button.text = MenuStyle.persian_digits(_resend_otp_button.text)
		elif _resend_otp_button != null:
			_resend_otp_button.disabled = false
			_resend_otp_button.text = "ارسال دوباره کد"


# ══════════════════════════════════════════════════════════════
#  SETUP & UI CONFIGURATION
# ══════════════════════════════════════════════════════════════

func _setup_controls() -> void:
	# Fonts and placeholders for LineEdits
	var edits: Array[LineEdit] = [
		_login_user_edit,
		_login_pass_edit,
		_phone_edit,
		_otp_edit,
		_reg_user_edit,
		_reg_pass_edit,
		_reg_pass_confirm_edit,
		_new_pass_edit,
		_confirm_pass_edit
	]
	for edit in edits:
		if edit != null:
			edit.add_theme_font_override("font", MenuStyle.vazir())
			edit.add_theme_font_size_override("font_size", 34)

	_phone_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PHONE
	_otp_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	_otp_edit.add_theme_font_size_override("font_size", 42)

	# Labels
	var labels: Array[Label] = [
		_card_heading,
		_card_subtitle,
		_status_label,
		_phone_hint,
		_otp_hint,
		_reg_hint,
		_grade_label,
		_reset_hint,
		_profile_info_label
	]
	for lbl in labels:
		if lbl != null:
			lbl.add_theme_font_override("font", MenuStyle.vazir())

	# Button Layouts & Microinteractions
	_apply_button_layout(_login_button, 36, true)
	_apply_button_layout(_send_otp_button, 36, true)
	_apply_button_layout(_verify_otp_button, 36, true)
	_apply_button_layout(_submit_reg_button, 36, true)
	_apply_button_layout(_submit_reset_button, 36, true)
	_apply_button_layout(_logout_button, 34, false)

	_apply_button_layout(_to_signup_button, 30, false)
	_apply_button_layout(_to_forgot_button, 28, false)
	_apply_button_layout(_phone_cancel_button, 30, false)
	_apply_button_layout(_resend_otp_button, 30, false)
	_apply_button_layout(_change_phone_button, 30, false)
	_apply_button_layout(_cancel_reg_button, 30, false)
	_apply_button_layout(_cancel_reset_button, 30, false)

	# Connect signals
	_login_button.pressed.connect(_on_login_pressed)
	_to_signup_button.pressed.connect(func() -> void: _switch_mode(Mode.SIGNUP_PHONE))
	_to_forgot_button.pressed.connect(func() -> void: _switch_mode(Mode.FORGOT_PHONE))

	_send_otp_button.pressed.connect(_on_send_otp_pressed)
	_phone_cancel_button.pressed.connect(func() -> void: _switch_mode(Mode.SIGN_IN))

	_verify_otp_button.pressed.connect(_on_verify_otp_pressed)
	_resend_otp_button.pressed.connect(_on_resend_otp_pressed)
	_change_phone_button.pressed.connect(_on_change_phone_pressed)

	_grade_10_btn.pressed.connect(func() -> void: _select_grade(10))
	_grade_11_btn.pressed.connect(func() -> void: _select_grade(11))
	_grade_12_btn.pressed.connect(func() -> void: _select_grade(12))

	_submit_reg_button.pressed.connect(_on_register_pressed)
	_cancel_reg_button.pressed.connect(func() -> void: _switch_mode(Mode.SIGN_IN))

	_submit_reset_button.pressed.connect(_on_reset_password_pressed)
	_cancel_reset_button.pressed.connect(func() -> void: _switch_mode(Mode.SIGN_IN))

	_logout_button.pressed.connect(_on_logout_pressed)

	_update_grade_buttons_ui()


func _apply_button_layout(button: Button, font_size: int, primary: bool) -> void:
	if button == null:
		return
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
#  MODE SWITCHING & VIEW CHOREOGRAPHY
# ══════════════════════════════════════════════════════════════

func _switch_mode(new_mode: Mode) -> void:
	_current_mode = new_mode
	_set_status("", Global.get_theme_color("text_dim"))

	# Hide all views first
	_signin_view.visible = false
	_phone_step_view.visible = false
	_otp_step_view.visible = false
	_register_view.visible = false
	_reset_pass_view.visible = false
	_logged_in_view.visible = false

	match _current_mode:
		Mode.LOGGED_IN:
			_card_heading.text = "حساب کاربری"
			_card_subtitle.text = "اطلاعات حساب فعال شما در ویژن مستر"
			_refresh_logged_in_view()
			_logged_in_view.visible = true

		Mode.SIGN_IN:
			_card_heading.text = "ورود به حساب کاربری"
			_card_subtitle.text = "نام کاربری و رمز عبور خود را وارد کنید."
			_signin_view.visible = true
			_login_user_edit.grab_focus()

		Mode.SIGNUP_PHONE:
			_card_heading.text = "ثبت‌نام در برنامه"
			_card_subtitle.text = "شماره موبایل خود را وارد کنید تا کد تأیید ارسال شود."
			_phone_hint.text = "شماره موبایل خود را وارد کنید:"
			_send_otp_button.text = "ارسال کد تأیید"
			_phone_step_view.visible = true
			_phone_edit.grab_focus()

		Mode.SIGNUP_OTP:
			_card_heading.text = "تأیید شماره موبایل"
			_card_subtitle.text = "کد ۵ رقمی پیامک‌شده را وارد کنید."
			_otp_step_view.visible = true
			_otp_edit.text = ""
			_otp_edit.grab_focus()

		Mode.SIGNUP_PROFILE:
			_card_heading.text = "تکمیل ثبت‌نام"
			_card_subtitle.text = "نام کاربری، رمز عبور و پایه تحصیلی خود را مشخص کنید."
			_register_view.visible = true
			_reg_user_edit.grab_focus()

		Mode.FORGOT_PHONE:
			_card_heading.text = "بازیابی رمز عبور"
			_card_subtitle.text = "شماره موبایل حساب خود را وارد کنید."
			_phone_hint.text = "کد بازیابی به شماره موبایل شما پیامک خواهد شد:"
			_send_otp_button.text = "ارسال کد بازیابی"
			_phone_step_view.visible = true
			_phone_edit.grab_focus()

		Mode.FORGOT_OTP:
			_card_heading.text = "تأیید کد بازیابی"
			_card_subtitle.text = "کد ارسال‌شده برای بازیابی رمز عبور را وارد کنید."
			_otp_step_view.visible = true
			_otp_edit.text = ""
			_otp_edit.grab_focus()

		Mode.FORGOT_NEW_PASS:
			_card_heading.text = "تعیین رمز عبور جدید"
			_card_subtitle.text = "رمز عبور جدید خود را ۲ بار وارد کنید."
			_reset_pass_view.visible = true
			_new_pass_edit.text = ""
			_confirm_pass_edit.text = ""
			_new_pass_edit.grab_focus()


func _refresh_logged_in_view() -> void:
	var phone := MenuStyle.persian_digits(API.get_phone())
	var username := API.get_username()
	var grade := API.get_grade()
	var grade_fa := ""
	match grade:
		10: grade_fa = "پایه دهم"
		11: grade_fa = "پایه یازدهم"
		12: grade_fa = "پایه دوازدهم"
		_: grade_fa = "نامشخص"
	var tier := str(API.get_subscription().get("tier", "free"))
	var tier_fa := "ویژه" if tier != "free" else "رایگان"

	var text_lines: Array[String] = []
	if username != "":
		text_lines.append("👤 نام کاربری: %s" % username)
	text_lines.append("📱 شماره موبایل: %s" % phone)
	text_lines.append("🎓 پایه تحصیلی: %s" % grade_fa)
	text_lines.append("💎 نوع اشتراک: %s" % tier_fa)
	_profile_info_label.text = "\n".join(text_lines)


# ══════════════════════════════════════════════════════════════
#  GRADE SELECTOR
# ══════════════════════════════════════════════════════════════

func _select_grade(grade: int) -> void:
	_selected_grade = grade
	_update_grade_buttons_ui()


func _update_grade_buttons_ui() -> void:
	var grade_buttons: Dictionary = {
		10: _grade_10_btn,
		11: _grade_11_btn,
		12: _grade_12_btn
	}

	for grade_val: int in grade_buttons.keys():
		var btn: Button = grade_buttons[grade_val] as Button
		if btn == null:
			continue
		var is_selected: bool = (grade_val == _selected_grade)
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(16)
		style.set_content_margin_all(14)
		if is_selected:
			style.bg_color = COLOR_ACCENT
			style.border_color = COLOR_ACCENT
			style.set_border_width_all(2)
			btn.add_theme_color_override("font_color", Color.WHITE)
			btn.add_theme_color_override("font_hover_color", Color.WHITE)
			btn.add_theme_color_override("font_pressed_color", Color.WHITE)
		else:
			style.bg_color = Global.get_theme_color("surface_raised")
			style.border_color = Global.get_theme_color("border")
			style.set_border_width_all(1)
			var text_color: Color = Global.get_theme_color("text")
			btn.add_theme_color_override("font_color", text_color)
			btn.add_theme_color_override("font_hover_color", text_color)
			btn.add_theme_color_override("font_pressed_color", text_color)

		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)
		btn.add_theme_stylebox_override("focus", style)
		MenuStyle.wire_microinteractions(btn)


# ══════════════════════════════════════════════════════════════
#  ACTIONS & HANDLERS
# ══════════════════════════════════════════════════════════════

# 1. Sign In
func _on_login_pressed() -> void:
	if _busy:
		return
	var identifier := _login_user_edit.text.strip_edges()
	var password := _login_pass_edit.text
	if identifier == "":
		_set_status("لطفاً نام کاربری یا شماره موبایل را وارد کنید.", COLOR_ERR)
		_login_user_edit.grab_focus()
		return
	if password == "":
		_set_status("لطفاً رمز عبور را وارد کنید.", COLOR_ERR)
		_login_pass_edit.grab_focus()
		return

	_busy = true
	_login_button.disabled = true
	_set_status("در حال ورود…", Global.get_theme_color("text_dim"))

	API.login_with_password(identifier, password, func(ok: bool, error: String) -> void:
		_busy = false
		_login_button.disabled = false
		if not ok:
			_set_status(_error_message(error, 0), COLOR_ERR)
			return
		_set_status("خوش آمدید! ورود موفقیت‌آمیز بود.", COLOR_OK)
		await get_tree().create_timer(0.6).timeout
		TransitionManager.change_scene(SCENE_SETTINGS)
	)


# 2. Send OTP (Sign Up & Forgot Password)
func _on_send_otp_pressed() -> void:
	if _busy:
		return
	var phone := _phone_edit.text.strip_edges()
	if phone.length() < 10:
		_set_status("شماره موبایل معتبر وارد کنید.", COLOR_ERR)
		return
	_phone = phone
	_busy = true
	_send_otp_button.disabled = true
	_set_status("در حال ارسال کد…", Global.get_theme_color("text_dim"))

	var intent := "signup" if _current_mode == Mode.SIGNUP_PHONE else "reset"
	API.request_otp(phone, func(ok: bool, error: String, retry_after: int) -> void:
		_busy = false
		_send_otp_button.disabled = false
		if not ok:
			_set_status(_error_message(error, retry_after), COLOR_ERR)
			return
		_start_resend_cooldown(60.0)
		_set_status("کد تأیید پیامک شد.", COLOR_OK)
		if _current_mode == Mode.SIGNUP_PHONE:
			_switch_mode(Mode.SIGNUP_OTP)
		else:
			_switch_mode(Mode.FORGOT_OTP)
	, intent)


# 3. Verify OTP
func _on_verify_otp_pressed() -> void:
	if _busy:
		return
	var code := _otp_edit.text.strip_edges()
	if code.length() < 4:
		_set_status("کد را کامل وارد کنید.", COLOR_ERR)
		return

	_busy = true
	_verify_otp_button.disabled = true
	_set_status("در حال بررسی کد…", Global.get_theme_color("text_dim"))

	if _current_mode == Mode.SIGNUP_OTP:
		API.verify_otp_for_signup(_phone, code, func(ok: bool, signup_token: String, error: String) -> void:
			_busy = false
			_verify_otp_button.disabled = false
			if not ok:
				_set_status(_error_message(error, 0), COLOR_ERR)
				return
			_signup_token = signup_token
			_set_status("شماره تأیید شد. لطفاً اطلاعات حساب را وارد کنید.", COLOR_OK)
			_switch_mode(Mode.SIGNUP_PROFILE)
		)
	else:
		API.verify_otp_for_reset(_phone, code, func(ok: bool, reset_token: String, error: String) -> void:
			_busy = false
			_verify_otp_button.disabled = false
			if not ok:
				_set_status(_error_message(error, 0), COLOR_ERR)
				return
			_reset_token = reset_token
			_set_status("کد تأیید شد. اکنون رمز عبور جدید را تعیین کنید.", COLOR_OK)
			_switch_mode(Mode.FORGOT_NEW_PASS)
		)


# 4. Resend OTP
func _on_resend_otp_pressed() -> void:
	if _busy or _resend_cooldown > 0.0:
		return
	_busy = true
	_resend_otp_button.disabled = true
	var intent := "signup" if _current_mode == Mode.SIGNUP_OTP else "reset"
	API.request_otp(_phone, func(ok: bool, error: String, retry_after: int) -> void:
		_busy = false
		if ok:
			_start_resend_cooldown(60.0)
			_set_status("کد جدید پیامک شد.", COLOR_OK)
		else:
			_resend_otp_button.disabled = false
			_set_status(_error_message(error, retry_after), COLOR_ERR)
	, intent)


func _on_change_phone_pressed() -> void:
	_resend_cooldown = 0.0
	if _current_mode == Mode.SIGNUP_OTP:
		_switch_mode(Mode.SIGNUP_PHONE)
	else:
		_switch_mode(Mode.FORGOT_PHONE)


func _start_resend_cooldown(seconds: float) -> void:
	_resend_cooldown = seconds
	_resend_otp_button.visible = true


# 5. Complete Registration Form
func _on_register_pressed() -> void:
	if _busy:
		return
	var username := _reg_user_edit.text.strip_edges()
	var password := _reg_pass_edit.text
	var password_confirm := _reg_pass_confirm_edit.text

	# Validation
	if username.length() < 3:
		_set_status("نام کاربری باید حداقل ۳ کاراکتر باشد.", COLOR_ERR)
		_reg_user_edit.grab_focus()
		return

	# Regex check for alphanumeric + underscore
	var regex := RegEx.new()
	regex.compile("^[a-zA-Z0-9_]{3,30}$")
	if regex.search(username) == null:
		_set_status("نام کاربری فقط می‌تواند شامل حروف انگلیسی، عدد و _ باشد.", COLOR_ERR)
		_reg_user_edit.grab_focus()
		return

	if password.length() < 6:
		_set_status("رمز عبور باید حداقل ۶ کاراکتر باشد.", COLOR_ERR)
		_reg_pass_edit.grab_focus()
		return

	if password != password_confirm:
		_set_status("رمز عبور با تکرار آن یکسان نیست.", COLOR_ERR)
		_reg_pass_confirm_edit.grab_focus()
		return

	if _selected_grade not in [10, 11, 12]:
		_set_status("لطفاً پایه تحصیلی خود را انتخاب کنید.", COLOR_ERR)
		return

	_busy = true
	_submit_reg_button.disabled = true
	_set_status("در حال ثبت‌نام و ایجاد حساب…", Global.get_theme_color("text_dim"))

	API.register_user(_signup_token, username, password, _selected_grade, func(ok: bool, error: String) -> void:
		_busy = false
		_submit_reg_button.disabled = false
		if not ok:
			_set_status(_error_message(error, 0), COLOR_ERR)
			return
		_set_status("ثبت‌نام با موفقیت انجام شد! خوش آمدید.", COLOR_OK)
		await get_tree().create_timer(0.6).timeout
		TransitionManager.change_scene(SCENE_SETTINGS)
	)


# 6. Reset Password Form
func _on_reset_password_pressed() -> void:
	if _busy:
		return
	var new_pass := _new_pass_edit.text
	var confirm_pass := _confirm_pass_edit.text

	if new_pass.length() < 6:
		_set_status("رمز عبور باید حداقل ۶ کاراکتر باشد.", COLOR_ERR)
		_new_pass_edit.grab_focus()
		return

	if new_pass != confirm_pass:
		_set_status("رمز عبور با تکرار آن یکسان نیست.", COLOR_ERR)
		_confirm_pass_edit.grab_focus()
		return

	_busy = true
	_submit_reset_button.disabled = true
	_set_status("در حال تنظیم رمز عبور جدید…", Global.get_theme_color("text_dim"))

	API.reset_password(_reset_token, new_pass, func(ok: bool, error: String) -> void:
		_busy = false
		_submit_reset_button.disabled = false
		if not ok:
			_set_status(_error_message(error, 0), COLOR_ERR)
			return
		_set_status("رمز عبور با موفقیت تغییر کرد! خوش آمدید.", COLOR_OK)
		await get_tree().create_timer(0.6).timeout
		TransitionManager.change_scene(SCENE_SETTINGS)
	)


# 7. Logout
func _on_logout_pressed() -> void:
	API.logout()
	_switch_mode(Mode.SIGN_IN)


# ══════════════════════════════════════════════════════════════
#  STATUS & THEME
# ══════════════════════════════════════════════════════════════

func _set_status(message: String, color: Color) -> void:
	if _status_label == null:
		return
	_status_label.text = message
	_status_label.add_theme_color_override("font_color", color)


func _on_theme_changed(_mode: int) -> void:
	_apply_theme()


func _apply_theme() -> void:
	if not is_inside_tree():
		return
	var bg: ColorRect = $Background
	if bg != null:
		bg.color = Global.get_theme_color("bg_base")

	var card: PanelContainer = $Scroll/ScrollMargin/CenterBox/AuthCard
	if card != null:
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(28)
		style.content_margin_left = 48
		style.content_margin_right = 48
		style.content_margin_top = 48
		style.content_margin_bottom = 48
		style.bg_color = Global.get_theme_color("surface")
		style.border_color = Global.get_theme_color("border")
		style.set_border_width_all(1)
		card.add_theme_stylebox_override("panel", style)

	if _card_heading != null:
		_card_heading.add_theme_color_override("font_color", Global.get_theme_color("accent_bright"))
	if _card_subtitle != null:
		_card_subtitle.add_theme_color_override("font_color", Global.get_theme_color("text_dim"))
	if _status_label != null:
		_status_label.add_theme_color_override("font_color", Global.get_theme_color("text_dim"))

	_update_grade_buttons_ui()


func _error_message(error: String, retry_after: int) -> String:
	match error:
		"invalid_phone", "invalid_input":
			return "شماره موبایل معتبر نیست."
		"already_registered":
			return "این شماره قبلاً ثبت‌نام شده است. لطفاً وارد شوید."
		"user_not_found":
			return "حساب کاربری با این شماره یافت نشد."
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
		"invalid_credentials":
			return "نام کاربری یا رمز عبور اشتباه است."
		"invalid_or_expired_token":
			return "جلسه معتبر نیست یا منقضی شده است. لطفاً از ابتدا تلاش کنید."
		"invalid_username":
			return "نام کاربری نامعتبر است (حداقل ۳ حرف انگلیسی یا عدد)."
		"username_taken":
			return "این نام کاربری قبلاً ثبت شده است. نام دیگری انتخاب کنید."
		"weak_password":
			return "رمز عبور باید حداقل ۶ کاراکتر باشد."
		"invalid_grade":
			return "پایه تحصیلی معتبر نیست."
		"no_base_url":
			return "اتصال به سرور تنظیم نشده است."
		_:
			return "خطا در ارتباط با سرور. دوباره تلاش کنید."


# ══════════════════════════════════════════════════════════════
#  NAVIGATION
# ══════════════════════════════════════════════════════════════

func _on_android_back_pressed() -> void:
	Sfx.click()
	# If in a sub-step, navigate back within Auth instead of exiting
	if _current_mode in [Mode.SIGNUP_PHONE, Mode.FORGOT_PHONE]:
		_switch_mode(Mode.SIGN_IN)
	elif _current_mode == Mode.SIGNUP_OTP:
		_switch_mode(Mode.SIGNUP_PHONE)
	elif _current_mode == Mode.SIGNUP_PROFILE:
		_switch_mode(Mode.SIGN_IN)
	elif _current_mode == Mode.FORGOT_OTP:
		_switch_mode(Mode.FORGOT_PHONE)
	elif _current_mode == Mode.FORGOT_NEW_PASS:
		_switch_mode(Mode.SIGN_IN)
	else:
		TransitionManager.change_scene(SCENE_MAIN_MENU)
