extends "res://autoload/BackButtonHandler.gd"

# ============================================================
#  PURCHASE — placeholder screen.
#  The real purchase flow isn't implemented yet; this screen
#  exists so the side menu shows a friendly, themed message
#  instead of a blank page.
# ============================================================
@onready var _message_label: Label = $CenterBox/MessageLabel
@onready var _subtitle_label: Label = $CenterBox/SubLabel
@onready var _background: ColorRect = $Bg

func _ready() -> void:
	_apply_theme()
	Global.on_theme_changed(_on_theme_changed)
	_refresh_status()
	API.logged_in.connect(func(_user: Dictionary) -> void: _refresh_status())
	API.logged_out.connect(_refresh_status)
	API.subscription_updated.connect(func(_sub: Dictionary) -> void: _refresh_status())


func _apply_theme() -> void:
	if not is_inside_tree():
		return
	_background.color = Global.get_theme_color("bg_base")
	_message_label.add_theme_color_override("font_color", Global.get_theme_color("text"))
	_subtitle_label.add_theme_color_override("font_color", Global.get_theme_color("text_dim"))


func _refresh_status() -> void:
	var tier: String = str(API.get_subscription().get("tier", "free"))
	if not API.is_logged_in():
		_message_label.text = "برای مشاهده و فعال‌سازی اشتراک وارد حساب شوید."
		_subtitle_label.text = "با ورود به حساب، وضعیت اشتراک شما اینجا نمایش داده می‌شود."
	elif tier != "free":
		_message_label.text = "اشتراک ویژه فعال است ✓"
		_subtitle_label.text = "به همه بخش‌های آموزشی دسترسی کامل دارید."
	else:
		_message_label.text = "اشتراک فعلی: رایگان"
		_subtitle_label.text = "همه بخش‌های آموزشی فعلاً رایگان هستند."


func _on_theme_changed(_mode: int) -> void:
	_apply_theme()


func _on_android_back_pressed() -> void:
	Sfx.click()
	TransitionManager.change_scene("res://scenes/main_menu/MainMenu.tscn")


