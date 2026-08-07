extends CanvasLayer

signal menu_closed
signal profile_pressed
signal saved_words_pressed
signal leitner_pressed      
signal purchase_pressed
signal settings_pressed
signal about_me_pressed

const SCENE_SAVED_WORDS  := "res://scenes/saved_words/SavedWords.tscn"
const SCENE_SETTINGS     := "res://scenes/settings/Settings.tscn"
const SCENE_LEITNER      := "res://scenes/review/WordReview.tscn"
const SCENE_PURCHASE    := "res://scenes/purchase/Purchase.tscn"
const SCENE_ABOUT_ME    := "res://scenes/about_me/AboutMe.tscn"

# --- Node References ---
@onready var overlay: ColorRect = $Overlay
@onready var menu_panel: Control = $MenuPanel

# Buttons
@onready var saved_words_button: Button = $MenuPanel/MarginContainer/VBoxContainer/SavedWordsButton
@onready var purchase_button: Button = $MenuPanel/MarginContainer/VBoxContainer/PurchaseButton
@onready var leitner_button: Button = $MenuPanel/MarginContainer/VBoxContainer/LeitnerButton
@onready var settings_button: Button = $MenuPanel/MarginContainer/VBoxContainer/SettingsButton
@onready var about_me_button: Button = $MenuPanel/MarginContainer/VBoxContainer/AboutMeButton

var is_open := false
var tween: Tween
var hamburger_button: Button
var hamburger_original_position: Vector2
var menu_closed_position: float
var menu_open_position: float

func _ready() -> void:
	# Hide menu immediately to prevent flash
	menu_panel.visible = false
	
		# In _ready(), gives the menu a cleaner rhythm (panel size unchanged)
	var vbox := $MenuPanel/MarginContainer/VBoxContainer as VBoxContainer
	vbox.add_theme_constant_override("separation", 40)
	
	overlay.modulate.a = 0.0
	overlay.visible = false
	
	# Calculate positions based on viewport
	menu_closed_position = get_viewport().get_visible_rect().size.x  # Off-screen right
	menu_open_position = get_viewport().get_visible_rect().size.x - menu_panel.size.x  # Visible on left
	
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

# ======================================================
# MODERN BUTTON STYLING (buttons only - MenuPanel untouched)
# ======================================================

# Accent palette used ONLY by the buttons (change to match your app)
const ACCENT       := Color("#8B5CF6")   # Modern violet accent
const ACCENT_HOVER := Color("#A78BFA")   # Lighter violet for hover/pressed
const TEXT_COLOR   := Color("#FFFFFF")

func _setup_modern_buttons() -> void:
	var buttons: Array[Button] = [
		saved_words_button,
		leitner_button,
		purchase_button,
		settings_button,
		about_me_button,
	]
	for btn in buttons:
		if btn:
			_apply_modern_style(btn)
			_add_hover_animation(btn)


func _apply_modern_style(btn: Button) -> void:
	var t := Theme.new()

	# --- Normal state: soft translucent card, rounded corners ---
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1.0, 1.0, 1.0, 0.06)   # Works over ANY panel color
	normal.set_corner_radius_all(12)
	normal.set_border_width_all(1)
	normal.border_color = Color(1.0, 1.0, 1.0, 0.10)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10

	# --- Hover state: accent border + soft glow ---
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(1.0, 1.0, 1.0, 0.12)
	hover.border_color = ACCENT
	hover.set_border_width_all(2)
	hover.shadow_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.35)
	hover.shadow_size = 10
	hover.shadow_offset = Vector2.ZERO   # Glow in all directions

	# --- Pressed state: stronger fill, tighter glow ---
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(1.0, 1.0, 1.0, 0.18)
	pressed.border_color = ACCENT_HOVER
	pressed.shadow_size = 6

	# --- Focus state: same as hover (removes ugly default outline) ---
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
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

	# Keep inner Labels (inside the HBoxContainers) white + same size
	for child in btn.find_children("*", "Label"):
		var label := child as Label
		label.add_theme_color_override("font_color", TEXT_COLOR)
		label.add_theme_font_size_override("font_size", 16)


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
	tw.tween_property(btn, "scale", target, duration)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	btn.set_meta("scale_tween", tw)

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
	
	# Move panel from right to left
	tween.tween_property(menu_panel, "position:x", menu_open_position, 0.4)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	
	# Fade in overlay
	tween.tween_property(overlay, "modulate:a", 0.5, 0.4)
	
	if hamburger_button:
		# Move hamburger button to stay at the right edge of the menu panel
		# The button should move left by the same amount as the panel, keeping it visible
		var target_btn_x = hamburger_original_position.x - menu_panel.size.x
		tween.tween_property(hamburger_button, "position:x", target_btn_x, 0.4)\
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

func close() -> void:
	if not is_open: 
		return
	
	is_open = false
	
	if tween: 
		tween.kill()
	
	tween = create_tween().set_parallel(true)
	
	# Move panel back off-screen right
	tween.tween_property(menu_panel, "position:x", menu_closed_position, 0.4)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	
	# Fade out overlay
	tween.tween_property(overlay, "modulate:a", 0.0, 0.4)
	
	if hamburger_button:
		# Return hamburger button to original position
		tween.tween_property(hamburger_button, "position:x", hamburger_original_position.x, 0.4)\
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tween.tween_property(hamburger_button, "rotation_degrees", 0.0, 0.4)\
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	
	# Hide overlay after animation completes
	tween.chain().tween_callback(func(): overlay.visible = false)

func _on_overlay_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()
