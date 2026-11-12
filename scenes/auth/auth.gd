extends "res://autoload/BackButtonHandler.gd"

# ============================================================
#  AUTH — Account Authentication & Management
#  Supports:
#    * Sign In with Username / Phone + Password
#    * Sign Up via Phone OTP -> Username, Password (twice), School Grade (10, 11, 12)
#    * Password Recovery via Phone OTP -> Set New Password (twice)
#    * Logged-in profile hero, account bento & logout
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
const COLOR_ACCENT_BRIGHT := DesignTokens.ACCENT_BRIGHT
const COLOR_GOLD := DesignTokens.GOLD
const COLOR_OK := DesignTokens.SUCCESS
const COLOR_ERR := DesignTokens.ERROR
const COLOR_INK := DesignTokens.INK
const COLOR_DIM := Color("#6E6A61")

@onready var _main_col: VBoxContainer = $Scroll/ScrollMargin/MainColumn
@onready var _brand_banner: PanelContainer = $Scroll/ScrollMargin/MainColumn/BrandBanner
@onready var _auth_mode_tabs: PanelContainer = $Scroll/ScrollMargin/MainColumn/AuthModeTabs
@onready var _signin_tab_btn: Button = $Scroll/ScrollMargin/MainColumn/AuthModeTabs/Tabs/SignInTabButton
@onready var _signup_tab_btn: Button = $Scroll/ScrollMargin/MainColumn/AuthModeTabs/Tabs/SignUpTabButton

@onready var _auth_card: PanelContainer = $Scroll/ScrollMargin/MainColumn/AuthCard
@onready var _step_bar: VBoxContainer = $Scroll/ScrollMargin/MainColumn/AuthCard/CardMargin/VBoxContainer/StepBar
@onready var _step_label: Label = $Scroll/ScrollMargin/MainColumn/AuthCard/CardMargin/VBoxContainer/StepBar/StepLabel
@onready var _step_pills: Array[Panel] = [
	$Scroll/ScrollMargin/MainColumn/AuthCard/CardMargin/VBoxContainer/StepBar/Pills/Step1,
	$Scroll/ScrollMargin/MainColumn/AuthCard/CardMargin/VBoxContainer/StepBar/Pills/Step2,
	$Scroll/ScrollMargin/MainColumn/AuthCard/CardMargin/VBoxContainer/StepBar/Pills/Step3,
]
@onready var _heading_box: VBoxContainer = $Scroll/ScrollMargin/MainColumn/AuthCard/CardMargin/VBoxContainer/HeadingBox
@onready var _card_heading: Label = $Scroll/ScrollMargin/MainColumn/AuthCard/CardMargin/VBoxContainer/HeadingBox/CardHeading
@onready var _card_subtitle: Label = $Scroll/ScrollMargin/MainColumn/AuthCard/CardMargin/VBoxContainer/HeadingBox/CardSubtitle
@onready var _status_banner: PanelContainer = $Scroll/ScrollMargin/MainColumn/AuthCard/CardMargin/VBoxContainer/StatusBanner
@onready var _status_label: Label = $Scroll/ScrollMargin/MainColumn/AuthCard/CardMargin/VBoxContainer/StatusBanner/StatusLabel

# View containers
@onready var _signin_view: VBoxContainer = $Scroll/ScrollMargin/MainColumn/AuthCard/CardMargin/VBoxContainer/SignInView
@onready var _phone_step_view: VBoxContainer = $Scroll/ScrollMargin/MainColumn/AuthCard/CardMargin/VBoxContainer/PhoneStepView
@onready var _otp_step_view: VBoxContainer = $Scroll/ScrollMargin/MainColumn/AuthCard/CardMargin/VBoxContainer/OtpStepView
@onready var _register_view: VBoxContainer = $Scroll/ScrollMargin/MainColumn/AuthCard/CardMargin/VBoxContainer/RegisterFormView
@onready var _reset_pass_view: VBoxContainer = $Scroll/ScrollMargin/MainColumn/AuthCard/CardMargin/VBoxContainer/ResetPassView
@onready var _logged_in_view: VBoxContainer = $Scroll/ScrollMargin/MainColumn/AuthCard/CardMargin/VBoxContainer/LoggedInView

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
@onready var _reg_user_edit: LineEdit = _register_view.get_node("RegUserEdit") as LineEdit
@onready var _reg_pass_edit: LineEdit = _register_view.get_node("RegPassEdit") as LineEdit
@onready var _reg_pass_confirm_edit: LineEdit = _register_view.get_node("RegPassConfirmEdit") as LineEdit
@onready var _grade_10_btn: Button = _register_view.get_node("GradeSection/GradeButtonsBox/Grade10Button") as Button
@onready var _grade_11_btn: Button = _register_view.get_node("GradeSection/GradeButtonsBox/Grade11Button") as Button
@onready var _grade_12_btn: Button = _register_view.get_node("GradeSection/GradeButtonsBox/Grade12Button") as Button
@onready var _submit_reg_button: Button = _register_view.get_node("SubmitRegisterButton") as Button
@onready var _cancel_reg_button: Button = _register_view.get_node("CancelRegisterButton") as Button

