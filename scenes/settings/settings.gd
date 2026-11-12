extends "res://autoload/BackButtonHandler.gd"
## ============================================================
##  SETTINGS — Redesigned, Modern & Feature-Complete Settings Screen
##  Vision Master English Learning Application
##  Sections:
##    • حساب کاربری    (Account status, login / logout)
##    • دانلود محتوا    (Offline content management, progress, storage)
##    • صدا و گفتار     (Sound effects + English TTS toggles & test)
##    • مدیریت داده‌ها   (Clear flashcards / Leitner / reset all progress)
##    • درباره برنامه   (App version, developer link, subscription status)
##  Design language: Light warm-paper palette, spring micro-interactions.
## ============================================================

const SCENE_AUTH := "res://scenes/auth/Auth.tscn"
const SCENE_MAIN_MENU := "res://scenes/main_menu/MainMenu.tscn"
const SCENE_ABOUT_ME := "res://scenes/about_me/AboutMe.tscn"

# --- Node references (match Settings.tscn) ---
@onready var bg: ColorRect = $Bg
@onready var scroll: ScrollContainer = $Scroll
@onready var layout: VBoxContainer = $Scroll/Margin/Layout

# Cards for staggered entrance animation
@onready var account_card: PanelContainer = $Scroll/Margin/Layout/AccountCard
@onready var downloads_card: PanelContainer = $Scroll/Margin/Layout/DownloadsCard
@onready var sound_card: PanelContainer = $Scroll/Margin/Layout/SoundCard
@onready var data_card: PanelContainer = $Scroll/Margin/Layout/DataCard
@onready var about_card: PanelContainer = $Scroll/Margin/Layout/AboutCard

# Account section
@onready var account_badge: Label = $Scroll/Margin/Layout/AccountCard/VBox/HeaderRow/Badge
@onready var account_status: Label = $Scroll/Margin/Layout/AccountCard/VBox/StatusBox/AccountStatus
@onready var account_login_button: Button = $Scroll/Margin/Layout/AccountCard/VBox/AccountLoginButton
@onready var account_logout_button: Button = $Scroll/Margin/Layout/AccountCard/VBox/AccountLogoutButton

# Downloads section
@onready var download_info: Label = $Scroll/Margin/Layout/DownloadsCard/VBox/InfoBox/VBox/DownloadInfo
@onready var download_hint: Label = $Scroll/Margin/Layout/DownloadsCard/VBox/InfoBox/VBox/DownloadHint
@onready var download_progress_bar: ProgressBar = $Scroll/Margin/Layout/DownloadsCard/VBox/InfoBox/VBox/DownloadProgressBar
@onready var download_progress_label: Label = $Scroll/Margin/Layout/DownloadsCard/VBox/InfoBox/VBox/DownloadProgressLabel
@onready var download_button: Button = $Scroll/Margin/Layout/DownloadsCard/VBox/DownloadButton
@onready var cancel_download_button: Button = $Scroll/Margin/Layout/DownloadsCard/VBox/CancelDownloadButton
@onready var clear_content_button: Button = $Scroll/Margin/Layout/DownloadsCard/VBox/ClearContentButton

# Sound & Speech section
@onready var sound_toggle: Button = $Scroll/Margin/Layout/SoundCard/VBox/SoundRow/SoundToggle
@onready var tts_toggle: Button = $Scroll/Margin/Layout/SoundCard/VBox/TtsRow/TtsToggle
@onready var test_tts_button: Button = $Scroll/Margin/Layout/SoundCard/VBox/TestTtsButton

# Data Management section
@onready var saved_words_stat: Label = $Scroll/Margin/Layout/DataCard/VBox/StatsBox/HBox/SavedWordsStat
@onready var review_words_stat: Label = $Scroll/Margin/Layout/DataCard/VBox/StatsBox/HBox/ReviewWordsStat
@onready var clear_saved_button: Button = $Scroll/Margin/Layout/DataCard/VBox/ClearSavedButton
@onready var clear_review_button: Button = $Scroll/Margin/Layout/DataCard/VBox/ClearReviewButton
@onready var reset_button: Button = $Scroll/Margin/Layout/DataCard/VBox/ResetButton

