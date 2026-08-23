extends CanvasLayer

signal saved_words_pressed
signal leitner_pressed
signal purchase_pressed
signal settings_pressed
signal about_me_pressed

const SCENE_SAVED_WORDS := "res://scenes/saved_words/SavedWords.tscn"
const SCENE_SETTINGS    := "res://scenes/settings/Settings.tscn"
const SCENE_LEITNER     := "res://scenes/review/WordReview.tscn"
const SCENE_PURCHASE    := "res://scenes/purchase/Purchase.tscn"
const SCENE_ABOUT_ME    := "res://scenes/about_me/AboutMe.tscn"

# ─── Node References ───────────────────────────────────────────
@onready var overlay: ColorRect = $Overlay
@onready var menu_panel: Control = $MenuPanel

# Buttons
@onready var saved_words_button: Button = $MenuPanel/MarginContainer/VBoxContainer/SavedWordsButton
@onready var purchase_button: Button = $MenuPanel/MarginContainer/VBoxContainer/PurchaseButton
@onready var leitner_button: Button = $MenuPanel/MarginContainer/VBoxContainer/LeitnerButton
@onready var settings_button: Button = $MenuPanel/MarginContainer/VBoxContainer/SettingsButton
@onready var about_me_button: Button = $MenuPanel/MarginContainer/VBoxContainer/AboutMeButton

# Header / footer labels (use LabelSettings that override the theme — recolor them)
@onready var user_name_label: Label = $MenuPanel/MarginContainer/VBoxContainer/Header/UserName
@onready var welcome_label: Label   = $MenuPanel/MarginContainer/VBoxContainer/Header/WelcomeText
@onready var version_label: Label   = $MenuPanel/MarginContainer/VBoxContainer/VersionLabel

var is_open := false
var tween: Tween
var hamburger_button: Button
var hamburger_original_position: Vector2
var menu_closed_position: float
var menu_open_position: float

# ─── Emoji mapping for each button ─────────────────────────────
const BUTTON_EMOJIS := {
	"SavedWords": "📚",
	"Leitner":    "🧠",
	"Purchase":   "💎",
	"Settings":   "⚙️",
	"AboutMe":    "👤",
}

const BUTTON_TEXT_FONT_SIZE := 45
const EMOJI_FONT_SIZE := 55
const EMOJI_MIN_COLUMN_WIDTH := 44.0

# Fixed width for the emoji column so all emojis align vertically
const EMOJI_WIDTH := 40.0

func _ready() -> void:
	# Hide menu immediately to prevent flash
	menu_panel.visible = false

	# Give the VBoxContainer a cleaner rhythm
	var vbox := $MenuPanel/MarginContainer/VBoxContainer as VBoxContainer
	vbox.add_theme_constant_override("separation", 40)

	overlay.modulate.a = 0.0
	overlay.visible = false

	# Calculate positions based on viewport
	menu_closed_position = get_viewport().get_visible_rect().size.x
	menu_open_position = get_viewport().get_visible_rect().size.x - menu_panel.size.x

	# Set initial position (off-screen right)
	menu_panel.position.x = menu_closed_position

	# Now show the menu (it's off-screen so won't be visible)
	menu_panel.visible = true

	overlay.gui_input.connect(_on_overlay_gui_input)
	saved_words_button.pressed.connect(func(): emit_signal("saved_words_pressed"); close())
	leitner_button.pressed.connect(func(): emit_signal("leitner_pressed"); close())
	purchase_button.pressed.connect(func(): emit_signal("purchase_pressed"); close())
	settings_button.pressed.connect(func(): emit_signal("settings_pressed"); close())
	about_me_button.pressed.connect(func(): emit_signal("about_me_pressed"); close())

	_setup_modern_buttons()

	Global.on_theme_changed(_on_theme_changed)
	_apply_theme()


# ══════════════════════════════════════════════════════════════
# THEME AWARENESS — restyle the panel for Dark / Light
# ══════════════════════════════════════════════════════════════
func _on_theme_changed(_mode: int) -> void:
	_apply_theme()