# Reset Password Controls
@onready var _new_pass_edit: LineEdit = _reset_pass_view.get_node("NewPassEdit") as LineEdit
@onready var _confirm_pass_edit: LineEdit = _reset_pass_view.get_node("ConfirmPassEdit") as LineEdit
@onready var _submit_reset_button: Button = _reset_pass_view.get_node("SubmitResetButton") as Button
@onready var _cancel_reset_button: Button = _reset_pass_view.get_node("CancelResetButton") as Button

# Logged In Controls
@onready var _profile_hero_card: PanelContainer = _logged_in_view.get_node("ProfileHeroCard") as PanelContainer
@onready var _tier_label: Label = _logged_in_view.get_node("ProfileHeroCard/Margin/Row/TextCol/TierRow/TierPill/TierLabel") as Label
@onready var _username_label: Label = _logged_in_view.get_node("ProfileHeroCard/Margin/Row/TextCol/UsernameLabel") as Label
@onready var _profile_info_label: Label = _logged_in_view.get_node("ProfileHeroCard/Margin/Row/TextCol/ProfileInfoLabel") as Label
@onready var _phone_value_label: Label = _logged_in_view.get_node("InfoBento/PhoneTile/VBox/Value") as Label
@onready var _grade_value_label: Label = _logged_in_view.get_node("InfoBento/GradeTile/VBox/Value") as Label
@onready var _settings_shortcut_button: Button = _logged_in_view.get_node("SettingsShortcutButton") as Button
@onready var _logout_button: Button = _logged_in_view.get_node("LogoutButton") as Button

# State variables
var _current_mode: Mode = Mode.SIGN_IN
var _phone: String = ""
var _signup_token: String = ""
var _reset_token: String = ""
var _selected_grade: int = 10
var _resend_cooldown: float = 0.0
var _busy: bool = false
var _button_tweens: Dictionary = {}


func _ready() -> void:
	super._ready()
	wire_header_bar("حساب کاربری")
	_setup_controls()

	if API.is_logged_in():
		_switch_mode(Mode.LOGGED_IN, false)
	else:
		_switch_mode(Mode.SIGN_IN, false)

	set_process(true)
	_play_intro_animation()


func _exit_tree() -> void:
	for key: int in _button_tweens:
		var tw: Tween = _button_tweens[key] as Tween
		if tw != null and tw.is_valid():
			tw.kill()
	_button_tweens.clear()


func _process(delta: float) -> void:
	if _resend_cooldown > 0.0:
		_resend_cooldown = maxf(0.0, _resend_cooldown - delta)
		if _resend_otp_button != null and _resend_otp_button.visible:
			_resend_otp_button.disabled = _resend_cooldown > 0.0
			var seconds_left := int(ceil(_resend_cooldown))
			_resend_otp_button.text = MenuStyle.persian_digits("ارسال دوباره کد (%d)" % seconds_left)
	elif _resend_otp_button != null and _resend_otp_button.disabled:
		_resend_otp_button.disabled = false
		_resend_otp_button.text = "ارسال دوباره کد"


# ══════════════════════════════════════════════════════════════
#  SETUP & SPRING MICRO-INTERACTIONS
# ══════════════════════════════════════════════════════════════