# About section
@onready var version_value: Label = $Scroll/Margin/Layout/AboutCard/VBox/InfoBox/VBox/VersionRow/VersionValue
@onready var sub_value: Label = $Scroll/Margin/Layout/AboutCard/VBox/InfoBox/VBox/SubRow/SubValue
@onready var about_dev_button: Button = $Scroll/Margin/Layout/AboutCard/VBox/AboutDevButton

# Active toast & modal references
var _active_modal: CanvasLayer = null
var _current_toast: CanvasLayer = null


func _ready() -> void:
	wire_header_bar("تنظیمات")

	# Initialise toggle button states
	_update_toggle(sound_toggle, Global.sound_enabled, false)
	_update_toggle(tts_toggle, Global.tts_enabled, false)

	# Initialise text values
	version_value.text = _app_version()
	_refresh_account_section()
	_refresh_downloads_section()
	_refresh_data_section()

	# Connect signals
	_connect_interactive_signals()
	_wire_all_button_springs()

	# Theme & global event updates
	_apply_theme()
	Global.on_theme_changed(_on_theme_changed)

	API.logged_in.connect(func(_user: Dictionary) -> void: _refresh_account_section())
	API.logged_out.connect(_refresh_account_section)
	API.subscription_updated.connect(func(_sub: Dictionary) -> void: _refresh_account_section())
	Content.manifest_ready.connect(_refresh_downloads_section)
	Content.download_progress.connect(_on_download_progress)
	Content.download_finished.connect(_on_download_finished)
	Global.review_words_changed.connect(_refresh_data_section)

	# Staggered entrance animation
	_play_entrance_animation()


func _on_theme_changed(_mode: int) -> void:
	_apply_theme()


func _apply_theme() -> void:
	if bg != null:
		bg.color = Global.get_theme_color("bg_base")


# ══════════════════════════════════════════════════════════════
#  INTERACTIVE CONNECTIONS & BUTTON SPRINGS
# ══════════════════════════════════════════════════════════════
func _connect_interactive_signals() -> void:
	# Account
	account_login_button.pressed.connect(_on_account_login_pressed)
	account_logout_button.pressed.connect(_on_logout_pressed)

	# Downloads
	download_button.pressed.connect(_on_download_all_pressed)
	cancel_download_button.pressed.connect(_on_cancel_download_pressed)
	clear_content_button.pressed.connect(_on_clear_content_pressed)

	# Sound & TTS
	sound_toggle.pressed.connect(_on_sound_toggled)
	tts_toggle.pressed.connect(_on_tts_toggled)
	test_tts_button.pressed.connect(_on_test_tts_pressed)

	# Data
	clear_saved_button.pressed.connect(_on_clear_saved_pressed)
	clear_review_button.pressed.connect(_on_clear_review_pressed)
	reset_button.pressed.connect(_on_reset_pressed)

	# About
	about_dev_button.pressed.connect(_on_about_dev_pressed)


func _wire_all_button_springs() -> void:
	var buttons: Array[Button] = [
		account_login_button,
		account_logout_button,
		download_button,
		cancel_download_button,
		clear_content_button,
		sound_toggle,
		tts_toggle,
		test_tts_button,
		clear_saved_button,
		clear_review_button,
		reset_button,
		about_dev_button,
	]
	for btn in buttons:
		if btn != null:
			_setup_button_spring(btn)