func _apply_theme() -> void:
	var dark := Global.theme_is_dark()
	var st := StyleBoxFlat.new()
	st.set_corner_radius_all(24)
	if dark:
		st.bg_color = Color(0, 0.29, 0.29, 1)
		st.set_border_width_all(0)
	else:
		st.bg_color = Color(0.97, 0.98, 1, 1)
		st.border_color = Color(0, 0, 0, 0.08)
		st.set_border_width_all(1)
	menu_panel.add_theme_stylebox_override("panel", st)

	# Overlay dims the page behind — neutral in both themes.
	overlay.color = Color(0, 0, 0, 1) if not dark else Color(0, 0.29, 0.29, 1)

	# Button text + backgrounds must be readable on the panel in both themes.
	var text_color: Color = Global.get_theme_color("text")

	# Header title / subtitle / footer must be readable on the panel.
	var dim_color: Color = Global.get_theme_color("text_dim")
	for l in [user_name_label, version_label]:
		if l.label_settings != null:
			l.label_settings.font_color = text_color
		else:
			l.add_theme_color_override("font_color", text_color)
	if welcome_label.label_settings != null:
		welcome_label.label_settings.font_color = dim_color
	else:
		welcome_label.add_theme_color_override("font_color", dim_color)
	var btn_bg := Color(1, 1, 1, 0.08) if dark else Color(0, 0, 0, 0.05)
	var btn_border := Color(1, 1, 1, 0.12) if dark else Color(0, 0, 0, 0.10)
	var btn_hover_bg := Color(1, 1, 1, 0.15) if dark else Color(0.545, 0.361, 0.965, 0.12)

	for btn in [saved_words_button, leitner_button, purchase_button, settings_button, about_me_button]:
		btn.add_theme_color_override("font_color", text_color)
		btn.add_theme_color_override("font_hover_color", text_color)
		btn.add_theme_color_override("font_pressed_color", text_color)
		btn.add_theme_color_override("font_focus_color", text_color)

		# The visible text is a child Label inside the button — recolor it too.
		for lbl in btn.find_children("TextLabel", "Label", true, false):
			lbl.add_theme_color_override("font_color", text_color)

		# Give the buttons a subtle, theme-appropriate backdrop.
		var normal := StyleBoxFlat.new()
		normal.bg_color = btn_bg
		normal.border_color = btn_border
		normal.set_border_width_all(1)
		normal.set_corner_radius_all(12)
		normal.content_margin_left = 16
		normal.content_margin_right = 16
		normal.content_margin_top = 10
		normal.content_margin_bottom = 10
		var hover := normal.duplicate() as StyleBoxFlat
		hover.bg_color = btn_hover_bg
		hover.border_color = Color("#8B5CF6")
		hover.set_border_width_all(2)
		var pressed := hover.duplicate() as StyleBoxFlat
		var focus := hover.duplicate() as StyleBoxFlat
		btn.add_theme_stylebox_override("normal", normal)
		btn.add_theme_stylebox_override("hover", hover)
		btn.add_theme_stylebox_override("pressed", pressed)
		btn.add_theme_stylebox_override("focus", focus)


# ══════════════════════════════════════════════════════════════
# MODERN BUTTON STYLING
# ══════════════════════════════════════════════════════════════
const ACCENT       := Color("#8B5CF6")
const ACCENT_HOVER := Color("#A78BFA")
const TEXT_COLOR   := Color("#FFFFFF")


func _setup_modern_buttons() -> void:
	var button_data: Array[Dictionary] = [
		{"button": saved_words_button, "key": "SavedWords"},
		{"button": leitner_button,     "key": "Leitner"},
		{"button": purchase_button,    "key": "Purchase"},
		{"button": settings_button,    "key": "Settings"},
		{"button": about_me_button,    "key": "AboutMe"},
	]

	for data in button_data:
		var btn: Button = data.get("button")
		var key: String = data.get("key", "")

		if btn == null:
			continue

		# Keep the original minimum size as a base minimum.
		if not btn.has_meta("base_min_size"):
			btn.set_meta("base_min_size", btn.custom_minimum_size)

		# Store the original visible text before rebuilding the button content.
		if not btn.has_meta("original_text"):
			btn.set_meta("original_text", _extract_button_text(btn))

		_apply_modern_style(btn)
		_rebuild_button_content(btn, key)
		_add_hover_animation(btn)