func _setup_controls() -> void:
	_phone_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PHONE
	_otp_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER

	_signin_tab_btn.pressed.connect(_on_signin_tab_pressed)
	_signup_tab_btn.pressed.connect(_on_signup_tab_pressed)

	_login_button.pressed.connect(_on_login_pressed)
	_to_signup_button.pressed.connect(func() -> void:
		Sfx.click()
		_switch_mode(Mode.SIGNUP_PHONE)
	)
	_to_forgot_button.pressed.connect(func() -> void:
		Sfx.click()
		_switch_mode(Mode.FORGOT_PHONE)
	)

	_send_otp_button.pressed.connect(_on_send_otp_pressed)
	_phone_cancel_button.pressed.connect(func() -> void:
		Sfx.click()
		_switch_mode(Mode.SIGN_IN)
	)

	_verify_otp_button.pressed.connect(_on_verify_otp_pressed)
	_resend_otp_button.pressed.connect(_on_resend_otp_pressed)
	_change_phone_button.pressed.connect(_on_change_phone_pressed)

	_grade_10_btn.pressed.connect(func() -> void: _select_grade(10))
	_grade_11_btn.pressed.connect(func() -> void: _select_grade(11))
	_grade_12_btn.pressed.connect(func() -> void: _select_grade(12))

	_submit_reg_button.pressed.connect(_on_register_pressed)
	_cancel_reg_button.pressed.connect(func() -> void:
		Sfx.click()
		_switch_mode(Mode.SIGN_IN)
	)

	_submit_reset_button.pressed.connect(_on_reset_password_pressed)
	_cancel_reset_button.pressed.connect(func() -> void:
		Sfx.click()
		_switch_mode(Mode.SIGN_IN)
	)

	_settings_shortcut_button.pressed.connect(_on_settings_shortcut_pressed)
	_logout_button.pressed.connect(_on_logout_pressed)

	var spring_buttons: Array[Button] = [
		_login_button,
		_to_signup_button,
		_to_forgot_button,
		_send_otp_button,
		_phone_cancel_button,
		_verify_otp_button,
		_resend_otp_button,
		_change_phone_button,
		_grade_10_btn,
		_grade_11_btn,
		_grade_12_btn,
		_submit_reg_button,
		_cancel_reg_button,
		_submit_reset_button,
		_cancel_reset_button,
		_settings_shortcut_button,
		_logout_button,
	]
	for btn: Button in spring_buttons:
		_wire_spring(btn)

	for tab: Button in [_signin_tab_btn, _signup_tab_btn]:
		_wire_press_only_spring(tab)

	_update_grade_buttons_ui()


func _wire_spring(btn: Button) -> void:
	btn.pivot_offset = btn.size / 2.0
	btn.resized.connect(_on_btn_resized.bind(btn))
	btn.mouse_entered.connect(_on_btn_hover.bind(btn, true))
	btn.mouse_exited.connect(_on_btn_hover.bind(btn, false))
	btn.button_down.connect(_animate_btn_scale.bind(btn, Vector2(0.96, 0.96), 0.07, Tween.TRANS_QUAD))
	btn.button_up.connect(_on_btn_released.bind(btn))


func _wire_press_only_spring(btn: Button) -> void:
	btn.pivot_offset = btn.size / 2.0
	btn.resized.connect(_on_btn_resized.bind(btn))
	btn.button_down.connect(_animate_btn_scale.bind(btn, Vector2(0.97, 0.97), 0.07, Tween.TRANS_QUAD))
	btn.button_up.connect(_animate_btn_scale.bind(btn, Vector2.ONE, 0.18, Tween.TRANS_BACK))


func _on_btn_resized(btn: Button) -> void:
	btn.pivot_offset = btn.size / 2.0


func _on_btn_hover(btn: Button, entered: bool) -> void:
	if btn.disabled or btn.button_pressed:
		return
	var target: Vector2 = Vector2(1.02, 1.02) if entered else Vector2.ONE
	var duration: float = 0.16 if entered else 0.20
	_animate_btn_scale(btn, target, duration, Tween.TRANS_BACK)


func _on_btn_released(btn: Button) -> void:
	var target: Vector2 = Vector2(1.02, 1.02) if btn.is_hovered() and not btn.disabled else Vector2.ONE
	_animate_btn_scale(btn, target, 0.20, Tween.TRANS_BACK)