## Tactile spring-physics micro-interaction for interactive buttons
func _setup_button_spring(button: Button) -> void:
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
#  ENTRANCE ANIMATION
# ══════════════════════════════════════════════════════════════
func _play_entrance_animation() -> void:
	var animated_cards: Array[Control] = [
		account_card,
		downloads_card,
		sound_card,
		data_card,
		about_card
	]

	var delay: float = 0.05
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
#  TOGGLE CONTROLS (SOUND & TTS)
# ══════════════════════════════════════════════════════════════
func _update_toggle(btn: Button, is_on: bool, animate: bool = true) -> void:
	btn.text = "روشن ✓" if is_on else "خاموش ✕"

	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(20)
	style.content_margin_left = 24.0
	style.content_margin_top = 16.0
	style.content_margin_right = 24.0
	style.content_margin_bottom = 16.0

	if is_on:
		style.bg_color = Global.get_theme_color("accent")
		style.border_color = Global.get_theme_color("accent_bright")
		style.set_border_width_all(2)
		style.shadow_color = Color(0.184314, 0.435294, 0.847059, 0.35)
		style.shadow_size = 8
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
		btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	else:
		style.bg_color = Color(0.93, 0.91, 0.88, 1)
		style.border_color = Color(0.235, 0.196, 0.118, 0.16)
		style.set_border_width_all(1)
		btn.add_theme_color_override("font_color", Color(0.38, 0.35, 0.32, 1))
		btn.add_theme_color_override("font_hover_color", Color(0.25, 0.22, 0.20, 1))
		btn.add_theme_color_override("font_pressed_color", Color(0.25, 0.22, 0.20, 1))

	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("focus", style)

	if animate:
		var tw: Tween = create_tween()
		tw.tween_property(btn, "scale", Vector2(1.08, 1.08), 0.10) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.14) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _on_sound_toggled() -> void:
	Global.sound_enabled = not Global.sound_enabled
	Global.save_settings()
	_update_toggle(sound_toggle, Global.sound_enabled, true)
	if Global.sound_enabled:
		Sfx.click()


func _on_tts_toggled() -> void:
	Global.tts_enabled = not Global.tts_enabled
	Global.save_settings()
	_update_toggle(tts_toggle, Global.tts_enabled, true)
	if Global.sound_enabled:
		Sfx.click()
	if Global.tts_enabled:
		Global.speak_word("Hello")
		_show_toast("تلفظ انگلیسی فعال شد ✓")
	else:
		_show_toast("تلفظ انگلیسی غیرفعال شد")


func _on_test_tts_pressed() -> void:
	if Global.sound_enabled:
		Sfx.click()
	if not Global.tts_enabled:
		_show_toast("برای پخش، ابتدا گزینه تلفظ انگلیسی را روشن کنید")
		return
	Global.speak_word("Hello, welcome to Vision Master!")
	_show_toast("در حال پخش تلفظ نمونه...")


# ══════════════════════════════════════════════════════════════
#  ACCOUNT SECTION
# ══════════════════════════════════════════════════════════════
func _refresh_account_section() -> void:
	if account_status == null:
		return
	if API.is_logged_in():
		var phone := MenuStyle.persian_digits(API.get_phone())
		var tier := str(API.get_subscription().get("tier", "free"))
		var tier_fa := "ویژه (VIP)" if tier != "free" else "رایگان"
		account_status.text = "شماره همراه: %s\nسطح دسترسی: %s" % [phone, tier_fa]
		account_badge.text = "متصل"
		account_badge.add_theme_color_override("font_color", Global.get_theme_color("success"))
		account_login_button.visible = false
		account_logout_button.visible = true
		sub_value.text = tier_fa
	else:
		account_status.text = "برای ذخیره ابری پیشرفت، همگام‌سازی لایتنر و دانلود فایل‌های صوتی و تصویری دروس با شماره موبایل وارد شوید."
		account_badge.text = "مهمان"
		account_badge.add_theme_color_override("font_color", Global.get_theme_color("text_dim"))
		account_login_button.visible = true
		account_logout_button.visible = false
		sub_value.text = "نسخه رایگان"


func _on_account_login_pressed() -> void:
	if Global.sound_enabled:
		Sfx.click()
	TransitionManager.change_scene(SCENE_AUTH)