func _apply_modern_style(btn: Button) -> void:
	var t := Theme.new()

	# --- Normal state ---
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1.0, 1.0, 1.0, 0.06)
	normal.set_corner_radius_all(12)
	normal.set_border_width_all(1)
	normal.border_color = Color(1.0, 1.0, 1.0, 0.10)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10

	# --- Hover state ---
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(1.0, 1.0, 1.0, 0.12)
	hover.border_color = ACCENT
	hover.set_border_width_all(2)
	hover.shadow_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.35)
	hover.shadow_size = 10
	hover.shadow_offset = Vector2.ZERO

	# --- Pressed state ---
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(1.0, 1.0, 1.0, 0.18)
	pressed.border_color = ACCENT_HOVER
	pressed.shadow_size = 6

	# --- Focus state ---
	var focus := hover.duplicate() as StyleBoxFlat

	t.set_stylebox("normal",   "Button", normal)
	t.set_stylebox("hover",    "Button", hover)
	t.set_stylebox("pressed",  "Button", pressed)
	t.set_stylebox("focus",    "Button", focus)
	t.set_stylebox("disabled", "Button", normal)

	# --- Typography ---
	t.set_color("font_color",         "Button", TEXT_COLOR)
	t.set_color("font_hover_color",   "Button", TEXT_COLOR)
	t.set_color("font_pressed_color", "Button", TEXT_COLOR)
	t.set_color("font_focus_color",   "Button", TEXT_COLOR)
	t.set_font_size("font_size", "Button", 16)
	t.set_constant("h_separation", "Button", 10)

	btn.theme = t


func _add_hover_animation(btn: Button) -> void:
	# Keep pivot centered so the button scales from its middle
	var update_pivot := func() -> void:
		btn.pivot_offset = btn.size / 2.0
	update_pivot.call()
	btn.resized.connect(update_pivot)

	# Smooth grow on hover
	btn.mouse_entered.connect(func() -> void:
		_tween_scale(btn, Vector2(1.04, 1.04), 0.15)
	)
	# Shrink back when mouse leaves
	btn.mouse_exited.connect(func() -> void:
		_tween_scale(btn, Vector2.ONE, 0.15)
	)
	# Quick "press-down" feedback
	btn.button_down.connect(func() -> void:
		_tween_scale(btn, Vector2(0.96, 0.96), 0.08)
	)
	btn.button_up.connect(func() -> void:
		_tween_scale(btn, Vector2(1.04, 1.04), 0.08)
	)


func _tween_scale(btn: Button, target: Vector2, duration: float) -> void:
	# Kill any previous scale tween on this button to avoid conflicts
	if btn.has_meta("scale_tween"):
		var old := btn.get_meta("scale_tween") as Tween
		if old.is_valid():
			old.kill()

	var tw := create_tween()
	tw.tween_property(btn, "scale", target, duration) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	btn.set_meta("scale_tween", tw)


# ─── Menu open / close ─────────────────────────────────────────
func set_hamburger_button(button: Button) -> void:
	hamburger_button = button
	hamburger_original_position = hamburger_button.position


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	if is_open:
		return
	is_open = true

	overlay.visible = true
	if tween:
		tween.kill()

	tween = create_tween().set_parallel(true)
	tween.tween_property(menu_panel, "position:x", menu_open_position, 0.4) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(overlay, "modulate:a", 0.5, 0.4)

	if hamburger_button:
		var target_btn_x := hamburger_original_position.x - menu_panel.size.x
		tween.tween_property(hamburger_button, "position:x", target_btn_x, 0.4) \
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)


func close() -> void:
	if not is_open:
		return
	is_open = false

	if tween:
		tween.kill()

	tween = create_tween().set_parallel(true)
	tween.tween_property(menu_panel, "position:x", menu_closed_position, 0.4) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(overlay, "modulate:a", 0.0, 0.4)

	if hamburger_button:
		tween.tween_property(hamburger_button, "position:x", hamburger_original_position.x, 0.4) \
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tween.tween_property(hamburger_button, "rotation_degrees", 0.0, 0.4) \
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

	tween.chain().tween_callback(func(): overlay.visible = false)


func _on_overlay_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()

# ─────────────────────────────────────────────────────────────────────────────
# Button content helpers
# ─────────────────────────────────────────────────────────────────────────────

# Tries to get the original text from the Button itself.
# If the Button text is empty, it looks for an existing Label child.
func _extract_button_text(btn: Button) -> String:
	var direct_text := btn.text.strip_edges()
	if not direct_text.is_empty():
		return direct_text

	for child in btn.find_children("*", "Label"):
		var label := child as Label
		if label and not label.text.strip_edges().is_empty():
			return label.text.strip_edges()

	# Fallback: SavedWordsButton -> SavedWords
	return btn.name.trim_suffix("Button")