func _animate_btn_scale(btn: Button, target: Vector2, duration: float, trans: Tween.TransitionType) -> void:
	var key: int = btn.get_instance_id()
	var prev: Tween = _button_tweens.get(key) as Tween
	if prev != null and prev.is_valid():
		prev.kill()
	var tw: Tween = btn.create_tween()
	tw.set_trans(trans)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", target, duration)
	_button_tweens[key] = tw


func _play_intro_animation() -> void:
	var targets: Array[Control] = []
	for child: Node in _main_col.get_children():
		if child is Control and child.visible and not child.is_queued_for_deletion():
			var ctrl: Control = child as Control
			ctrl.modulate.a = 0.0
			ctrl.pivot_offset = ctrl.size / 2.0
			ctrl.scale = Vector2(0.96, 0.96)
			targets.append(ctrl)

	await get_tree().process_frame
	if not is_inside_tree():
		return

	var tw: Tween = create_tween()
	tw.set_parallel(true)
	for i: int in range(targets.size()):
		var target: Control = targets[i]
		target.pivot_offset = target.size / 2.0
		var delay: float = 0.04 * float(i)
		tw.tween_property(target, "modulate:a", 1.0, 0.26).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(target, "scale", Vector2.ONE, 0.32).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ══════════════════════════════════════════════════════════════
#  MODE SWITCHING & VIEW CHOREOGRAPHY
# ══════════════════════════════════════════════════════════════

func _on_signin_tab_pressed() -> void:
	if _current_mode == Mode.SIGN_IN:
		_sync_mode_tabs()
		return
	Sfx.click()
	_switch_mode(Mode.SIGN_IN)


func _on_signup_tab_pressed() -> void:
	if _current_mode in [Mode.SIGNUP_PHONE, Mode.SIGNUP_OTP, Mode.SIGNUP_PROFILE]:
		_sync_mode_tabs()
		return
	Sfx.click()
	_switch_mode(Mode.SIGNUP_PHONE)


func _switch_mode(new_mode: Mode, animate: bool = true) -> void:
	_current_mode = new_mode
	_set_status("", COLOR_DIM)

	_signin_view.visible = false
	_phone_step_view.visible = false
	_otp_step_view.visible = false
	_register_view.visible = false
	_reset_pass_view.visible = false
	_logged_in_view.visible = false

	var is_logged_in: bool = (_current_mode == Mode.LOGGED_IN)
	_brand_banner.visible = not is_logged_in
	_auth_mode_tabs.visible = _current_mode in [Mode.SIGN_IN, Mode.SIGNUP_PHONE, Mode.SIGNUP_OTP, Mode.SIGNUP_PROFILE]
	_heading_box.visible = not is_logged_in
	_sync_mode_tabs()
	_update_step_bar()

	var active_view: Control = null
	match _current_mode:
		Mode.LOGGED_IN:
			_refresh_logged_in_view()
			_logged_in_view.visible = true
			active_view = _logged_in_view

		Mode.SIGN_IN:
			_card_heading.text = "ورود به حساب کاربری"
			_card_subtitle.text = "نام کاربری یا شماره موبایل و رمز عبور خود را وارد کنید."
			_signin_view.visible = true
			active_view = _signin_view
			_login_user_edit.grab_focus()

		Mode.SIGNUP_PHONE:
			_card_heading.text = "ثبت‌نام با شماره موبایل"
			_card_subtitle.text = "شماره موبایل خود را وارد کنید تا کد تأیید پیامک شود."
			_phone_hint.text = "شماره موبایل خود را وارد کنید:"
			_send_otp_button.text = "ارسال کد تأیید"
			_phone_step_view.visible = true
			active_view = _phone_step_view
			_phone_edit.grab_focus()

		Mode.SIGNUP_OTP:
			_card_heading.text = "تأیید شماره موبایل"
			_card_subtitle.text = "کد ۵ رقمی ارسال‌شده به %s را وارد کنید." % MenuStyle.persian_digits(_phone)
			_otp_step_view.visible = true
			_otp_edit.text = ""
			active_view = _otp_step_view
			_otp_edit.grab_focus()

		Mode.SIGNUP_PROFILE:
			_card_heading.text = "تکمیل اطلاعات حساب"
			_card_subtitle.text = "نام کاربری، رمز عبور و پایه تحصیلی خود را مشخص کنید."
			_register_view.visible = true
			active_view = _register_view
			_reg_user_edit.grab_focus()

		Mode.FORGOT_PHONE:
			_card_heading.text = "بازیابی رمز عبور"
			_card_subtitle.text = "شماره موبایل ثبت‌شده در حساب خود را وارد کنید."
			_phone_hint.text = "کد بازیابی به شماره موبایل شما پیامک خواهد شد:"
			_send_otp_button.text = "ارسال کد بازیابی"
			_phone_step_view.visible = true
			active_view = _phone_step_view
			_phone_edit.grab_focus()

		Mode.FORGOT_OTP:
			_card_heading.text = "تأیید کد بازیابی"
			_card_subtitle.text = "کد ارسال‌شده به %s را وارد کنید." % MenuStyle.persian_digits(_phone)
			_otp_step_view.visible = true
			_otp_edit.text = ""
			active_view = _otp_step_view
			_otp_edit.grab_focus()

		Mode.FORGOT_NEW_PASS:
			_card_heading.text = "تعیین رمز عبور جدید"
			_card_subtitle.text = "رمز عبور جدید خود را ۲ بار وارد کنید."
			_reset_pass_view.visible = true
			_new_pass_edit.text = ""
			_confirm_pass_edit.text = ""
			active_view = _reset_pass_view
			_new_pass_edit.grab_focus()

	if animate and active_view != null:
		active_view.modulate.a = 0.0
		var tw: Tween = active_view.create_tween()
		tw.set_trans(Tween.TRANS_CUBIC)
		tw.set_ease(Tween.EASE_OUT)
		tw.tween_property(active_view, "modulate:a", 1.0, 0.22)