func _on_logout_pressed() -> void:
	if Global.sound_enabled:
		Sfx.click()
	_show_confirm_dialog(
		"خروج از حساب کاربری",
		"از حساب کاربری خود خارج می‌شوید.\nاطلاعات و پیشرفت محلی شما روی این دستگاه حفظ خواهد شد.\nادامه می‌دهید؟",
		"خروج از حساب",
		false,
		func() -> void:
			API.logout()
			_refresh_account_section()
			_refresh_downloads_section()
			_show_toast("با موفقیت از حساب کاربری خارج شدید ✓")
	)


# ══════════════════════════════════════════════════════════════
#  DOWNLOADS SECTION
# ══════════════════════════════════════════════════════════════
func _refresh_downloads_section() -> void:
	if download_info == null:
		return

	var bytes: int = Content.total_downloaded_bytes()
	var size_text: String = MenuStyle.persian_digits(_format_mb(bytes))
	download_info.text = "حجم محتوای دانلودشده: %s" % size_text

	var is_dl: bool = Content.is_downloading()
	download_button.disabled = is_dl
	cancel_download_button.visible = is_dl
	download_progress_bar.visible = is_dl
	download_progress_label.visible = is_dl

	if not API.is_logged_in() and not Content.has_manifest():
		download_hint.text = "برای دانلود فایل‌های صوتی و تصویری دروس، ابتدا وارد حساب کاربری شوید."
	else:
		download_hint.text = "فایل‌های صوتی و تصویری دروس برای استفاده آفلاین در دسترس هستند."


func _format_mb(bytes: int) -> String:
	if bytes < 1048576:
		return "%d کیلوبایت" % int(bytes / 1024.0)
	return "%.1f مگابایت" % (float(bytes) / 1048576.0)


func _on_download_all_pressed() -> void:
	if Global.sound_enabled:
		Sfx.click()
	if not API.is_logged_in():
		_show_toast("ابتدا وارد حساب کاربری شوید")
		return

	download_button.disabled = true
	cancel_download_button.visible = true
	download_progress_bar.visible = true
	download_progress_bar.value = 0.0
	download_progress_label.visible = true
	download_progress_label.text = "در حال آماده‌سازی و دریافت لیست فایل‌ها…"
	Content.download_all()


func _on_cancel_download_pressed() -> void:
	if Global.sound_enabled:
		Sfx.click()
	Content.cancel_downloads()
	download_button.disabled = false
	cancel_download_button.visible = false
	download_progress_bar.visible = false
	download_progress_label.text = "دانلود لغو شد."
	_show_toast("دانلود محتوا متوقف شد")
	_refresh_downloads_section()


func _on_clear_content_pressed() -> void:
	if Global.sound_enabled:
		Sfx.click()
	var bytes: int = Content.total_downloaded_bytes()
	if bytes <= 0:
		_show_toast("هیچ فایل دانلودشده‌ای برای پاک‌سازی وجود ندارد.")
		return

	_show_confirm_dialog(
		"پاک‌سازی محتوای دانلودشده",
		"همه فایل‌های صوتی و تصویری دانلودشده (%s) حذف خواهند شد.\nاین فایل‌ها هنگام ورود به هر درس مجدداً دانلود می‌شوند.\nادامه می‌دهید؟" % MenuStyle.persian_digits(_format_mb(bytes)),
		"پاک کردن فایل‌ها",
		true,
		func() -> void:
			Content.clear_downloads()
			_refresh_downloads_section()
			download_progress_label.visible = false
			download_progress_bar.visible = false
			_show_toast("محتوای دانلودشده با موفقیت پاک شد ✓")
	)


func _on_download_progress(done_count: int, total_count: int, done_bytes: int, total_bytes: int) -> void:
	if download_progress_label == null:
		return
	if total_count == 0:
		return

	download_progress_bar.visible = true
	download_progress_label.visible = true
	cancel_download_button.visible = true
	download_button.disabled = true

	var progress_ratio: float = float(done_bytes) / float(max(1, total_bytes))
	download_progress_bar.value = clampf(progress_ratio, 0.0, 1.0)

	download_progress_label.text = "دانلود %s از %s فایل (%s از %s)" % [
		MenuStyle.persian_digits(str(done_count)),
		MenuStyle.persian_digits(str(total_count)),
		MenuStyle.persian_digits(_format_mb(done_bytes)),
		MenuStyle.persian_digits(_format_mb(total_bytes))
	]


