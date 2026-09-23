extends CanvasLayer

signal saved_words_pressed
signal leitner_pressed
signal purchase_pressed
signal settings_pressed
signal account_pressed
signal about_me_pressed

const SCENE_SAVED_WORDS := "res://scenes/saved_words/SavedWords.tscn"
const SCENE_SETTINGS    := "res://scenes/settings/Settings.tscn"
const SCENE_LEITNER     := "res://scenes/review/WordReview.tscn"
const SCENE_PURCHASE    := "res://scenes/purchase/Purchase.tscn"
const SCENE_ACCOUNT     := "res://scenes/auth/Auth.tscn"
const SCENE_ABOUT_ME    := "res://scenes/about_me/AboutMe.tscn"

# ─── Node References ───────────────────────────────────────────
@onready var overlay: ColorRect = $Overlay
@onready var menu_panel: Control = $MenuPanel
var _panel_stylebox: StyleBoxFlat

# Buttons
@onready var saved_words_button: Button = $MenuPanel/MarginContainer/VBoxContainer/SavedWordsButton
@onready var purchase_button: Button = $MenuPanel/MarginContainer/VBoxContainer/PurchaseButton
@onready var leitner_button: Button = $MenuPanel/MarginContainer/VBoxContainer/LeitnerButton
@onready var settings_button: Button = $MenuPanel/MarginContainer/VBoxContainer/SettingsButton
@onready var account_button: Button = $MenuPanel/MarginContainer/VBoxContainer/AccountButton
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
	"Account":    "📱",
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
	_update_menu_positions()

	# Recompute if the window/viewport is ever resized (desktop testing,
	# foldables) so the panel always parks fully off/on screen.
	get_viewport().size_changed.connect(_update_menu_positions)

	# Set initial position (off-screen right)
	menu_panel.position.x = menu_closed_position
	# Keep the closed drawer hidden. It is shown only by open(), so a fresh
	# MainMenu never draws a parked sliver or a shadow bleed on the edge.
	menu_panel.visible = false

	overlay.gui_input.connect(_on_overlay_gui_input)
	saved_words_button.pressed.connect(func(): emit_signal("saved_words_pressed"); close())
	leitner_button.pressed.connect(func(): emit_signal("leitner_pressed"); close())
	purchase_button.pressed.connect(func(): emit_signal("purchase_pressed"); close())
	settings_button.pressed.connect(func(): emit_signal("settings_pressed"); close())
	account_button.pressed.connect(func(): emit_signal("account_pressed"); close())
	about_me_button.pressed.connect(func(): emit_signal("about_me_pressed"); close())

	_setup_modern_buttons()

	Global.on_theme_changed(_on_theme_changed)
	_apply_theme()


# How far past the right viewport edge the closed drawer is parked. A plain
# "viewport width" is NOT enough: the panel is laid out from its offsets each
# frame and actually settles a few px on-screen (and its shadow bleeds further),
# which shows a sliver of the menu on the fresh MainMenu after leaving a
# side-menu destination and coming back. Pushing it off with a margin — and
# keeping it invisible while closed — guarantees nothing is ever drawn.
const CLOSED_OFFSCREEN_MARGIN := 60.0

# Recomputes the off-screen / on-screen X positions from the current
# viewport size. Called in _ready and again whenever the viewport resizes
# so the drawer always parks exactly at the right edge.
func _update_menu_positions() -> void:
	menu_closed_position = get_viewport().get_visible_rect().size.x + CLOSED_OFFSCREEN_MARGIN
	menu_open_position = get_viewport().get_visible_rect().size.x - menu_panel.size.x
	# If the drawer is currently closed, keep it fully off-screen.
	if not is_open:
		menu_panel.position.x = menu_closed_position


# ══════════════════════════════════════════════════════════════
# THEME AWARENESS — restyle the panel for Dark / Light
# ══════════════════════════════════════════════════════════════
func _on_theme_changed(_mode: int) -> void:
	_apply_theme()