func _sync_mode_tabs() -> void:
	var is_signup: bool = _current_mode in [Mode.SIGNUP_PHONE, Mode.SIGNUP_OTP, Mode.SIGNUP_PROFILE]
	_signin_tab_btn.button_pressed = not is_signup
	_signup_tab_btn.button_pressed = is_signup


func _update_step_bar() -> void:
	var step_index: int = 0
	var flow_name: String = ""
	match _current_mode:
		Mode.SIGNUP_PHONE:
			step_index = 1
			flow_name = "ثبت‌نام"
		Mode.SIGNUP_OTP:
			step_index = 2
			flow_name = "ثبت‌نام"
		Mode.SIGNUP_PROFILE:
			step_index = 3
			flow_name = "ثبت‌نام"
		Mode.FORGOT_PHONE:
			step_index = 1
			flow_name = "بازیابی رمز"
		Mode.FORGOT_OTP:
			step_index = 2
			flow_name = "بازیابی رمز"
		Mode.FORGOT_NEW_PASS:
			step_index = 3
			flow_name = "بازیابی رمز"
		_:
			step_index = 0

	_step_bar.visible = step_index > 0
	if step_index <= 0:
		return

	_step_label.text = "%s · مرحله %s از ۳" % [flow_name, MenuStyle.persian_digits(str(step_index))]
	for i: int in range(_step_pills.size()):
		var pill: Panel = _step_pills[i]
		var st := StyleBoxFlat.new()
		st.set_corner_radius_all(999)
		if i + 1 < step_index:
			st.bg_color = COLOR_OK
		elif i + 1 == step_index:
			st.bg_color = COLOR_ACCENT
		else:
			st.bg_color = Color("#EBE5D8")
		pill.add_theme_stylebox_override("panel", st)


func _refresh_logged_in_view() -> void:
	var phone_raw: String = API.get_phone().strip_edges()
	var phone: String = MenuStyle.persian_digits(phone_raw) if not phone_raw.is_empty() else "ثبت‌نشده"
	var username: String = API.get_username().strip_edges()
	var grade: int = API.get_grade()
	var grade_fa: String = ""
	match grade:
		10: grade_fa = "پایه دهم"
		11: grade_fa = "پایه یازدهم"
		12: grade_fa = "پایه دوازدهم"
		_: grade_fa = "متوسطه دوم"

	var tier: String = str(API.get_subscription().get("tier", "free"))
	var is_premium: bool = (tier != "free" and tier != "")

	_username_label.text = username if not username.is_empty() else "کاربر ویژن مستر"
	_tier_label.text = "اشتراک ویژه ✨" if is_premium else "حساب کاربری فعال ✓"
	_profile_info_label.text = "پیشرفت مطالعه و امتیازهای چالش روزانه همگام‌سازی می‌شوند."
	_phone_value_label.text = phone
	_grade_value_label.text = grade_fa