func _on_download_finished(success: bool) -> void:
	if download_button == null:
		return
	download_button.disabled = false
	cancel_download_button.visible = false
	download_progress_bar.visible = false

	if success:
		download_progress_label.text = "دانلود با موفقیت پایان یافت ✓"
		_show_toast("دانلود همه فایل‌ها کامل شد ✓")
	else:
		download_progress_label.text = "دانلود با خطا مواجه شد — لطفاً اتصال اینترنت را بررسی کنید."
		_show_toast("خطا در دانلود برخی فایل‌ها")
	_refresh_downloads_section()


# ══════════════════════════════════════════════════════════════
#  DATA MANAGEMENT SECTION
# ══════════════════════════════════════════════════════════════
func _refresh_data_section() -> void:
	var saved_count: int = Global.get_saved_words().size()
	var review_count: int = Global.get_review_words().size()

	saved_words_stat.text = "فلش‌کارت‌ها: %s لغت" % MenuStyle.persian_digits(str(saved_count))
	review_words_stat.text = "مرور لایتنر: %s لغت" % MenuStyle.persian_digits(str(review_count))


func _on_clear_saved_pressed() -> void:
	if Global.sound_enabled:
		Sfx.click()
	var count: int = Global.get_saved_words().size()
	if count == 0:
		_show_toast("لیست فلش‌کارت‌ها خالی است.")
		return

	_show_confirm_dialog(
		"پاک کردن فلش‌کارت‌ها",
		"همه %s لغت ذخیره‌شده در فلش‌کارت‌ها پاک خواهند شد.\nاین عمل قابل بازگشت نیست. آیا مایل به ادامه هستید؟" % MenuStyle.persian_digits(str(count)),
		"پاک کردن",
		true,
		func() -> void:
			Global.clear_saved_words()
			_refresh_data_section()
			_show_toast("فلش‌کارت‌ها پاک شدند ✓")
	)


func _on_clear_review_pressed() -> void:
	if Global.sound_enabled:
		Sfx.click()
	var count: int = Global.get_review_words().size()
	if count == 0:
		_show_toast("لیست مرور لایتنر خالی است.")
		return

	_show_confirm_dialog(
		"پاک کردن نوبت مرور لایتنر",
		"همه %s لغت در نوبت مرور جعبه لایتنر پاک خواهند شد.\nتوجه: با توجه به همگام‌بودن لیست‌ها، فلش‌کارت‌ها نیز بازنشانی می‌شوند.\nادامه می‌دهید؟" % MenuStyle.persian_digits(str(count)),
		"پاک کردن نوبت مرور",
		true,
		func() -> void:
			Global.clear_review_words()
			_refresh_data_section()
			_show_toast("نوبت مرور لایتنر پاک شد ✓")
	)


func _on_reset_pressed() -> void:
	if Global.sound_enabled:
		Sfx.click()
	_show_confirm_dialog(
		"بازنشانی کامل پیشرفت",
		"تمام پیشرفت آموزشی شما (شامل فلش‌کارت‌ها، نوبت‌های مرور لایتنر، امتیازات و پیشرفت دروس گرامر) به طور کامل حذف خواهد شد.\n\nاین عمل به هیچ وجه قابل بازگشت نیست!\nآیا کاملاً مطمئن هستید؟",
		"بازنشانی کامل",
		true,
		func() -> void:
			Global.reset_all_progress()
			_refresh_data_section()
			_show_toast("همه پیشرفت آموزشی بازنشانی شد ✓")
	)


# ══════════════════════════════════════════════════════════════
#  ABOUT SECTION
# ══════════════════════════════════════════════════════════════
func _app_version() -> String:
	var v: Variant = ProjectSettings.get_setting("application/config/version", "")
	return str(v) if not str(v).is_empty() else "1.0.0"


