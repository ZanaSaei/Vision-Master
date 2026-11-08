extends "res://autoload/BackButtonHandler.gd"
class_name WordGameLearning
## Landing page of the Wordef / Unscramble word games: two glossy cards that
## route into MeaningGame.tscn and SpellingGame.tscn.

const MEANING_SCENE: String = "res://scenes/word_game/MeaningGame.tscn"
const SCRAMBLED_SCENE: String = "res://scenes/word_game/SpellingGame.tscn"
const HUB_SCENE: String = "res://scenes/word_game/WordGameHub.tscn"
const MAIN_MENU_SCENE: String = "res://scenes/main_menu/MainMenu.tscn"

const FONT_VAZIR_BOLD: FontFile = preload("res://ui/fonts/Vazirmatn-Bold.ttf")
const FONT_VAZIR: FontFile = preload("res://ui/fonts/Vazirmatn-Regular.ttf")

@onready var _background: ColorRect = $Background
@onready var _header_bar: PanelContainer = $HeaderBar
@onready var _back_button: Button = $HeaderBar/HeaderContent/BackButton
@onready var _home_button: Button = $HeaderBar/HeaderContent/HomeButton
@onready var _wordef_button: Button = $MainMargin/MainColumn/WordefButton
@onready var _unscramble_button: Button = $MainMargin/MainColumn/UnscrambleButton

func _ready() -> void:
	Global.style_header(_header_bar)
	_background.color = MenuStyle.c("bg")
	_style_game_card(_wordef_button, Color("#2563EB"), "بازی Wordef", "یادگیری معنی، مترادف و متضاد واژگان", "📖")
	_style_game_card(_unscramble_button, Color("#7C3AED"), "بازی Unscramble", "تمرین هجی، املا و مرتب‌کردن حروف واژه‌ها", "🔤")
	_back_button.pressed.connect(_on_back_pressed)
	if _home_button != null:
		_home_button.pressed.connect(_on_home_pressed)
	_wordef_button.pressed.connect(_on_wordef_pressed)
	_unscramble_button.pressed.connect(_on_unscramble_pressed)
	UiMotion.wire_microinteractions(_wordef_button)
	UiMotion.wire_microinteractions(_unscramble_button)

func _style_game_card(btn: Button, accent: Color, title: String, subtitle: String, emoji: String) -> void:
	btn.text = ""
	btn.clip_contents = true
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.WHITE
	sb.set_corner_radius_all(28)
	sb.border_width_left = 10
	sb.border_color = accent
	sb.content_margin_left = 32
	sb.content_margin_right = 32
	sb.content_margin_top = 24
	sb.content_margin_bottom = 24
	sb.shadow_color = Color(0, 0, 0, 0.08)
	sb.shadow_size = 12
	sb.shadow_offset = Vector2(0, 4)
	btn.add_theme_stylebox_override("normal", sb)

	var sb_pressed := sb.duplicate() as StyleBoxFlat
	sb_pressed.bg_color = Color("#F8FAFC")
	btn.add_theme_stylebox_override("pressed", sb_pressed)
	btn.add_theme_stylebox_override("hover", sb_pressed)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 44)
	margin.add_theme_constant_override("margin_right", 44)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 24)

	var emoji_lbl := Label.new()
	emoji_lbl.text = emoji
	emoji_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emoji_lbl.add_theme_font_size_override("font_size", 58)
	emoji_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(emoji_lbl)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.alignment = BoxContainer.ALIGNMENT_CENTER
	text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_lbl.add_theme_font_override("font", FONT_VAZIR_BOLD)
	title_lbl.add_theme_font_size_override("font_size", 40)
	title_lbl.add_theme_color_override("font_color", Color("#1E293B"))
	text_col.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = subtitle
	sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub_lbl.add_theme_font_override("font", FONT_VAZIR)
	sub_lbl.add_theme_font_size_override("font_size", 26)
	sub_lbl.add_theme_color_override("font_color", Color("#64748B"))
	text_col.add_child(sub_lbl)

	row.add_child(text_col)

	var arrow := Label.new()
	arrow.text = "❯"
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.add_theme_font_size_override("font_size", 44)
	arrow.add_theme_color_override("font_color", accent)
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(arrow)

	margin.add_child(row)
	btn.add_child(margin)

func _on_back_pressed() -> void:
	TransitionManager.change_scene(HUB_SCENE)

func _on_home_pressed() -> void:
	TransitionManager.change_scene(MAIN_MENU_SCENE)

func _on_wordef_pressed() -> void:
	TransitionManager.change_scene(MEANING_SCENE)

func _on_unscramble_pressed() -> void:
	TransitionManager.change_scene(SCRAMBLED_SCENE)

func _on_android_back_pressed() -> void:
	TransitionManager.change_scene(HUB_SCENE)