# ══════════════════════════════════════════════════════════════
#  GRADE SELECTOR
# ══════════════════════════════════════════════════════════════

func _select_grade(grade: int) -> void:
	Sfx.click()
	_selected_grade = grade
	_update_grade_buttons_ui()


func _update_grade_buttons_ui() -> void:
	var grade_buttons: Dictionary = {
		10: _grade_10_btn,
		11: _grade_11_btn,
		12: _grade_12_btn,
	}

	for grade_val: int in grade_buttons.keys():
		var btn: Button = grade_buttons[grade_val] as Button
		if btn == null:
			continue
		var is_selected: bool = (grade_val == _selected_grade)
		var normal_style := StyleBoxFlat.new()
		normal_style.set_corner_radius_all(18)
		normal_style.set_content_margin_all(14)
		var hover_style := normal_style.duplicate() as StyleBoxFlat

		if is_selected:
			normal_style.bg_color = COLOR_ACCENT
			normal_style.border_color = COLOR_ACCENT_BRIGHT
			normal_style.set_border_width_all(2)
			normal_style.shadow_color = Color(COLOR_ACCENT.r, COLOR_ACCENT.g, COLOR_ACCENT.b, 0.30)
			normal_style.shadow_size = 10
			hover_style.bg_color = COLOR_ACCENT_BRIGHT
			hover_style.border_color = COLOR_ACCENT_BRIGHT
			hover_style.set_border_width_all(2)
			btn.add_theme_font_override("font", MenuStyle.vazir_bold())
			btn.add_theme_font_size_override("font_size", 28)
			btn.add_theme_color_override("font_color", Color.WHITE)
			btn.add_theme_color_override("font_hover_color", Color.WHITE)
			btn.add_theme_color_override("font_pressed_color", Color.WHITE)
		else:
			normal_style.bg_color = Color("#F7F4EC")
			normal_style.border_color = Color(0.235, 0.196, 0.118, 0.16)
			normal_style.set_border_width_all(1)
			hover_style.bg_color = Color("#EFE7D2")
			hover_style.border_color = Color(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b, 0.45)
			hover_style.set_border_width_all(2)
			btn.add_theme_font_override("font", MenuStyle.vazir())
			btn.add_theme_font_size_override("font_size", 27)
			btn.add_theme_color_override("font_color", COLOR_INK)
			btn.add_theme_color_override("font_hover_color", COLOR_INK)
			btn.add_theme_color_override("font_pressed_color", COLOR_INK)

		btn.add_theme_stylebox_override("normal", normal_style)
		btn.add_theme_stylebox_override("hover", hover_style)
		btn.add_theme_stylebox_override("pressed", normal_style)
		btn.add_theme_stylebox_override("focus", hover_style)


# ══════════════════════════════════════════════════════════════
#  ACTIONS & HANDLERS
# ══════════════════════════════════════════════════════════════

func _on_login_pressed() -> void:
	if _busy:
		return
	Sfx.click()
	var identifier := _login_user_edit.text.strip_edges()
	var password := _login_pass_edit.text
	if identifier == "":
		_set_status("لطفاً نام کاربری یا شماره موبایل را وارد کنید.", COLOR_ERR, true)
		_login_user_edit.grab_focus()
		return
	if password == "":
		_set_status("لطفاً رمز عبور را وارد کنید.", COLOR_ERR, true)
		_login_pass_edit.grab_focus()
		return

	_busy = true
	_login_button.disabled = true
	_set_status("در حال ورود به حساب…", COLOR_DIM)

	API.login_with_password(identifier, password, func(ok: bool, error: String) -> void:
		_busy = false
		_login_button.disabled = false
		if not ok:
			_set_status(_error_message(error, 0), COLOR_ERR, true)
			return
		_set_status("خوش آمدید! ورود موفقیت‌آمیز بود.", COLOR_OK)
		await get_tree().create_timer(0.6).timeout
		if is_inside_tree():
			TransitionManager.change_scene(SCENE_SETTINGS)
	)


