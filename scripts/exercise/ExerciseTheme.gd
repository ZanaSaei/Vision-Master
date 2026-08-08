class_name ExerciseTheme
extends RefCounted

## Centralized theme constants, colors, fonts, and UI factory methods.
## Replaces the massive UI creation code from the original ExerciseEngine.

const COLORS := {
	"primary": Color("#22D3EE"),
	"success": Color("#34D399"),
	"error": Color("#F87171"),
	"text": Color("#F1F5F9"),
	"muted": Color("#94A3B8"),
	"tint": Color("#1a2f5c"),
	"warning": Color("#FBBF24"),
	"info": Color("#22D3EE"),
	"purple": Color("#A78BFA"),
	"orange": Color("#FB923C"),
}

const FONT_SIZES := {
	"badge": 28, "title": 40, "body": 36, "body_small": 34,
	"hint": 32, "tiny": 28, "button": 34, "input": 36, "checkbox": 32,
}

const SPACING := {
	"section": 32, "item": 18, "tight": 10, "loose": 14, "button_row": 14,
}

const PADDING := {
	"button": 16, "input": 14, "badge": 10, "panel": 24,
}

const FONT_REGULAR_PATH := "res://assets/fonts/PlusJakartaSans-Regular.ttf"
const FONT_BOLD_PATH := "res://assets/fonts/PlusJakartaSans-Bold.ttf"

const TYPE_META := {
	"multiple_choice": {"badge": "Multiple Choice", "color": Color("#2563EB")},
	"true_false": {"badge": "True / False", "color": Color("#7C3AED")},
	"open_ended": {"badge": "Your Turn", "color": Color("#64748B")},
	# ... Add all 30+ types here ...
}

static var font_regular: FontFile
static var font_bold: FontFile

static func _static_init() -> void:
	font_regular = load(FONT_REGULAR_PATH)
	font_bold = load(FONT_BOLD_PATH)

static func make_label(text: String, size_key: String, color_key: String, bold: bool) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.add_theme_font_size_override("font_size", FONT_SIZES[size_key])
	l.add_theme_color_override("font_color", COLORS[color_key])
	
	if bold and font_bold:
		l.add_theme_font_override("font", font_bold)
	elif not bold and font_regular:
		l.add_theme_font_override("font", font_regular)
		
	return l

static func make_button(text: String, color_key: String) -> Button:
	var btn := Button.new()
	btn.mouse_filter = Control.MOUSE_FILTER_PASS
	btn.text = text
	btn.add_theme_font_size_override("font_size", FONT_SIZES.button)
	btn.add_theme_color_override("font_color", Color.WHITE)
	
	var style := StyleBoxFlat.new()
	style.bg_color = COLORS[color_key]
	style.set_corner_radius_all(12)
	style.set_content_margin_all(PADDING.button)
	btn.add_theme_stylebox_override("normal", style)
	
	var hover := style.duplicate()
	hover.bg_color = COLORS[color_key].lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	
	if font_bold:
		btn.add_theme_font_override("font", font_bold)
		
	return btn

# ==========================================
# ADD THIS TO ExerciseTheme.gd
# ==========================================

static func set_button_color(btn: Button, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(12)
	style.set_content_margin_all(PADDING.button)
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 3)
	btn.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate()
	hover.bg_color = color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