# The drawer palette comes straight from the design tokens, so it matches the
# rest of the app: the soft-UI charcoal shell in Dark, warm paper in Light,
# with the signature gold rim along the leading edge.
func _panel_bg() -> Color:
	return DesignTokens.color_of(Global.theme_is_dark(), "sidebar")


func _panel_border() -> Color:
	return DesignTokens.color_of(Global.theme_is_dark(), "gold_rim")


func _overlay_color() -> Color:
	return DesignTokens.color_of(Global.theme_is_dark(), "overlay")


func _text_color() -> Color:
	return DesignTokens.color_of(Global.theme_is_dark(), "text")


func _dim_text_color() -> Color:
	return DesignTokens.color_of(Global.theme_is_dark(), "text_dim")


func _chip_bg() -> Color:
	return DesignTokens.color_of(Global.theme_is_dark(), "surface_alt")


func _chip_hover() -> Color:
	return DesignTokens.color_of(Global.theme_is_dark(), "accent_soft")


func _chip_border() -> Color:
	return DesignTokens.color_of(Global.theme_is_dark(), "border")

func _apply_theme() -> void:
	var dark := Global.theme_is_dark()
	var panel_bg := _panel_bg()
	var overlay_col := _overlay_color()
	var text_col := _text_color()
	var dim_text_col := _dim_text_color()
	# Panel — the drawer surface, with a gold hairline along its leading edge.
	var st := DesignTokens.box(
		panel_bg,
		0,
		_panel_border(),
		DesignTokens.BORDER_SUBTLE,
		Color(0, 0, 0, 0.40 if dark else 0.16),
		DesignTokens.SHADOW_MEDIUM_SIZE,
		Vector2(-6, 0)
	)
	st.corner_radius_top_left = DesignTokens.RADIUS_MD
	st.corner_radius_bottom_left = DesignTokens.RADIUS_MD
	st.border_width_left = DesignTokens.BORDER_STANDARD
	_panel_stylebox = st
	menu_panel.add_theme_stylebox_override("panel", st)

	# While the drawer is closed its panel hides off-screen; keep the shadow
	# disabled so it can't cast a visible strip onto the scene edge. open()
	# re-enables it, close() keeps it off.
	if not is_open:
		st.shadow_size = 0
		st.shadow_offset = Vector2.ZERO

	# Overlay dims the page behind.
	overlay.color = overlay_col

	# Header / footer text.
	user_name_label.text = "سلام! 👋"
	welcome_label.text = "چطور میتوانم کمکت کنم؟"
	for l in [user_name_label, version_label]:
		if l.label_settings != null:
			l.label_settings.font_color = text_col
		else:
			l.add_theme_color_override("font_color", text_col)
	# Menu titles stay centred in the drawer.
	user_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	welcome_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if welcome_label.label_settings != null:
		welcome_label.label_settings.font_color = dim_text_col
	else:
		welcome_label.add_theme_color_override("font_color", dim_text_col)

	for btn in [saved_words_button, leitner_button, purchase_button, settings_button, account_button, about_me_button]:
		btn.add_theme_color_override("font_color", text_col)
		btn.add_theme_color_override("font_hover_color", text_col)
		btn.add_theme_color_override("font_pressed_color", text_col)
		btn.add_theme_color_override("font_focus_color", text_col)

		# The visible text is a child Label inside the button — recolor it too.
		for lbl in btn.find_children("TextLabel", "Label", true, false):
			lbl.add_theme_color_override("font_color", text_col)


# ══════════════════════════════════════════════════════════════
# MODERN BUTTON STYLING
# Accent colours come from the palette now that the drawer no longer carries
# its own violet identity — the app has ONE accent (the design system's blue).
# ══════════════════════════════════════════════════════════════