func _on_send_otp_pressed() -> void:
	if _busy:
		return
	Sfx.click()
	var phone := _phone_edit.text.strip_edges()
	if phone.length() < 10:
		_set_status("شماره موبایل معتبر وارد کنید.", COLOR_ERR, true)
		_phone_edit.grab_focus()
		return
	_phone = phone
	_busy = true
	_send_otp_button.disabled = true
	_set_status("در حال ارسال کد تأیید…", COLOR_DIM)

	var intent := "signup" if _current_mode == Mode.SIGNUP_PHONE else "reset"
	API.request_otp(phone, func(ok: bool, error: String, retry_after: int) -> void:
		_busy = false
		_send_otp_button.disabled = false
		if not ok:
			_set_status(_error_message(error, retry_after), COLOR_ERR, true)
			return
		_start_resend_cooldown(60.0)
		if _current_mode == Mode.SIGNUP_PHONE:
			_switch_mode(Mode.SIGNUP_OTP)
		else:
			_switch_mode(Mode.FORGOT_OTP)
		_set_status("کد تأیید پیامک شد.", COLOR_OK)
	, intent)


func _on_verify_otp_pressed() -> void:
	if _busy:
		return
	Sfx.click()
	var code := _otp_edit.text.strip_edges()
	if code.length() < 4:
		_set_status("کد را کامل وارد کنید.", COLOR_ERR, true)
		_otp_edit.grab_focus()
		return

	_busy = true
	_verify_otp_button.disabled = true
	_set_status("در حال بررسی کد…", COLOR_DIM)

	if _current_mode == Mode.SIGNUP_OTP:
		API.verify_otp_for_signup(_phone, code, func(ok: bool, signup_token: String, error: String) -> void:
			_busy = false
			_verify_otp_button.disabled = false
			if not ok:
				_set_status(_error_message(error, 0), COLOR_ERR, true)
				return
			_signup_token = signup_token
			_switch_mode(Mode.SIGNUP_PROFILE)
			_set_status("شماره تأیید شد. لطفاً اطلاعات حساب را تکمیل کنید.", COLOR_OK)
		)
	else:
		API.verify_otp_for_reset(_phone, code, func(ok: bool, reset_token: String, error: String) -> void:
			_busy = false
			_verify_otp_button.disabled = false
			if not ok:
				_set_status(_error_message(error, 0), COLOR_ERR, true)
				return
			_reset_token = reset_token
			_switch_mode(Mode.FORGOT_NEW_PASS)
			_set_status("کد تأیید شد. اکنون رمز عبور جدید را تعیین کنید.", COLOR_OK)
		)


func _on_resend_otp_pressed() -> void:
	if _busy or _resend_cooldown > 0.0:
		return
	Sfx.click()
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
			_set_status(_error_message(error, retry_after), COLOR_ERR, true)
	, intent)


func _on_change_phone_pressed() -> void:
	Sfx.click()
	_resend_cooldown = 0.0
	if _current_mode == Mode.SIGNUP_OTP:
		_switch_mode(Mode.SIGNUP_PHONE)
	else:
		_switch_mode(Mode.FORGOT_PHONE)


func _start_resend_cooldown(seconds: float) -> void:
	_resend_cooldown = seconds
	_resend_otp_button.visible = true


func _on_register_pressed() -> void:
	if _busy:
		return
	Sfx.click()
	var username := _reg_user_edit.text.strip_edges()
	var password := _reg_pass_edit.text
	var password_confirm := _reg_pass_confirm_edit.text

	if username.length() < 3:
		_set_status("نام کاربری باید حداقل ۳ کاراکتر باشد.", COLOR_ERR, true)
		_reg_user_edit.grab_focus()
		return

	var regex := RegEx.new()
	regex.compile("^[a-zA-Z0-9_]{3,30}$")
	if regex.search(username) == null:
		_set_status("نام کاربری فقط می‌تواند شامل حروف انگلیسی، عدد و _ باشد.", COLOR_ERR, true)
		_reg_user_edit.grab_focus()
		return

	if password.length() < 6:
		_set_status("رمز عبور باید حداقل ۶ کاراکتر باشد.", COLOR_ERR, true)
		_reg_pass_edit.grab_focus()
		return

	if password != password_confirm:
		_set_status("رمز عبور با تکرار آن یکسان نیست.", COLOR_ERR, true)
		_reg_pass_confirm_edit.grab_focus()
		return

	if _selected_grade not in [10, 11, 12]:
		_set_status("لطفاً پایه تحصیلی خود را انتخاب کنید.", COLOR_ERR, true)
		return

	_busy = true
	_submit_reg_button.disabled = true
	_set_status("در حال ثبت‌نام و ایجاد حساب…", COLOR_DIM)

	API.register_user(_signup_token, username, password, _selected_grade, func(ok: bool, error: String) -> void:
		_busy = false
		_submit_reg_button.disabled = false
		if not ok:
			_set_status(_error_message(error, 0), COLOR_ERR, true)
			return
		_set_status("ثبت‌نام با موفقیت انجام شد! خوش آمدید.", COLOR_OK)
		await get_tree().create_timer(0.6).timeout
		if is_inside_tree():
			TransitionManager.change_scene(SCENE_SETTINGS)
	)