# Rebuilds the button content as:
# [LeftSpacer] [Centered Text] [Emoji]
#
# The LeftSpacer has the same width as the emoji column.
# This makes the text visually centered inside the whole button,
# while the emoji stays aligned on the right side.
func _rebuild_button_content(btn: Button, emoji_key: String) -> void:
	var button_text: String = btn.get_meta("original_text", "")
	btn.text = ""
	btn.clip_contents = false

	# Keep full width so all right-side emojis align with each other.
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Let the button height fit its content instead of stretching unnecessarily.
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	# Remove old custom children safely.
	for child in btn.get_children():
		if child.is_internal():
			continue
		btn.remove_child(child)
		child.queue_free()

	# Main row inside the button.
	var row := HBoxContainer.new()
	row.name = "ButtonContent"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 8)
	btn.add_child(row)

	# Invisible spacer on the left.
	# It balances the emoji width on the right, so the text stays centered.
	var left_spacer := Control.new()
	left_spacer.name = "LeftSpacer"
	left_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_spacer.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left_spacer.size_flags_vertical = Control.SIZE_FILL
	row.add_child(left_spacer)

	# Centered text label.
	var text_label := Label.new()
	text_label.name = "TextLabel"
	text_label.text = button_text
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_label.size_flags_vertical = Control.SIZE_FILL
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_label.add_theme_color_override("font_color", TEXT_COLOR)
	text_label.add_theme_font_size_override("font_size", BUTTON_TEXT_FONT_SIZE)
	row.add_child(text_label)

	# Right emoji label.
	var emoji_label := Label.new()
	emoji_label.name = "EmojiLabel"
	emoji_label.text = BUTTON_EMOJIS.get(emoji_key, "")
	emoji_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	emoji_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	emoji_label.size_flags_vertical = Control.SIZE_FILL
	emoji_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emoji_label.add_theme_font_size_override("font_size", EMOJI_FONT_SIZE)
	row.add_child(emoji_label)

	# Refresh layout and minimum size whenever something changes.
	var refresh := func() -> void:
		if not is_instance_valid(btn) or not is_instance_valid(row):
			return
		_sync_emoji_column_width(left_spacer, emoji_label)
		_apply_content_margins(btn, row)
		_update_button_minimum_size(btn, row)

	btn.theme_changed.connect(refresh)
	row.minimum_size_changed.connect(refresh)
	text_label.minimum_size_changed.connect(refresh)
	emoji_label.minimum_size_changed.connect(refresh)

	# Initial refresh.
	refresh.call()


# Keeps the left spacer and emoji label using the same column width.
func _sync_emoji_column_width(left_spacer: Control, emoji_label: Label) -> void:
	if not is_instance_valid(left_spacer) or not is_instance_valid(emoji_label):
		return

	var font_size := emoji_label.get_theme_font_size("font_size")
	var column_width : float = max(EMOJI_MIN_COLUMN_WIDTH, float(font_size) * 1.5)

	if left_spacer.custom_minimum_size.x != column_width:
		left_spacer.custom_minimum_size.x = column_width

	if emoji_label.custom_minimum_size.x != column_width:
		emoji_label.custom_minimum_size.x = column_width


# Applies the Button StyleBox content margins to the inner HBoxContainer.
func _apply_content_margins(btn: Button, content: Control) -> void:
	var style := btn.get_theme_stylebox("normal")
	if style == null:
		return

	content.offset_left = style.get_content_margin(SIDE_LEFT)
	content.offset_top = style.get_content_margin(SIDE_TOP)
	content.offset_right = -style.get_content_margin(SIDE_RIGHT)
	content.offset_bottom = -style.get_content_margin(SIDE_BOTTOM)


# Makes the Button large enough to fit its custom child content.
func _update_button_minimum_size(btn: Button, content: Control) -> void:
	if not is_instance_valid(btn) or not is_instance_valid(content):
		return

	var base_min: Vector2 = btn.get_meta("base_min_size", Vector2.ZERO)
	var style := btn.get_theme_stylebox("normal")

	var margin := Vector2.ZERO
	if style:
		margin.x += style.get_content_margin(SIDE_LEFT)
		margin.x += style.get_content_margin(SIDE_RIGHT)
		margin.y += style.get_content_margin(SIDE_TOP)
		margin.y += style.get_content_margin(SIDE_BOTTOM)

	var needed := content.get_combined_minimum_size() + margin

	var final_min := Vector2(
		max(base_min.x, needed.x),
		max(base_min.y, needed.y)
	)

	if btn.custom_minimum_size != final_min:
		btn.custom_minimum_size = final_min