func _on_about_dev_pressed() -> void:
	if Global.sound_enabled:
		Sfx.click()
	TransitionManager.change_scene(SCENE_ABOUT_ME)


# ══════════════════════════════════════════════════════════════
#  MODAL CONFIRMATION DIALOG (High Contrast & Spring Motion)
# ══════════════════════════════════════════════════════════════
func _show_confirm_dialog(
	title: String,
	message: String,
	confirm_text: String,
	is_danger: bool,
	action: Callable
) -> void:
	# Close existing modal if open
	if _active_modal != null and is_instance_valid(_active_modal):
		_active_modal.queue_free()

	var modal_layer := CanvasLayer.new()
	modal_layer.layer = 3  # Above all controls & bottom navigation
	add_child(modal_layer)
	_active_modal = modal_layer

	var modal_root := Control.new()
	modal_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_root.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_layer.add_child(modal_root)

	# Scrim / Dim backdrop
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_root.add_child(dim)

	# Center wrapper
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_root.add_child(center)

	# Card container
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(860, 0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(1, 1, 1, 1)
	card_style.border_color = Color(0.235, 0.196, 0.118, 0.14)
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(28)
	card_style.shadow_color = Color(0, 0, 0, 0.22)
	card_style.shadow_size = 28
	card_style.shadow_offset = Vector2(0, 10)
	card_style.content_margin_left = 48.0
	card_style.content_margin_top = 44.0
	card_style.content_margin_right = 48.0
	card_style.content_margin_bottom = 44.0
	card.add_theme_stylebox_override("panel", card_style)
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	card.add_child(vbox)

	# Title
	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_override("font", MenuStyle.vazir_bold())
	title_lbl.add_theme_font_size_override("font_size", 38)
	var title_color: Color = Color(0.75, 0.22, 0.17, 1) if is_danger else Global.get_theme_color("accent")
	title_lbl.add_theme_color_override("font_color", title_color)
	vbox.add_child(title_lbl)

	# Message
	var msg_lbl := Label.new()
	msg_lbl.text = message
	msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_lbl.add_theme_font_override("font", MenuStyle.vazir())
	msg_lbl.add_theme_font_size_override("font_size", 28)
	msg_lbl.add_theme_color_override("font_color", Color(0.24, 0.22, 0.19, 1))
	vbox.add_child(msg_lbl)

	# Actions Row
	var actions_row := HBoxContainer.new()
	actions_row.alignment = BoxContainer.ALIGNMENT_CENTER
	actions_row.add_theme_constant_override("separation", 20)
	vbox.add_child(actions_row)

	var cancel_btn := Button.new()
	cancel_btn.text = "انصراف"
	cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_btn.custom_minimum_size = Vector2(0, 90)
	cancel_btn.add_theme_font_override("font", MenuStyle.vazir_bold())
	cancel_btn.add_theme_font_size_override("font_size", 32)
	_style_modal_cancel_button(cancel_btn)
	_setup_button_spring(cancel_btn)
	actions_row.add_child(cancel_btn)

	var confirm_btn := Button.new()
	confirm_btn.text = confirm_text
	confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_btn.custom_minimum_size = Vector2(0, 90)
	confirm_btn.add_theme_font_override("font", MenuStyle.vazir_bold())
	confirm_btn.add_theme_font_size_override("font_size", 32)
	_style_modal_confirm_button(confirm_btn, is_danger)
	_setup_button_spring(confirm_btn)
	actions_row.add_child(confirm_btn)

	# Close helper with smooth exit animation
	var close_dialog := func() -> void:
		if not is_instance_valid(modal_layer):
			return
		var tw_exit: Tween = create_tween()
		tw_exit.set_parallel(true)
		tw_exit.tween_property(dim, "modulate:a", 0.0, 0.16)
		tw_exit.tween_property(card, "modulate:a", 0.0, 0.16)
		tw_exit.tween_property(card, "scale", Vector2(0.90, 0.90), 0.16) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw_exit.chain().tween_callback(func() -> void:
			if is_instance_valid(modal_layer):
				modal_layer.queue_free()
				_active_modal = null
		)

	# Connect buttons
	cancel_btn.pressed.connect(func() -> void:
		if Global.sound_enabled:
			Sfx.click()
		close_dialog.call()
	)

	confirm_btn.pressed.connect(func() -> void:
		if Global.sound_enabled:
			Sfx.click()
		if action.is_valid():
			action.call()
		close_dialog.call()
	)

	# Tapping backdrop dismisses modal
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			close_dialog.call()
	)

	# Center pivot & entrance animation
	card.resized.connect(func() -> void:
		card.pivot_offset = card.size / 2.0
	)
	card.pivot_offset = card.custom_minimum_size / 2.0
	card.scale = Vector2(0.88, 0.88)
	card.modulate.a = 0.0
	dim.modulate.a = 0.0

	var tw_enter: Tween = create_tween().set_parallel(true)
	tw_enter.tween_property(dim, "modulate:a", 1.0, 0.22)
	tw_enter.tween_property(card, "modulate:a", 1.0, 0.25)
	tw_enter.tween_property(card, "scale", Vector2.ONE, 0.30) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _style_modal_cancel_button(btn: Button) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.96, 0.94, 0.91, 1)
	style.border_color = Color(0.235, 0.196, 0.118, 0.16)
	style.set_border_width_all(1)
	style.set_corner_radius_all(18)
	style.content_margin_left = 24
	style.content_margin_top = 18
	style.content_margin_right = 24
	style.content_margin_bottom = 18

	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("focus", style)
	btn.add_theme_color_override("font_color", Color(0.28, 0.25, 0.22, 1))
	btn.add_theme_color_override("font_hover_color", Color(0.18, 0.16, 0.14, 1))
	btn.add_theme_color_override("font_pressed_color", Color(0.18, 0.16, 0.14, 1))