func _on_reset_password_pressed() -> void:
	if _busy:
		return
	Sfx.click()
	var new_pass := _new_pass_edit.text
	var confirm_pass := _confirm_pass_edit.text

	if new_pass.length() < 6:
		_set_status("رمز عبور باید حداقل ۶ کاراکتر باشد.", COLOR_ERR, true)
		_new_pass_edit.grab_focus()
		return

	if new_pass != confirm_pass:
		_set_status("رمز عبور با تکرار آن یکسان نیست.", COLOR_ERR, true)
		_confirm_pass_edit.grab_focus()
		return

	_busy = true
	_submit_reset_button.disabled = true
	_set_status("در حال تنظیم رمز عبور جدید…", COLOR_DIM)

	API.reset_password(_reset_token, new_pass, func(ok: bool, error: String) -> void:
		_busy = false
		_submit_reset_button.disabled = false
		if not ok:
			_set_status(_error_message(error, 0), COLOR_ERR, true)
			return
		_set_status("رمز عبور با موفقیت تغییر کرد! خوش آمدید.", COLOR_OK)
		await get_tree().create_timer(0.6).timeout
		if is_inside_tree():
			TransitionManager.change_scene(SCENE_SETTINGS)
	)


func _on_settings_shortcut_pressed() -> void:
	Sfx.click()
	TransitionManager.change_scene(SCENE_SETTINGS)


func _on_logout_pressed() -> void:
	Sfx.click()
	API.logout()
	_switch_mode(Mode.SIGN_IN)


# ══════════════════════════════════════════════════════════════
#  STATUS BANNER & ERRORS
# ══════════════════════════════════════════════════════════════

func _set_status(message: String, color: Color, is_error: bool = false) -> void:
	if _status_label == null or _status_banner == null:
		return
	_status_label.text = message
	_status_banner.visible = not message.is_empty()
	if message.is_empty():
		return

	_status_label.add_theme_color_override("font_color", color)
	var st := StyleBoxFlat.new()
	st.set_corner_radius_all(18)
	st.set_border_width_all(1)
	st.content_margin_left = 20.0
	st.content_margin_right = 20.0
	st.content_margin_top = 14.0
	st.content_margin_bottom = 14.0

	if is_error:
		st.bg_color = Color("#FDF2F2")
		st.border_color = Color(COLOR_ERR.r, COLOR_ERR.g, COLOR_ERR.b, 0.35)
		UiMotion.shake(_status_banner)
	elif color == COLOR_OK:
		st.bg_color = Color("#F0FAF4")
		st.border_color = Color(COLOR_OK.r, COLOR_OK.g, COLOR_OK.b, 0.35)
	else:
		st.bg_color = Color("#FAF7F0")
		st.border_color = Color(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b, 0.30)

	_status_banner.add_theme_stylebox_override("panel", st)


func _error_message(error: String, retry_after: int) -> String:
	match error:
		"invalid_phone", "invalid_input":
			return "شماره موبایل معتبر نیست."
		"already_registered":
			return "این شماره قبلاً ثبت‌نام شده است. لطفاً وارد شوید."
		"user_not_found":
			return "حساب کاربری با این شماره یافت نشد."
		"too_many_requests":
			return MenuStyle.persian_digits("لطفاً %d ثانیه دیگر دوباره تلاش کنید." % retry_after)
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