func _apply_modern_style(btn: Button) -> void:
	# Drawer rows are "chips": the raised surface with a hairline border, an
	# accent wash on hover and a solid accent fill when pressed.
	var dark := Global.theme_is_dark()
	var t := Theme.new()

	var normal := DesignTokens.box(_chip_bg(), DesignTokens.RADIUS_SM, _chip_border(), DesignTokens.BORDER_SUBTLE)
	DesignTokens.pad(normal, DesignTokens.SPACE_SM, 12)

	var hover := DesignTokens.box(
		_chip_hover(),
		DesignTokens.RADIUS_SM,
		DesignTokens.color_of(dark, "accent_bright"),
		DesignTokens.BORDER_SUBTLE
	)
	DesignTokens.pad(hover, DesignTokens.SPACE_SM, 12)

	var pressed := DesignTokens.box(
		DesignTokens.color_of(dark, "accent"),
		DesignTokens.RADIUS_SM,
		DesignTokens.color_of(dark, "accent_bright"),
		DesignTokens.BORDER_SUBTLE
	)
	DesignTokens.pad(pressed, DesignTokens.SPACE_SM, 12)

	t.set_stylebox("normal",   "Button", normal)
	t.set_stylebox("hover",    "Button", hover)
	t.set_stylebox("pressed",  "Button", pressed)
	t.set_stylebox("focus",    "Button", DesignTokens.button_focus(dark))
	t.set_stylebox("disabled", "Button", normal)

	# --- Typography ---
	t.set_color("font_color",         "Button", _text_color())
	t.set_color("font_hover_color",   "Button", DesignTokens.color_of(dark, "accent_bright"))
	t.set_color("font_pressed_color", "Button", DesignTokens.color_of(dark, "on_accent"))
	t.set_color("font_focus_color",   "Button", _text_color())
	t.set_font_size("font_size", "Button", DesignTokens.FONT_SMALL)
	t.set_constant("h_separation", "Button", 10)

	btn.theme = t


func _setup_modern_buttons() -> void:
	var button_data: Array[Dictionary] = [
		{"button": saved_words_button, "key": "SavedWords"},
		{"button": leitner_button,     "key": "Leitner"},
		{"button": purchase_button,    "key": "Purchase"},
		{"button": account_button,     "key": "Account"},
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
	# Position is captured lazily on the first open() — by then the button is
	# laid out (a floating control may still be settling in _ready).


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	if is_open:
		return
	is_open = true
	menu_panel.visible = true

	# Restore shadow for the open animation.
	if _panel_stylebox:
		_panel_stylebox.shadow_size = 24
		_panel_stylebox.shadow_offset = Vector2(-6, 0)

	overlay.visible = true
	if tween:
		tween.kill()

	tween = create_tween().set_parallel(true)
	tween.tween_property(menu_panel, "position:x", menu_open_position, 0.4) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(overlay, "modulate:a", 0.85, 0.4)

	if hamburger_button:
		if hamburger_original_position == Vector2.ZERO:
			hamburger_original_position = hamburger_button.position
		var target_btn_x := hamburger_original_position.x - menu_panel.size.x
		tween.tween_property(hamburger_button, "position:x", target_btn_x, 0.4) \
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		# Counter-clockwise 90° so the ☰ turns into a vertical "close" glyph.
		tween.tween_property(hamburger_button, "rotation_degrees", -90.0, 0.4) \
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)


func close() -> void:
	if not is_open:
		return
	is_open = false

	# Kill shadow immediately so it can't bleed onto the next scene.
	if _panel_stylebox:
		_panel_stylebox.shadow_size = 0
		_panel_stylebox.shadow_offset = Vector2.ZERO

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

	tween.chain().tween_callback(_on_close_tween_complete)


func _on_close_tween_complete() -> void:
	overlay.visible = false
	menu_panel.visible = false


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
	text_label.add_theme_color_override("font_color", Color("#FFFFFF") if Global.theme_is_dark() else Color("#1E1E1E"))
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