func _style_modal_confirm_button(btn: Button, is_danger: bool) -> void:
	var style := StyleBoxFlat.new()
	var bg_col: Color = Color(0.75, 0.22, 0.17, 1) if is_danger else Global.get_theme_color("accent")
	var border_col: Color = bg_col.lightened(0.2)
	style.bg_color = bg_col
	style.border_color = border_col
	style.set_border_width_all(1)
	style.set_corner_radius_all(18)
	style.content_margin_left = 24
	style.content_margin_top = 18
	style.content_margin_right = 24
	style.content_margin_bottom = 18
	style.shadow_color = Color(bg_col.r, bg_col.g, bg_col.b, 0.35)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 4)

	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("focus", style)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)


# ══════════════════════════════════════════════════════════════
#  TOAST FEEDBACK
# ══════════════════════════════════════════════════════════════
func _show_toast(text: String) -> void:
	if _current_toast != null and is_instance_valid(_current_toast):
		_current_toast.queue_free()

	var toast_layer := CanvasLayer.new()
	toast_layer.layer = 2  # Above bottom navigation
	add_child(toast_layer)
	_current_toast = toast_layer

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.17, 0.24, 0.96)
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
	hbox.add_theme_constant_override(&"separation", 16)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var icon_label := Label.new()
	icon_label.text = "✓"
	icon_label.add_theme_font_size_override("font_size", 34)
	icon_label.add_theme_color_override("font_color", Global.get_theme_color("accent_bright"))
	hbox.add_child(icon_label)

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", MenuStyle.vazir())
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Color.WHITE)
	hbox.add_child(label)

	panel.add_child(hbox)
	toast_layer.add_child(panel)

	# Position above bottom navigation bar
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
#  NAVIGATION & ANDROID BACK HANDLER
# ══════════════════════════════════════════════════════════════
func _on_android_back_pressed() -> void:
	if Global.sound_enabled:
		Sfx.click()

	# If a modal dialog is currently showing, dismiss it first
	if _active_modal != null and is_instance_valid(_active_modal):
		_active_modal.queue_free()
		_active_modal = null
		return

	# Otherwise navigate back to MainMenu
	TransitionManager.change_scene(SCENE_MAIN_MENU)
