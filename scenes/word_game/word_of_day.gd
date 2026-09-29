extends "res://autoload/BackButtonHandler.gd"
# ============================================================
# کلمه روز — the daily Wordle puzzle.
#
# This scene is the host: it owns the header bar (title, back, help) and the
# navigation, while the puzzle itself lives in the instanced game content
# scene (wordle/WordleScreen.tscn). The «کلمه روز» button on the word-game
# hub opens this screen — there is no separate Wordle entry point.
# ============================================================

const SCENE_WORD_GAME := "res://scenes/word_game/WordGame.tscn"

@onready var back_button: Button = $HeaderBar/HeaderContent/BackButton
@onready var help_button: Button = $HeaderBar/HeaderContent/HelpButton
@onready var card_button: Button = $HeaderBar/HeaderContent/CardButton
## The instanced game content. Typed as Node on purpose: its small public API
## (show_help / close_panels) is reached through call(), so this shell does
## not need to know the game's script class.
@onready var game_content: Node = $Game


func _ready() -> void:
	back_button.pressed.connect(_on_back_button_pressed)
	help_button.pressed.connect(_on_help_button_pressed)
	back_button.mouse_filter = Control.MOUSE_FILTER_STOP
	help_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_header_actions.call_deferred()

	# The app-wide theme walk styles a scene when it is *entered*, not on a
	# live toggle; re-walking from here keeps the header and the page surface
	# in step when the theme is switched while the puzzle is open. (The game
	# content re-colours its own board, keyboard and cards.)
	Global.on_theme_changed(_on_theme_changed)
	_style_header_actions.call_deferred()


func _style_header_actions() -> void:
	if not is_inside_tree():
		return
	_style_action_button(help_button, "راهنما", Color("#DCEBFF"), Color("#2563EB"))
	_style_action_button(card_button, "کارت واژه", Color("#DDF7E8"), Color("#16834A"))


func _style_action_button(button: Button, label_text: String, tint: Color, accent: Color) -> void:
	button.text = label_text
	button.tooltip_text = label_text
	button.custom_minimum_size = Vector2(150, 102)
	button.add_theme_font_override("font", MenuStyle.vazir())
	button.add_theme_font_size_override("font_size", 28)
	button.add_theme_color_override("font_color", accent)
	button.add_theme_color_override("font_hover_color", accent)
	button.add_theme_color_override("font_pressed_color", accent.darkened(0.15))
	button.add_theme_stylebox_override("normal", _action_button_style(Color.WHITE, accent, 2))
	button.add_theme_stylebox_override("hover", _action_button_style(tint, accent, 3))
	button.add_theme_stylebox_override("pressed", _action_button_style(accent.lightened(0.78), accent, 3))
	button.add_theme_stylebox_override("focus", _action_button_style(tint, accent, 3))


func _action_button_style(fill: Color, outline: Color, border_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = outline
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(24)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	style.shadow_color = Color(outline.r, outline.g, outline.b, 0.14)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 2)
	return style


func _on_help_button_pressed() -> void:
	if game_content != null and game_content.has_method("show_help"):
		game_content.call("show_help")


func _on_theme_changed() -> void:
	Global.style_scene(self)
	_style_header_actions()


func _on_back_button_pressed() -> void:
	TransitionManager.change_scene(SCENE_WORD_GAME)


## Android back: an open card swallows the press first, so a player reading
## the word card is not thrown out of the puzzle. (The help card used to have
## no way out at all except leaving the screen.)
func _on_android_back_pressed() -> void:
	if game_content != null and game_content.has_method("close_panels") \
			and bool(game_content.call("close_panels")):
		return
	_on_back_button_pressed()
